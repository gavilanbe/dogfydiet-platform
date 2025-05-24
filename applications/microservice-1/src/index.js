const express = require('express')
const cors = require('cors')
const helmet = require('helmet')
const compression = require('compression')
const morgan = require('morgan')
const rateLimit = require('express-rate-limit')
const { body, validationResult } = require('express-validator')
const { PubSub } = require('@google-cloud/pubsub')
const winston = require('winston')
require('dotenv').config()

// Initialize Google Cloud Tracing (must be before other imports)
if (process.env.GOOGLE_CLOUD_PROJECT) {
  require('@google-cloud/trace-agent').start()
}

// Configure Winston logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { 
    service: 'microservice-1',
    version: process.env.npm_package_version || '1.0.0'
  },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    })
  ]
})

// Initialize Express app
const app = express()
const PORT = process.env.PORT || 3000

// Initialize Pub/Sub client
const pubsub = new PubSub({
  projectId: process.env.GOOGLE_CLOUD_PROJECT || 'nahuelgabe-test'
})

const TOPIC_NAME = process.env.PUBSUB_TOPIC || 'dogfydiet-dev-items-topic'

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  }
}))

app.use(compression())
app.use(express.json({ limit: '10mb' }))
app.use(express.urlencoded({ extended: true, limit: '10mb' }))

// CORS configuration
app.use(cors({
  origin: process.env.CORS_ORIGIN || ['http://localhost:8080', 'https://*.googleapis.com'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  credentials: true
}))

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: process.env.RATE_LIMIT || 100, // limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests from this IP, please try again later.'
  },
  standardHeaders: true,
  legacyHeaders: false
})

app.use('/api/', limiter)

// Logging middleware
app.use(morgan('combined', {
  stream: {
    write: (message) => logger.info(message.trim())
  }
}))

// Request ID middleware
app.use((req, res, next) => {
  req.id = require('crypto').randomUUID()
  res.setHeader('X-Request-ID', req.id)
  next()
})

// Health check endpoint
app.get('/health', (req, res) => {
  const healthStatus = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'microservice-1',
    version: process.env.npm_package_version || '1.0.0',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    environment: process.env.NODE_ENV || 'development'
  }
  
  res.status(200).json(healthStatus)
})

// Readiness check endpoint
app.get('/ready', async (req, res) => {
  try {
    // Check Pub/Sub connectivity
    const topic = pubsub.topic(TOPIC_NAME)
    await topic.exists()
    
    res.status(200).json({
      status: 'ready',
      timestamp: new Date().toISOString(),
      checks: {
        pubsub: 'connected'
      }
    })
  } catch (error) {
    logger.error('Readiness check failed:', error)
    res.status(503).json({
      status: 'not ready',
      timestamp: new Date().toISOString(),
      error: error.message
    })
  }
})

// Metrics endpoint for monitoring
app.get('/metrics', (req, res) => {
  const metrics = {
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    cpu: process.cpuUsage(),
    environment: process.env.NODE_ENV || 'development',
    nodejs_version: process.version
  }
  
  res.status(200).json(metrics)
})

// Validation middleware for items
const validateItem = [
  body('name')
    .isLength({ min: 1, max: 100 })
    .trim()
    .escape()
    .withMessage('Name must be between 1 and 100 characters'),
  body('category')
    .isIn(['treats', 'food', 'supplements', 'toys'])
    .withMessage('Category must be one of: treats, food, supplements, toys'),
  body('description')
    .optional()
    .isLength({ max: 500 })
    .trim()
    .escape()
    .withMessage('Description must be less than 500 characters')
]

// API Routes

// Get items endpoint (for frontend compatibility)
app.get('/api/items', async (req, res) => {
  try {
    // This is a simple in-memory store for demo purposes
    // In production, this would typically come from a database or cache
    const items = req.app.locals.items || []
    
    logger.info(`Retrieved ${items.length} items`, {
      requestId: req.id,
      count: items.length
    })
    
    res.status(200).json(items)
  } catch (error) {
    logger.error('Error retrieving items:', {
      requestId: req.id,
      error: error.message,
      stack: error.stack
    })
    
    res.status(500).json({
      error: 'Internal server error',
      requestId: req.id
    })
  }
})

