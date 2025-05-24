# DogfyDiet Platform

A cloud-native full-stack application deployed on Google Cloud Platform, demonstrating microservices architecture, Infrastructure as Code, and modern DevOps practices.

## 🏗️ Architecture Overview

This solution implements a microservices-based architecture with:
- **Frontend**: Vue.js 3 SPA hosted on Google Cloud Storage with CDN
- **Backend**: Two Node.js microservices deployed on Google Kubernetes Engine
- **Messaging**: Event-driven communication via Google Pub/Sub
- **Database**: Google Firestore for NoSQL data storage
- **Infrastructure**: Managed via Terraform with comprehensive monitoring

## 🚀 Technology Stack

### Infrastructure & Cloud
- **Google Cloud Platform** - Cloud provider
- **Terraform** - Infrastructure as Code
- **Google Kubernetes Engine (GKE)** - Container orchestration
- **Google Cloud Storage** - Static website hosting with CDN
- **Google Cloud Load Balancer** - Traffic distribution and SSL termination
- **Google Pub/Sub** - Event messaging system
- **Google Firestore** - NoSQL document database
- **Google Cloud Monitoring** - Observability and alerting

### Applications  
- **Vue.js 3** - Frontend framework with Composition API
- **Node.js + Express.js** - Backend microservices
- **Docker** - Multi-stage containerization
- **Helm** - Kubernetes package management

### DevOps & Security
- **GitHub Actions** - CI/CD pipeline
- **Google Artifact Registry** - Container registry
- **Google Secret Manager** - Secret management
- **Workload Identity** - Secure GKE-to-GCP authentication
- **Network Policies** - Kubernetes microsegmentation

## 📋 Prerequisites

- Google Cloud Platform account with billing enabled
- `gcloud` CLI installed and configured
- `terraform` >= 1.5.0
- `kubectl` configured for GKE
- `helm` >= 3.12.0
- Node.js >= 18.0.0 (for local development)
- Docker (for building images)

## 🔧 Quick Start

### 1. Infrastructure Deployment

```bash
# Clone the repository
git clone https://github.com/your-username/dogfydiet-platform.git
cd dogfydiet-platform

# Set up Terraform backend (create GCS bucket first)
gsutil mb gs://your-project-terraform-state

# Initialize and deploy infrastructure
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# Get GKE credentials
gcloud container clusters get-credentials dogfydiet-dev-gke-cluster --region us-central1
```

### 2. Application Deployment

```bash
# Build and push Docker images
docker build -t us-central1-docker.pkg.dev/your-project/dogfydiet-dev-docker-repo/microservice-1:latest applications/microservice-1/
docker push us-central1-docker.pkg.dev/your-project/dogfydiet-dev-docker-repo/microservice-1:latest

docker build -t us-central1-docker.pkg.dev/your-project/dogfydiet-dev-docker-repo/microservice-2:latest applications/microservice-2/
docker push us-central1-docker.pkg.dev/your-project/dogfydiet-dev-docker-repo/microservice-2:latest

# Deploy microservices using Helm
cd k8s/helm-charts/microservice-1
helm install microservice-1 . --set image.tag=latest

cd ../microservice-2
helm install microservice-2 . --set image.tag=latest

# Deploy frontend to Cloud Storage
cd applications/frontend
npm install
npm run build
gsutil -m rsync -r -d dist/ gs://your-frontend-bucket/
```

### 3. Configure CI/CD

Set up GitHub repository secrets:
- `GCP_SA_KEY`: Base64 encoded service account key
- `NOTIFICATION_EMAIL`: Email for monitoring alerts
- `FRONTEND_BUCKET_NAME`: Cloud Storage bucket name
- `API_URL`: Backend API URL

## 🏛️ Project Structure

```
dogfydiet-platform/
├── README.md                     # This file
├── .github/workflows/           # GitHub Actions CI/CD pipelines
├── terraform/                   # Infrastructure as Code
│   ├── environments/dev/        # Development environment
│   └── modules/                 # Reusable Terraform modules
├── applications/                # Application source code
│   ├── frontend/               # Vue.js frontend application
│   ├── microservice-1/         # API Gateway & Publisher
│   └── microservice-2/         # Subscriber & Data Processor
├── k8s/                        # Kubernetes manifests and Helm charts
│   └── helm-charts/            # Helm charts for microservices
├── docs/                       # Architecture and technical documentation
└── scripts/                    # Utility scripts
```

## 🔄 Application Flow

1. **User Interaction**: User adds items through Vue.js frontend
2. **API Request**: Frontend sends HTTP POST to Microservice 1
3. **Validation**: Microservice 1 validates input and processes request
4. **Event Publishing**: Microservice 1 publishes event to Pub/Sub topic
5. **Event Processing**: Microservice 2 subscribes and processes the event
6. **Data Persistence**: Microservice 2 stores data in Firestore
7. **Real-time Updates**: Frontend displays updated item list

