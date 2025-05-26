<template>
  <div id="app" class="min-h-screen bg-gradient-to-br from-pink-50 to-purple-50">
    <!-- Header -->
    <header class="bg-white shadow-sm border-b-2 border-pink-200">
      <div class="max-w-4xl mx-auto px-4 py-6">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <div class="w-10 h-10 bg-gradient-to-r from-pink-400 to-purple-400 rounded-full flex items-center justify-center">
              <Heart class="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 class="text-2xl font-bold text-gray-800">DogfyDiet</h1>
              <p class="text-sm text-gray-600">Healthy treats for happy pups! 🐕</p>
            </div>
          </div>
          <div class="flex items-center space-x-2 text-sm text-gray-500">
            <Activity class="w-4 h-4" />
            <span>{{ itemCount }} items added</span>
          </div>
        </div>
      </div>
    </header>

    <!-- Main Content -->
    <main class="max-w-4xl mx-auto px-4 py-8">
      <!-- Add Item Section -->
      <div class="bg-white rounded-2xl shadow-lg p-6 mb-8 border border-pink-100">
        <h2 class="text-xl font-semibold text-gray-800 mb-4 flex items-center">
          <Plus class="w-5 h-5 mr-2 text-pink-500" />
          Add New Item
        </h2>
        
        <form @submit.prevent="addItem" class="space-y-4">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label for="itemName" class="block text-sm font-medium text-gray-700 mb-2">
                Item Name
              </label>
              <input
                id="itemName"
                v-model="newItem.name"
                type="text"
                required
                placeholder="e.g., Premium Dog Treats"
                class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-pink-500 focus:border-transparent transition-all duration-200"
              />
            </div>
            
            <div>
              <label for="itemCategory" class="block text-sm font-medium text-gray-700 mb-2">
                Category
              </label>
              <select
                id="itemCategory"
                v-model="newItem.category"
                required
                class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-pink-500 focus:border-transparent transition-all duration-200"
              >
                <option value="">Select a category</option>
                <option value="treats">Treats</option>
                <option value="food">Food</option>
                <option value="supplements">Supplements</option>
                <option value="toys">Toys</option>
              </select>
            </div>
          </div>
          
          <div>
            <label for="itemDescription" class="block text-sm font-medium text-gray-700 mb-2">
              Description
            </label>
            <textarea
              id="itemDescription"
              v-model="newItem.description"
              rows="3"
              placeholder="Describe this item..."
              class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-pink-500 focus:border-transparent transition-all duration-200 resize-none"
            ></textarea>
          </div>
          
          <button
            type="submit"
            :disabled="isLoading"
            class="w-full bg-gradient-to-r from-pink-500 to-purple-500 text-white font-medium py-3 px-6 rounded-xl hover:from-pink-600 hover:to-purple-600 focus:outline-none focus:ring-2 focus:ring-pink-500 focus:ring-offset-2 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
          >
            <Loader2 v-if="isLoading" class="w-5 h-5 mr-2 animate-spin" />
            <Plus v-else class="w-5 h-5 mr-2" />
            {{ isLoading ? 'Adding Item...' : 'Add Item' }}
          </button>
        </form>
      </div>

      <!-- Items List -->
      <div class="bg-white rounded-2xl shadow-lg p-6 border border-pink-100">
        <h2 class="text-xl font-semibold text-gray-800 mb-6 flex items-center">
          <Package class="w-5 h-5 mr-2 text-purple-500" />
          Items List
        </h2>

        <!-- Loading State -->
        <div v-if="isLoadingItems" class="flex items-center justify-center py-8">
          <Loader2 class="w-8 h-8 animate-spin text-pink-500" />
          <span class="ml-3 text-gray-600">Loading items...</span>
        </div>

        <!-- Empty State -->
        <div v-else-if="items.length === 0" class="text-center py-12">
          <Package class="w-16 h-16 text-gray-300 mx-auto mb-4" />
          <h3 class="text-lg font-medium text-gray-500 mb-2">No items yet</h3>
          <p class="text-gray-400">Add your first item to get started!</p>
        </div>

        <!-- Items Grid -->
        <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div
            v-for="item in items"
            :key="item.id"
            class="bg-gradient-to-br from-gray-50 to-gray-100 rounded-xl p-4 hover:shadow-md transition-all duration-200 border border-gray-200"
          >
            <div class="flex items-start justify-between mb-3">
              <h3 class="font-semibold text-gray-800 truncate mr-2">{{ item.name }}</h3>
              <span class="px-2 py-1 text-xs font-medium bg-pink-100 text-pink-800 rounded-full whitespace-nowrap">
                {{ item.category }}
              </span>
            </div>
            
            <p v-if="item.description" class="text-sm text-gray-600 mb-3 line-clamp-2">
              {{ item.description }}
            </p>
            
            <div class="flex items-center justify-between text-xs text-gray-500">
              <span class="flex items-center">
                <Clock class="w-3 h-3 mr-1" />
                {{ formatDate(item.timestamp) }}
              </span>
              <span class="flex items-center">
                <CheckCircle class="w-3 h-3 mr-1 text-green-500" />
                Added
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Stats Section -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mt-8">
        <div class="bg-white rounded-xl p-4 text-center border border-pink-100">
          <div class="text-2xl font-bold text-pink-600">{{ itemCount }}</div>
          <div class="text-sm text-gray-600">Total Items</div>
        </div>
        <div class="bg-white rounded-xl p-4 text-center border border-purple-100">
          <div class="text-2xl font-bold text-purple-600">{{ categoryCount }}</div>
          <div class="text-sm text-gray-600">Categories</div>
        </div>
        <div class="bg-white rounded-xl p-4 text-center border border-blue-100">
          <div class="text-2xl font-bold text-blue-600">{{ todayCount }}</div>
          <div class="text-sm text-gray-600">Added Today</div>
        </div>
        <div class="bg-white rounded-xl p-4 text-center border border-green-100">
          <div class="text-2xl font-bold text-green-600">{{ isApiHealthy ? 'Online' : 'Offline' }}</div>
          <div class="text-sm text-gray-600">API Status</div>
        </div>
      </div>
    </main>

    <!-- Toast Notifications -->
    <div
      v-if="notification.show"
      class="fixed top-4 right-4 z-50 bg-white border border-gray-200 rounded-xl shadow-lg p-4 max-w-sm transform transition-all duration-300"
      :class="notification.type === 'success' ? 'border-green-200 bg-green-50' : 'border-red-200 bg-red-50'"
    >
      <div class="flex items-center">
        <CheckCircle v-if="notification.type === 'success'" class="w-5 h-5 text-green-600 mr-3" />
        <AlertCircle v-else class="w-5 h-5 text-red-600 mr-3" />
        <span class="text-sm font-medium text-gray-800">{{ notification.message }}</span>
      </div>
    </div>
  </div>
