FROM node:18-alpine AS base

WORKDIR /app

RUN apk add --no-cache dumb-init

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs

FROM base AS deps

COPY package*.json ./

RUN npm ci --only=production && \
    npm cache clean --force

FROM base AS builder

COPY package*.json ./

RUN npm ci --silent

COPY . .

RUN npm run lint

FROM base AS production

ENV NODE_ENV=production
ENV PORT=3001

COPY --from=deps --chown=nextjs:nodejs /app/node_modules ./node_modules

COPY --chown=nextjs:nodejs . .

RUN rm -rf tests/ *.test.js *.spec.js .eslintrc.js

LABEL maintainer="DogfyDiet Platform Team"
LABEL version="1.0.0"
LABEL description="DogfyDiet Microservice 2 - Subscriber and Data Processor"

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js || exit 1

RUN echo 'const http = require("http"); \
const options = { hostname: "localhost", port: 3001, path: "/health", timeout: 2000 }; \
const req = http.request(options, (res) => { \
  process.exit(res.statusCode === 200 ? 0 : 1); \
}); \
req.on("error", () => process.exit(1)); \
req.end();' > healthcheck.js

USER nextjs

EXPOSE 3001

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/index.js"]