## 🛡️ Security Features

- **Workload Identity**: Secure service-to-service authentication
- **Network Policies**: Kubernetes microsegmentation
- **IAM Roles**: Least privilege access control
- **Secret Management**: Google Secret Manager integration
- **Container Security**: Non-root users, read-only filesystems
- **Input Validation**: Comprehensive request validation and sanitization

## 📊 Monitoring & Observability

- **Health Checks**: Liveness and readiness probes for all services
- **Metrics**: Custom application and business metrics
- **Logging**: Structured logging with correlation IDs
- **Alerting**: Multi-tier alerting (infrastructure, SRE, business)
- **Dashboards**: GCP Monitoring dashboards for operational visibility
- **Distributed Tracing**: Request tracing across microservices

## 🎯 Key Features Implemented

### Infrastructure
- ✅ VPC with private/public subnets and NAT gateway
- ✅ GKE cluster with autoscaling and security hardening
- ✅ Cloud Storage + Load Balancer for cost-effective frontend hosting
- ✅ Pub/Sub for event-driven architecture
- ✅ Firestore for scalable NoSQL data storage
- ✅ Comprehensive IAM with service accounts and workload identity

### Applications
- ✅ Vue.js 3 frontend with modern UI/UX and PWA capabilities
- ✅ Node.js microservices with comprehensive error handling
- ✅ RESTful APIs with validation and rate limiting
- ✅ Event-driven communication between services
- ✅ Production-ready Docker containers with multi-stage builds

### DevOps
- ✅ Terraform modules for reusable infrastructure components
- ✅ GitHub Actions CI/CD with automated testing and deployment
- ✅ Helm charts for Kubernetes application management
- ✅ Automated Docker image building and registry management
- ✅ Environment-specific configuration management

### Monitoring
- ✅ Application health endpoints and metrics
- ✅ Infrastructure monitoring with custom dashboards
- ✅ Log aggregation and structured logging
- ✅ Multi-tier alerting strategy
- ✅ Performance monitoring and SLA tracking

## 🎮 Local Development

### Frontend Development
```bash
cd applications/frontend
npm install
npm run serve  # Development server on http://localhost:8080
```

### Microservice Development  
```bash
cd applications/microservice-1
npm install
npm run dev    # Development server with hot reload

cd applications/microservice-2  
npm install
npm run dev    # Development server with hot reload
```

### Testing
```bash
# Run frontend tests
cd applications/frontend
npm run test:unit

# Run microservice tests
cd applications/microservice-1
npm test

cd applications/microservice-2
npm test
```

## 🚀 Deployment

### Automated Deployment (Recommended)
Push to `main` branch triggers automatic deployment via GitHub Actions:
1. Terraform infrastructure updates
2. Docker image building and pushing
3. Kubernetes application deployment
4. Frontend deployment to Cloud Storage

### Manual Deployment
```bash
# Infrastructure
cd terraform/environments/dev
terraform apply

# Applications
# (See Quick Start section above)
```

## 📈 Scaling and Performance

- **Horizontal Pod Autoscaler**: Automatic scaling based on CPU/memory
- **Cluster Autoscaler**: Node pool scaling based on resource demands
- **CDN Caching**: Global content delivery with Cloud CDN
- **Connection Pooling**: Efficient database connection management
- **Async Processing**: Non-blocking operations with event-driven design

## 💰 Cost Optimization

- **Cloud Storage**: 90% cost reduction vs. compute instances for frontend
- **Preemptible Nodes**: Cost-effective compute for non-critical workloads
- **Auto-scaling**: Scale to zero during low usage periods
- **Resource Right-sizing**: Proper CPU/memory allocation to avoid waste

## 🔍 Troubleshooting

### Check Application Health
```bash
# Check pod status
kubectl get pods

# Check service endpoints
kubectl get services

# View application logs
kubectl logs -l app=microservice-1
kubectl logs -l app=microservice-2

# Check ingress status
kubectl describe ingress
```

### Common Issues
- **Pod CrashLoopBackOff**: Check resource limits and application logs
- **ImagePullBackOff**: Verify image names and registry permissions
- **Service Connection Issues**: Check network policies and service discovery
- **Pub/Sub Issues**: Verify IAM permissions and topic/subscription configuration

## 📚 Documentation

- [Architecture Documentation](docs/architecture.md) - Detailed system architecture
- [Production Recommendations](docs/production-recommendations.md) - Production readiness guide
- [Technical Decisions](docs/technical-decisions.md) - ADRs and design rationale

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎊 Acknowledgments

- Google Cloud Platform for comprehensive cloud services
- Kubernetes community for container orchestration
- Vue.js team for excellent frontend framework
- Terraform community for infrastructure as code tooling

---

**DogfyDiet Platform** - Demonstrating cloud-native architecture excellence 🐕❤️