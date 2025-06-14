# Troubleshooting Guide

This guide provides solutions to common issues encountered during the deployment and operation of the DogfyDiet Cloud Platform.

## Table of Contents

1.  [Terraform Issues](#terraform-issues)
2.  [GKE & Kubernetes Issues](#gke--kubernetes-issues)
3.  [Application Deployment Issues](#application-deployment-issues)
4.  [Networking Issues](#networking-issues)
5.  [Frontend Issues](#frontend-issues)
6.  [General Debugging Tips](#general-debugging-tips)

---

## 1. Terraform Issues

### a. Authentication Errors with GCP
* **Symptom**: `Error: google: could not find default credentials` or permission denied errors during `terraform apply`.
* **Cause**: Terraform cannot authenticate with your Google Cloud account or the authenticated identity lacks necessary permissions.
* **Solution**:
    1.  **Ensure `gcloud` is Authenticated**: Run `gcloud auth login` and `gcloud auth application-default login`.
    2.  **Check Project Configuration**: Verify the correct project is set with `gcloud config get-value project`. If not, run `gcloud config set project YOUR_PROJECT_ID`.
    3.  **Service Account Permissions (for CI/CD)**: If running in a CI/CD pipeline, ensure the service account (`dogfydiet-github-actions` or similar) has the required IAM roles. The `scripts/bootstrap.sh` grants broad roles; for production, these should be reviewed and minimized. The key roles are listed in the bootstrap script.
    4.  **API Enablement**: Ensure all necessary APIs are enabled for the project (e.g., Compute Engine, Kubernetes Engine, Pub/Sub, Firestore, Artifact Registry, IAM, Secret Manager, Cloud Monitoring, Cloud Logging). Terraform usually enables these, but failures can occur. Check the "APIs & Services" dashboard in GCP Console.

### b. Backend Initialization Failure
* **Symptom**: Error during `terraform init` related to the GCS backend, like "bucket not found" or "access denied".
* **Cause**: The GCS bucket for Terraform state is not correctly configured, doesn't exist, or the user/SA lacks permissions.
* **Solution**:
    1.  **Verify Bucket Name**: Ensure the bucket name in `terraform/environments/dev/main.tf` (or `backend.tf` if separated) matches the actual GCS bucket name (e.g., `nahuelgabe-test-terraform-state`).
    2.  **Bucket Existence**: Confirm the bucket exists in GCS. The `scripts/bootstrap.sh` should create it. If not, create it manually: `gsutil mb -p YOUR_PROJECT_ID -l YOUR_REGION gs://YOUR_BUCKET_NAME`.
    3.  **Bucket Permissions**: Ensure the identity running `terraform init` has `Storage Object Admin` or at least `Storage Object Creator` and `Storage Object Viewer` roles on the bucket.
    4.  **Versioning**: Ensure versioning is enabled on the state bucket: `gsutil versioning set on gs://YOUR_BUCKET_NAME`.

### c. Resource Creation Conflicts or "Already Exists" Errors
* **Symptom**: Terraform fails because a resource (e.g., GKE cluster, firewall rule) with the same name already exists.
* **Cause**:
    * A previous `terraform apply` partially succeeded.
    * Resources were created manually outside of Terraform with conflicting names.
    * Terraform state is out of sync.
* **Solution**:
    1.  **Import Resource**: If the resource exists and should be managed by Terraform, import it: `terraform import module.your_module.google_resource_type.name projects/YOUR_PROJECT_ID/regions/YOUR_REGION/resource_type/RESOURCE_NAME`. Refer to the specific resource's documentation for import syntax.
    2.  **Rename or Delete**: If the existing resource is not needed or can be renamed, do so in the GCP Console or via `gcloud`. Then re-run `terraform apply`.
    3.  **Refresh State**: Run `terraform refresh` to update the state file with the actual infrastructure.
    4.  **Check `name_prefix`**: Ensure the `name_prefix` in `terraform/environments/dev/main.tf` (e.g., `dogfydiet-dev`) is unique if you are deploying multiple instances of the platform in the same project.

### d. Load Balancer or NEG Issues
* **Symptom**: Load balancer not directing traffic to GKE services, 502 errors, or health check failures.
* **Cause**:
    * Incorrect NEG configuration in the Load Balancer module or GKE service annotations.
    * Firewall rules blocking health checks.
    * Microservice 1 not running or its health check endpoint (`/health`) is failing.
    * Service port mismatch between Kubernetes Service and BackendConfig/BackendService.
* **Solution**:
    1.  **Verify NEG Name/Zone**: The `gke_neg_name` and `gke_neg_zone` variables in `terraform/environments/dev/main.tf` (passed to the `loadbalancer` module) must match the NEG auto-generated by GKE for Microservice 1. You can find the NEG name using `gcloud compute network-endpoint-groups list`. The zone must be the zone of your GKE cluster nodes.
    2.  **Firewall for Health Checks**: Ensure the firewall rule `dogfydiet-dev-allow-lb-hc-gke` (or similar, defined in `terraform/environments/dev/main.tf`) allows traffic from Google Cloud health checker IP ranges (`130.211.0.0/22`, `35.191.0.0/16`) on the correct port (e.g., `3000` for Microservice 1) to nodes tagged with `dogfydiet-dev-gke-node`.
    3.  **Microservice 1 Health**:
        * Check pod logs: `kubectl logs -l app.kubernetes.io/name=microservice-1 -n default`
        * Ensure the `/health` endpoint in `applications/microservice-1/src/index.js` is functional and returns a 200 OK.
    4.  **Service Annotations**: Verify `k8s/helm-charts/microservice-1/templates/service.yaml` has the correct NEG annotation: `cloud.google.com/neg: '{"exposed_ports": {"80":{}}}'` (port `80` here refers to the Service port, not the container port).
    5.  **BackendConfig**: Ensure `k8s/helm-charts/microservice-1/templates/backendconfig.yaml` is correctly linked to the service and specifies the correct container port for health checks (e.g., `3000`).
    6.  **Backend Service Port Name**: The `gke_backend_service_port_name` in the Load Balancer Terraform module should match the `name` of the port in the Kubernetes Service definition for Microservice 1 (e.g., `http`).
    7.  **Check Load Balancer Backend Health**: In GCP Console, navigate to "Load balancing", select your LB, and check the health of the backend service associated with the GKE NEG.

---

## 2. GKE & Kubernetes Issues

### a. Pods Stuck in `Pending` State
* **Symptom**: `kubectl get pods` shows pods in `Pending` status.
* **Cause**:
    * Insufficient cluster resources (CPU, memory).
    * Node affinity/anti-affinity rules preventing scheduling.
    * PersistentVolumeClaim (PVC) issues (not applicable here as no PVCs are defined).
    * Taints and tolerations mismatch.
* **Solution**:
    1.  **Describe Pod**: `kubectl describe pod <pod-name> -n <namespace>` to see events and reasons for pending state.
    2.  **Check Cluster Resources**: Ensure your GKE node pool has enough allocatable CPU/memory. Consider increasing `max_node_count` in `terraform/modules/gke/variables.tf` or upgrading `node_machine_type`.
    3.  **Review Affinity/Tolerations**: Check `affinity` and `tolerations` in Helm chart `values.yaml` files.
    4.  **Check Node Taints**: `kubectl describe node <node-name>` to see if nodes have taints that pods don't tolerate.

### b. Pods in `CrashLoopBackOff` or `Error` State
* **Symptom**: Pods are restarting frequently or show `Error` status.
* **Cause**:
    * Application runtime errors.
    * Incorrect Docker image or image pull errors.
    * Configuration errors (missing environment variables, wrong file paths).
    * Liveness/Readiness probe failures.
* **Solution**:
    1.  **Check Pod Logs**:
        * Current logs: `kubectl logs <pod-name> -n <namespace>`
        * Previous instance logs (if restarted): `kubectl logs <pod-name> -n <namespace> -p`
    2.  **Describe Pod**: `kubectl describe pod <pod-name> -n <namespace>` for events, restart counts, and probe failures.
    3.  **Verify Image**: Ensure the image specified in Helm `values.yaml` (e.g., `us-central1-docker.pkg.dev/nahuelgabe-test/dogfydiet-dev-docker-repo/microservice-1:latest`) exists in Artifact Registry and the GKE node service account (`dogfydiet-dev-gke-nodes@...`) has `Artifact Registry Reader` permissions.
    4.  **Check Environment Variables**: Verify all required environment variables are correctly set in `values.yaml` (e.g., `GOOGLE_CLOUD_PROJECT`, `PUBSUB_TOPIC`, `CORS_ORIGIN`).
    5.  **Probe Configuration**:
        * Ensure `livenessProbe` and `readinessProbe` paths (e.g., `/health`, `/ready`) and ports in `values.yaml` are correct and the application responds successfully on these endpoints.
        * The application's `healthcheck.js` (defined in Dockerfile) should correctly reflect the health status.

### c. Workload Identity Failures
* **Symptom**: Applications cannot authenticate with GCP services (Pub/Sub, Firestore) despite Workload Identity being configured.
* **Cause**:
    * Incorrect GSA (Google Service Account) to KSA (Kubernetes Service Account) binding.
    * Missing IAM permissions for the GSA.
    * GKE cluster Workload Identity not properly enabled.
* **Solution**:
    1.  **Verify KSA Annotation**: In Helm `values.yaml` for each microservice, ensure the `serviceAccount.annotations."iam.gke.io/gcp-service-account"` correctly points to the respective GSA (e.g., `dogfydiet-dev-microservice-1@nahuelgabe-test.iam.gserviceaccount.com`).
    2.  **Verify IAM Binding**: Check that the GSA has the `roles/iam.workloadIdentityUser` role bound to the KSA:
        `gcloud iam service-accounts get-iam-policy <GSA_EMAIL>`
        It should include a member like `serviceAccount:YOUR_PROJECT_ID.svc.id.goog[<K8S_NAMESPACE>/<KSA_NAME>]`. This is configured in `terraform/modules/iam/main.tf`.
    3.  **GSA Permissions**: Ensure the GSA itself has the necessary permissions on GCP services (e.g., `roles/pubsub.publisher` for Microservice 1, `roles/pubsub.subscriber` and `roles/datastore.user` for Microservice 2). These are set in `terraform/modules/iam/main.tf`.
    4.  **Cluster WI Config**: Verify `workload_identity_config` is enabled in `terraform/modules/gke/main.tf` for the cluster.

### d. Helm Deployment Failures
* **Symptom**: `helm install` or `helm upgrade` fails.
* **Cause**: Syntax errors in templates, incorrect values in `values.yaml`, or issues with Tiller (Helm 2, not applicable here as Helm 3 is assumed).
* **Solution**:
    1.  **Lint Chart**: `helm lint k8s/helm-charts/microservice-1/`
    2.  **Dry Run**: `helm install --dry-run --debug microservice-1 k8s/helm-charts/microservice-1/ -n default > rendered.yaml`. Inspect `rendered.yaml` for issues.
    3.  **Check Values**: Double-check all values in `values.yaml`, especially image names, service account details, and environment variables.
    4.  **Check `kubectl` Context**: Ensure `kubectl` is configured for the correct cluster.

---

## 3. Application Deployment Issues

### a. Microservice 1 (API/Publisher) Not Publishing to Pub/Sub
* **Symptom**: Frontend successfully calls Microservice 1, but no messages appear in the Pub/Sub topic for Microservice 2.
* **Cause**:
    * Incorrect `PUBSUB_TOPIC` environment variable.
    * Permissions issue for Microservice 1's GSA to publish to the topic.
    * Application logic error in `applications/microservice-1/src/index.js`.
* **Solution**:
    1.  **Check Logs**: `kubectl logs -l app.kubernetes.io/name=microservice-1 -n default`. Look for errors related to Pub/Sub publishing.
    2.  **Verify Env Var**: Ensure `env.PUBSUB_TOPIC` in `k8s/helm-charts/microservice-1/values.yaml` matches the Terraform output `pubsub_topic_name` (e.g., `dogfydiet-dev-items-topic`).
    3.  **GSA Permissions**: Confirm `dogfydiet-dev-microservice-1@...` GSA has `roles/pubsub.publisher` on the topic.
    4.  **Code Logic**: Review the `POST /api/items` route in `applications/microservice-1/src/index.js` to ensure `topic.publishMessage()` is called correctly.

### b. Microservice 2 (Subscriber/Processor) Not Processing Messages
* **Symptom**: Messages accumulate in the Pub/Sub subscription or go to the Dead-Letter Topic (DLT).
* **Cause**:
    * Incorrect `PUBSUB_SUBSCRIPTION` or `FIRESTORE_COLLECTION` environment variables.
    * Permissions issue for Microservice 2's GSA to subscribe or write to Firestore.
    * Application logic error in `applications/microservice-2/src/index.js` (e.g., message parsing, Firestore interaction).
    * Message processing takes longer than `ackDeadlineSeconds`.
* **Solution**:
    1.  **Check Logs**: `kubectl logs -l app.kubernetes.io/name=microservice-2 -n default`. Look for errors.
    2.  **Verify Env Vars**:
        * `env.PUBSUB_SUBSCRIPTION` in `k8s/helm-charts/microservice-2/values.yaml` should match Terraform output `pubsub_subscription_name` (e.g., `dogfydiet-dev-items-subscription`).
        * `env.FIRESTORE_COLLECTION` should be set (e.g., `items`).
    3.  **GSA Permissions**: Confirm `dogfydiet-dev-microservice-2@...` GSA has `roles/pubsub.subscriber` on the subscription and `roles/datastore.user` on the project/Firestore database.
    4.  **Code Logic**: Review `processMessage` function in `applications/microservice-2/src/index.js`.
    5.  **Ack Deadline**: If processing is complex, consider increasing `ack_deadline_seconds` in `terraform/modules/pubsub/main.tf` for the subscription.
    6.  **DLT**: Check the DLT (`dogfydiet-dev-items-dead-letter-topic`) for messages and inspect their attributes for clues.

### c. CORS Errors from Frontend
* **Symptom**: Frontend (running locally or from GCS) shows CORS errors in the browser console when calling Microservice 1.
* **Cause**: `CORS_ORIGIN` environment variable in Microservice 1 is not correctly configured to allow requests from the frontend's origin.
* **Solution**:
    1.  **Identify Frontend Origin**:
        * Local dev: `http://localhost:8080` (or your dev server port).
        * Deployed: The URL of the Load Balancer (e.g., `http://<LOAD_BALANCER_IP>` or `https://nahueldog.duckdns.org`).
    2.  **Update `values.yaml`**: In `k8s/helm-charts/microservice-1/values.yaml`, ensure `env.CORS_ORIGIN` includes the correct frontend origin(s). Example: `https://nahueldog.duckdns.org,http://localhost:8080`.
    3.  **Redeploy Microservice 1**: `helm upgrade microservice-1 k8s/helm-charts/microservice-1/ -n default`.

---

## 4. Networking Issues

### a. Cannot Access Frontend via Load Balancer IP
* **Symptom**: Browser times out or shows errors when trying to access `http://<LOAD_BALANCER_IP>`.
* **Cause**:
    * Load Balancer IP not correctly provisioned or propagated.
    * Firewall rules blocking HTTP/HTTPS.
    * Backend bucket (GCS) for frontend not correctly configured or empty.
    * DNS issues if using a custom domain.
* **Solution**:
    1.  **Verify LB IP**: Check Terraform output `frontend_url` or `load_balancer_ip`.
    2.  **Firewall**: Ensure `dogfydiet-dev-allow-http-https` firewall rule allows traffic on ports 80/443 from `0.0.0.0/0` to targets tagged `http-server`/`https-server` (the LB implicitly gets these).
    3.  **Backend Bucket**:
        * Verify the GCS bucket (`dogfydiet-dev-frontend-xxxx`) exists and contains the frontend build (`dist/` contents).
        * Check the Load Balancer's backend service configuration in GCP Console to ensure it points to the correct backend bucket.
    4.  **DNS (for `nahueldog.duckdns.org`)**:
        * Ensure your DuckDNS (or other DNS provider) A record for `nahueldog.duckdns.org` points to the `load_balancer_ip`.
        * Allow time for DNS propagation.
    5.  **SSL Certificate**: If using HTTPS, ensure the SSL certificate (`dogfydiet-dev-lb-ssl-cert`) is active and valid for the domain.

### b. API Calls (`/api/*`) to Microservice 1 Fail
* **Symptom**: Frontend calls to `/api/items` result in 404, 502, or other errors.
* **Cause**:
    * Load Balancer path routing misconfiguration.
    * Microservice 1 not running or unhealthy.
    * See also: [Load Balancer or NEG Issues](#d-load-balancer-or-neg-issues) and [Pods in `CrashLoopBackOff` or `Error` State](#b-pods-in-crashloopbackoff-or-error-state).
* **Solution**:
    1.  **LB Path Matcher**: Verify the URL map (`dogfydiet-dev-lb-urlmap`) in GCP Console has a path rule for `/api/*` correctly routing to the backend service connected to Microservice 1's NEG. This is configured in `terraform/modules/loadbalancer/main.tf`.
    2.  **Microservice 1 Status**: Ensure Microservice 1 pods are running and healthy in GKE.

---

## 5. Frontend Issues

### a. Frontend Appears Blank or Shows Errors
* **Symptom**: White screen, JavaScript errors in console.
* **Cause**:
    * Build errors in `applications/frontend`.
    * Incorrect `VUE_APP_API_URL` during build.
    * Static files not correctly uploaded to GCS or cache issues.
* **Solution**:
    1.  **Browser DevTools**: Open the browser's developer console for error messages.
    2.  **Rebuild Frontend**:
        * Ensure `VUE_APP_API_URL` is correctly set in `applications/frontend/.env.local` (e.g., `VUE_APP_API_URL=http://<LOAD_BALANCER_IP>/api`).
        * Run `npm run build` in `applications/frontend/`.
    3.  **Re-upload to GCS**: `gsutil -m rsync -r -d applications/frontend/dist/ gs://<your-frontend-bucket-name>/`.
    4.  **Clear Browser Cache**: And/or CDN cache if aggressive caching is set. The `build-deploy.yml` GitHub Actions workflow attempts to set appropriate `Cache-Control` headers.

### b. API URL Misconfiguration
* **Symptom**: Frontend makes requests to `undefined/api/items` or `localhost/api/items` when deployed.
* **Cause**: `VUE_APP_API_URL` was not correctly set at build time.
* **Solution**:
    1.  Correct `applications/frontend/.env.local` (or `.env.production` if used).
    2.  Rebuild the frontend: `npm run build`.
    3.  Re-upload to GCS.
    4.  Verify in `App.vue` `onMounted` console log that the `apiUrl` is correct.

---

## 6. General Debugging Tips

* **Check GCP Logs Explorer**: Filter by GKE Container, Pub/Sub Topic/Subscription, Load Balancer, Firestore, etc., for detailed logs.
* **Use Terraform Outputs**: Many important resource names and URLs are available via `terraform output` in `terraform/environments/dev/`.
* **Incrementally Deploy**: If facing many issues, try deploying components one by one or commenting out parts of the Terraform configuration to isolate problems.
* **`kubectl describe`**: Your best friend for Kubernetes issues. Use it for pods, services, deployments, ingresses (if used), etc.
* **GCP Console**: Visually inspect resource configurations (Load Balancers, GKE, Pub/Sub, Firestore) to confirm they match Terraform's intent.
* **Check Quotas**: Ensure your GCP project has sufficient quotas for resources (CPUs, IP addresses, etc.).
* **Simplify**: Temporarily remove complexities (e.g., disable HTTPS on LB, simplify firewall rules) to isolate the root cause. Remember to revert to secure configurations.

---