</template>

<script>
</script>
import { ref, computed, onMounted } from 'vue'
import axios from 'axios'
import {
  Heart,
  Plus,
  Package,
  Activity,
  Clock,
  CheckCircle,
  AlertCircle,
  Loader2
} from 'lucide-vue-next'

export default {
  name: 'App',
  components: {
    Heart,
    Plus,
    Package,
    Activity,
    Clock,
    CheckCircle,
    AlertCircle,
    Loader2
  },
  setup() {
    // Reactive state
    const items = ref([])
    const newItem = ref({
      name: '',
      category: '',
      description: ''
    })
    const isLoading = ref(false)
    const isLoadingItems = ref(false)
    const isApiHealthy = ref(true)
    const notification = ref({
      show: false,
      type: 'success',
      message: ''
    })

    // API configuration
    const API_BASE_URL = process.env.VUE_APP_API_URL || 'http://localhost:3000'

    // Computed properties
    const itemCount = computed(() => items.value.length)
    const categoryCount = computed(() => new Set(items.value.map(item => item.category)).size)
    const todayCount = computed(() => {
      const today = new Date().toDateString()
      return items.value.filter(item => new Date(item.timestamp).toDateString() === today).length
    })

    // Methods
    const showNotification = (message, type = 'success') => {
      notification.value = { show: true, message, type }
      setTimeout(() => {
        notification.value.show = false
      }, 3000)
    }

    const formatDate = (timestamp) => {
      return new Date(timestamp).toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      })
    }

    const addItem = async () => {
      if (!newItem.value.name.trim()) return

      isLoading.value = true
      
      try {
        const itemData = {
          ...newItem.value,
          timestamp: new Date().toISOString(),
          id: Date.now().toString()
        }

        const response = await axios.post(`${API_BASE_URL}/api/items`, itemData, {
          timeout: 10000,
          headers: {
            'Content-Type': 'application/json'
          }
        })

        // Add to local state immediately for better UX
        items.value.unshift(itemData)
        
        // Reset form
        newItem.value = { name: '', category: '', description: '' }
        
        showNotification('Item added successfully! 🎉')
        isApiHealthy.value = true
        
      } catch (error) {
        console.error('Error adding item:', error)
        showNotification('Failed to add item. Please try again.', 'error')
        isApiHealthy.value = false
      } finally {