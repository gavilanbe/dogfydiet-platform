import { createApp } from 'vue'
import App from './App.vue'
import './style.css'

const app = createApp(App)

// Optional: Global error handler (from your original main.ts)
app.config.errorHandler = (err, instance, info) => {
  console.error('Global error:', err, info)
  // In production, you might want to send this to a logging service
  if (process.env.NODE_ENV === 'production') {
    // Example: sendToLoggingService(err, instance, info);
  }
}

app.mount('#app')
