<template>
  <div id="app-container">
    <h1>My DogfyDiet Items</h1>

    <form @submit.prevent="addItem" class="form-container">
      <input
        type="text"
        v-model="newItemName"
        placeholder="Enter item name (e.g., Favorite Toy)"
        class="input-field"
        required
      />
      <button type="submit" class="btn-primary" :disabled="isLoading">
        {{ isLoading ? 'Adding...' : 'Add Item' }}
      </button>
    </form>

    <div v-if="message" :class="['message', messageType]">
      {{ message }}
    </div>

    <div v-if="items.length === 0 && !isLoading && !initialLoadError && !message" class="message">
      No items added yet. Add one above!
    </div>

    <ul class="item-list">
      <li v-for="item in items" :key="item.id || item.name">
        {{ item.name }}
        <span v-if="item.status" :style="{ color: item.status === 'pending' ? 'orange' : 'green' }">
          ({{ item.status }})
        </span>
      </li>
    </ul>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, onMounted } from 'vue';
import axios from 'axios';

interface Item {
  id?: string | number; // Optional ID, if your backend returns one
  name: string;
  status?: 'pending' | 'confirmed'; // Example status
}

type MessageType = 'success' | 'error' | 'loading' | ''; // Allow '' for messageType ref

export default defineComponent({
  name: 'App',
  setup() {
    const newItemName = ref('');
    const items = ref<Item[]>([]);
    const isLoading = ref(false);
    const message = ref('');
    const messageType = ref<MessageType>(''); // Use the MessageType type
    const initialLoadError = ref(false);

    const apiUrl = process.env.VUE_APP_API_URL || '/api/microservice1';

    const clearMessage = () => {
      message.value = '';
      messageType.value = '';
    };

    const showMessage = (text: string, type: 'success' | 'error' | 'loading', duration: number = 3000) => {
      message.value = text;
      messageType.value = type; // Type is always one of the valid options here
      if (type !== 'loading') {
        setTimeout(clearMessage, duration);
      }
    };

    const fetchItems = async () => {
      isLoading.value = true;
      initialLoadError.value = false;
      showMessage('Loading items...', 'loading');
      try {
        // const response = await axios.get(`${apiUrl}/items`);
        // items.value = response.data;
        await new Promise(resolve => setTimeout(resolve, 500));
        if (messageType.value === 'loading') { // Clear loading message only if it's still the active one
          clearMessage();
        }
      } catch (error) {
        console.error('Error fetching items:', error);
        showMessage('Failed to load items from the server.', 'error');
        initialLoadError.value = true;
      } finally {
        isLoading.value = false;
      }
    };

    const addItem = async () => {
      if (!newItemName.value.trim()) {
        showMessage('Item name cannot be empty.', 'error');
        return;
      }

      isLoading.value = true;
      showMessage('Adding item...', 'loading');

      const itemToAdd: Item = {
        name: newItemName.value,
        status: 'pending'
      };

      items.value.push(itemToAdd);
      const currentItemIndex = items.value.length - 1;

      try {
        const response = await axios.post(`${apiUrl}/items`, { name: newItemName.value });
        
        if (response.data && items.value[currentItemIndex]) {
            items.value[currentItemIndex] = { ...items.value[currentItemIndex], ...response.data, status: 'confirmed' };
        } else if (items.value[currentItemIndex]) {
            items.value[currentItemIndex].status = 'confirmed';
        }
        
        showMessage(`Item "${newItemName.value}" added successfully!`, 'success');
        newItemName.value = '';
      } catch (error) {
        console.error('Error adding item:', error);
        showMessage(`Failed to add item "${itemToAdd.name}". Please try again.`, 'error');
        items.value.splice(currentItemIndex, 1);
      } finally {
        isLoading.value = false;
        if (messageType.value === 'loading') { // Clear loading message if not overridden by success/error
           clearMessage();
        }
      }
    };

    onMounted(() => {
      // fetchItems(); 
      console.log("VUE_APP_API_URL used by App.vue:", process.env.VUE_APP_API_URL);
      console.log("Effective API base URL for App.vue:", apiUrl);
    });

    return {
      newItemName,
      items,
      isLoading,
      addItem,
      message,
      messageType,
      initialLoadError
    };
  },
});
</script>