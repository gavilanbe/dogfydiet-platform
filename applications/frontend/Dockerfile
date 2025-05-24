# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci --only=production --silent

COPY . .

ARG VUE_APP_API_URL=http://localhost:3000
ARG VUE_APP_ENVIRONMENT=production

ENV VUE_APP_API_URL=${VUE_APP_API_URL}
ENV VUE_APP_ENVIRONMENT=${VUE_APP_ENVIRONMENT}

RUN npm run build

# Production stage
FROM nginx:1.25-alpine AS production

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /app/dist /usr/share/nginx/html

LABEL maintainer="DogfyDiet Platform Team"
LABEL version="1.0.0"
LABEL description="DogfyDiet Frontend Application"

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1

RUN addgroup -g 1001 -S nginx-user && \
    adduser -S -D -H -u 1001 -h /var/cache/nginx -s /sbin/nologin -G nginx-user -g nginx-user nginx-user && \
    chown -R nginx-user:nginx-user /usr/share/nginx/html && \
    chown -R nginx-user:nginx-user /var/cache/nginx && \
    chown -R nginx-user:nginx-user /var/log/nginx && \
    chown -R nginx-user:nginx-user /etc/nginx/conf.d

USER nginx-user

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]