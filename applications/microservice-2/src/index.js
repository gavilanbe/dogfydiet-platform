const express = require('express')
const cors = require('cors')
const helmet = require('helmet')
const compression = require('compression')
const morgan = require('morgan')
const rateLimit = require('express-rate-limit')
const { PubSub } = require('@google-cloud/pubsub')
const { Firestore } = require('@google-cloud/firestore')
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
    service: 'microservice-2',
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
const PORT = process.env.PORT || 3001

// Initialize Google Cloud clients
const pubsub = new PubSub({
  projectId: process.env.GOOGLE_CLOUD_PROJECT || 'nahuelgabe-test'
})

const firestore = new Firestore({
  projectId: process.env.GOOGLE_CLOUD_PROJECT || 'nahuelgabe-test'
})

const SUBSCRIPTION_NAME = process.env.PUBSUB_SUBSCRIPTION || 'dogfydiet-dev-items-subscription'
const COLLECTION_NAME = process.env.FIRESTORE_COLLECTION || 'items'

// Statistics tracking
let stats = {
  messagesProcessed: 0,
  itemsStored: 0,
  errors: 0,
  startTime: new Date(),
  lastProcessed: null
}

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
  max: process.env.RATE_LIMIT || 100,
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
    service: 'microservice-2',
    version: process.env.npm_package_version || '1.0.0',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    environment: process.env.NODE_ENV || 'development',
    stats: stats
  }
  
  res.status(200).json(healthStatus)
})

// Readiness check endpoint
app.get('/ready', async (req, res) => {
  try {
    // Check Pub/Sub connectivity
    const subscription = pubsub.subscription(SUBSCRIPTION_NAME)
    await subscription.exists()
    
    // Check Firestore connectivity
    await firestore.collection(COLLECTION_NAME).limit(1).get()
    
    res.status(200).json({
      status: 'ready',
      timestamp: new Date().toISOString(),
      checks: {
        pubsub: 'connected',
        firestore: 'connected'
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
    nodejs_version: process.version,
    stats: stats,
    processing_rate: stats.messagesProcessed / (process.uptime() / 60) // messages per minute
  }
  
  res.status(200).json(metrics)
})

// API Routes

// Get items from Firestore
app.get('/api/items', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50
    const offset = parseInt(req.query.offset) || 0
    
    const snapshot = await firestore
      .collection(COLLECTION_NAME)
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .offset(offset)
      .get()
    
    const items = []
    snapshot.forEach(doc => {
      items.push({
        id: doc.id,
        ...doc.data()
      })
    })
    
    logger.info(`Retrieved ${items.length} items from Firestore`, {
      requestId: req.id,
      count: items.length,
      limit,
      offset
    })
    
    res.status(200).json({
      items: items,
      count: items.length,
      limit,
      offset,
      requestId: req.id
    })
    
  } catch (error) {
    logger.error('Error retrieving items from Firestore:', {
      requestId: req.id,
      error: error.message,
      stack: error.stack
    })
    
    res.status(500).json({
      error: 'Failed to retrieve items',
      requestId: req.id
    })
  }
})

// Get statistics
app.get('/api/stats', (req, res) => {
  const uptime = process.uptime()
  const processingRate = stats.messagesProcessed / (uptime / 60) // per minute
  
  res.status(200).json({
    ...stats,
    uptime: uptime,
    processingRate: Math.round(processingRate * 100) / 100,
    requestId: req.id
  })
})

// Function to process Pub/Sub messages
const processMessage = async (message) => {
  const startTime = Date.now()
  
  try {
    // Parse message data
    const messageData = JSON.parse(message.data.toString())
    const attributes = message.attributes || {}
    
    logger.info('Processing message:', {
      messageId: message.id,
      eventType: attributes.eventType,
      source: attributes.source,
      itemId: messageData.id
    })
    
    // Validate message data
    if (!messageData.id || !messageData.name || !messageData.category) {
      throw new Error('Invalid message data: missing required fields')
    }
    
    // Prepare document for Firestore
    const document = {
      ...messageData,
      processedAt: new Date().toISOString(),
      processedBy: 'microservice-2',
      messageId: message.id,
      messageAttributes: attributes
    }
    
    // Store in Firestore
    const docRef = firestore.collection(COLLECTION_NAME).doc(messageData.id)
    await docRef.set(document, { merge: true })
    
    // Update statistics
    stats.messagesProcessed++
    stats.itemsStored++
    stats.lastProcessed = new Date().toISOString()
    
    const processingTime = Date.now() - startTime
    
    logger.info('Message processed successfully:', {
      messageId: message.id,
      itemId: messageData.id,
      processingTime: `${processingTime}ms`,
      category: messageData.category
    })
    
    // Acknowledge the message
    message.ack()
    
  } catch (error) {
    stats.errors++
    
    logger.error('Error processing message:', {
      messageId: message.id,
      error: error.message,
      stack: error.stack,
      processingTime: `${Date.now() - startTime}ms`
    })
    
    // Nack the message to retry later
    message.nack()
  }
}

// Initialize Pub/Sub subscription
const initializeSubscription = () => {
  const subscription = pubsub.subscription(SUBSCRIPTION_NAME)
  
  // Configure subscription options
  subscription.options = {
    ackDeadlineSeconds: 60,
    maxMessages: 10,
    allowExcessMessages: false,
    maxExtension: 600
  }
  
  // Set up message handler
  subscription.on('message', processMessage)
  
  // Handle subscription errors
  subscription.on('error', (error) => {
    logger.error('Subscription error:', {
      error: error.message,
      stack: error.stack
    })
    stats.errors++
  })
  
  // Handle subscription close
  subscription.on('close', () => {
    logger.info('Subscription closed')
  })
  
  logger.info('Pub/Sub subscription initialized:', {
    subscriptionName: SUBSCRIPTION_NAME,
    options: subscription.options
  })
  
  return subscription
}

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
let subscription
const gracefulShutdown = (signal) => {
  logger.info(`Received ${signal}. Starting graceful shutdown...`)
  
  // Close subscription
  if (subscription) {
    subscription.close()
  }
  
  server.close(() => {
    logger.info('HTTP server closed.')
    
    // Close Google Cloud connections
    Promise.all([
      pubsub.close(),
      firestore.terminate()
    ]).then(() => {
      logger.info('Google Cloud connections closed.')
      process.exit(0)
    }).catch((error) => {
      logger.error('Error closing Google Cloud connections:', error)
      process.exit(1)
    })
  })
}

// Start server
const server = app.listen(PORT, '0.0.0.0', () => {
  logger.info(`Microservice 2 started on port ${PORT}`, {
    port: PORT,
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
    subscriptionName: SUBSCRIPTION_NAME,
    collectionName: COLLECTION_NAME
  })
  
  // Initialize Pub/Sub subscription
  subscription = initializeSubscription()
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