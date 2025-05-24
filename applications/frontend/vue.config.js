const { defineConfig } = require('@vue/cli-service')

module.exports = defineConfig({
  transpileDependencies: true,
  
  // Production build configuration
  productionSourceMap: process.env.NODE_ENV !== 'production',
  
  // Development server configuration
  devServer: {
    port: 8080,
    host: '0.0.0.0',
    allowedHosts: 'all',
    historyApiFallback: true,
    proxy: {
      '/api': {
        target: process.env.VUE_APP_API_URL || 'http://localhost:3000',
        changeOrigin: true,
        secure: false,
        logLevel: 'debug'
      }
    }
  },
  
  // PWA configuration
  pwa: {
    name: 'DogfyDiet',
    themeColor: '#ec4899',
    msTileColor: '#ec4899',
    manifestOptions: {
      background_color: '#ffffff',
      display: 'standalone',
      scope: '/',
      start_url: '/',
      icons: [
        {
          src: '/android-chrome-192x192.png',
          sizes: '192x192',
          type: 'image/png'
        },
        {
          src: '/android-chrome-512x512.png',
          sizes: '512x512',
          type: 'image/png'
        }
      ]
    },
    workboxOptions: {
      skipWaiting: true,
      clientsClaim: true,
      runtimeCaching: [
        {
          urlPattern: /^https:\/\/api\./,
          handler: 'NetworkFirst',
          options: {
            cacheName: 'api-cache',
            expiration: {
              maxAgeSeconds: 60 * 60 * 24 // 24 hours
            }
          }
        }
      ]
    }
  },
  
  // Webpack configuration
  configureWebpack: {
    optimization: {
      splitChunks: {
        chunks: 'all',
        cacheGroups: {
          vendor: {
            test: /[\\/]node_modules[\\/]/,
            name: 'vendors',
            chunks: 'all'
          }
        }
      }
    }
  },
  
  // Build output configuration
  outputDir: 'dist',
  assetsDir: 'static',
  
  // CSS configuration
  css: {
    extract: process.env.NODE_ENV === 'production',
    loaderOptions: {
      postcss: {
        postcssOptions: {
          plugins: [
            require('tailwindcss'),
            require('autoprefixer')
          ]
        }
      }
    }
  }
})