// Create item endpoint
app.post('/api/items', validateItem, async (req, res) => {
  try {
    // Check validation results
    const errors = validationResult(req)
    if (!errors.isEmpty()) {
      logger.warn('Validation failed:', {
        requestId: req.id,
        errors: errors.array()
      })
      
      return res.status(400).json({
        error: 'Validation failed',
        details: errors.array(),
        requestId: req.id
      })
    }

    const itemData = {
      id: require('crypto').randomUUID(),
      name: req.body.name,
      category: req.body.category,
      description: req.body.description || '',
      timestamp: new Date().toISOString(),
      source: 'microservice-1',
      requestId: req.id
    }

    // Store item locally for GET requests (demo purposes)
    if (!req.app.locals.items) {
      req.app.locals.items = []
    }
    req.app.locals.items.unshift(itemData)

    // Publish message to Pub/Sub
    const topic = pubsub.topic(TOPIC_NAME)
    const messageData = Buffer.from(JSON.stringify(itemData))
    
    const messageId = await topic.publishMessage({
      data: messageData,
      attributes: {
        eventType: 'item.created',
        source: 'microservice-1',
        version: '1.0',
        timestamp: itemData.timestamp,
        requestId: req.id
      }
    })

    logger.info('Item created and published:', {
      requestId: req.id,
      itemId: itemData.id,
      messageId: messageId,
      category: itemData.category
    })

    res.status(201).json({
      success: true,
      data: itemData,
      messageId: messageId,
      requestId: req.id
    })

  } catch (error) {
    logger.error('Error creating item:', {
      requestId: req.id,
      error: error.message,
      stack: error.stack
    })

    res.status(500).json({
      error: 'Failed to create item',
      requestId: req.id
    })
  }
})

// API documentation endpoint
app.get('/api/docs', (req, res) => {
  const apiDocs = {
    name: 'DogfyDiet Microservice 1 API',
    version: '1.0.0',
    description: 'API Gateway and Publisher service for DogfyDiet platform',
    endpoints: {
      'GET /health': 'Health check endpoint',
      'GET /ready': 'Readiness check endpoint', 
      'GET /metrics': 'Metrics endpoint for monitoring',
      'GET /api/items': 'Retrieve all items',
      'POST /api/items': 'Create a new item and publish to Pub/Sub',
      'GET /api/docs': 'This documentation'
    },
    schemas: {
      item: {
        id: 'string (UUID)',
        name: 'string (1-100 chars)',
        category: 'string (treats|food|supplements|toys)',
        description: 'string (optional, max 500 chars)',
        timestamp: 'string (ISO 8601)',
        source: 'string',
        requestId: 'string (UUID)'
      }
    }
  }
  
  res.status(200).json(apiDocs)
})

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', {
    requestId: req.id,
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method
  })

  res.status(500).json({
    error: 'Internal server error',
    requestId: req.id
  })
})

// 404 handler
app.use('*', (req, res) => {
  logger.warn('Route not found:', {
    requestId: req.id,
    url: req.url,
    method: req.method
  })
  
  res.status(404).json({
    error: 'Route not found',
    requestId: req.id
  })
})

// Graceful shutdown
const gracefulShutdown = (signal) => {
  logger.info(`Received ${signal}. Starting graceful shutdown...`)
  
  server.close(() => {
    logger.info('HTTP server closed.')
    
    // Close Pub/Sub connections
    pubsub.close().then(() => {
      logger.info('Pub/Sub connections closed.')
      process.exit(0)
    }).catch((error) => {
      logger.error('Error closing Pub/Sub connections:', error)
      process.exit(1)
    })
  })
}

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  logger.info(`Microservice 1 started on port ${PORT}`, {
    port: PORT,
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
    pubsubTopic: TOPIC_NAME
  })
})

// Handle graceful shutdown
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'))
process.on('SIGINT', () => gracefulShutdown('SIGINT'))

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', {
    error: error.message,
    stack: error.stack
  })
  process.exit(1)
})

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection:', {
    reason: reason,
    promise: promise
  })
  process.exit(1)
})

module.exports = app