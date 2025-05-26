import { createApp } from 'vue'
import App from './App.vue'
import './style.css'

const app = createApp(App)

// Global error handler
app.config.errorHandler = (err, instance, info) => {
  console.error('Global error:', err, info)
  
  // In production, you might want to send this to a logging service
  if (process.env.NODE_ENV === 'production') {
    // sendToLoggingService(err, info)
  }
}

app.mount('#app')