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
      <select v-model="newItemCategory" class="input-field" required>
        <option value="food">Food</option>
        <option value="treats">Treats</option>
        <option value="supplements">Supplements</option>
        <option value="toys">Toys</option>
      </select>
      <input
        type="text"
        v-model="newItemDescription"
        placeholder="Optional description"
        class="input-field"
      />
      <button type="submit" class="btn-primary" :disabled="isLoading">
        {{ isLoading ? 'Adding...' : 'Add Item' }}
      </button>
    </form>
    </div>
</template>

<script lang="ts">
import { defineComponent, ref, onMounted } from 'vue';
import axios, { AxiosError } from 'axios'; // <--- AÑADIR AxiosError AQUÍ

// Interfaz para la estructura de un detalle de error de validación
interface ValidationErrorDetail {
  type: string;
  value: any;
  msg: string;
  path: string;
  location: string;
}

// Interfaz para la estructura de error.response.data
interface ErrorResponseData {
  error: string;
  details?: ValidationErrorDetail[];
  requestId?: string;
}

// ... resto de tus interfaces (Item, MessageType) ...
interface Item {
  id?: string | number;
  name: string;
  category?: string;
  description?: string;
  status?: 'pending' | 'confirmed';
}

type MessageType = 'success' | 'error' | 'loading' | '';

export default defineComponent({
  name: 'App',
  setup() {
    // ... (tus refs: newItemName, newItemCategory, etc. se mantienen como en la solución anterior)
    const newItemName = ref('');
    const newItemCategory = ref('food');
    const newItemDescription = ref('');
    const items = ref<Item[]>([]);
    const isLoading = ref(false);
    const message = ref('');
    const messageType = ref<MessageType>('');
    const initialLoadError = ref(false);

    const apiUrl = process.env.VUE_APP_API_URL || '/api/microservice1';

    const clearMessage = () => { /* ... se mantiene igual ... */
      message.value = '';
      messageType.value = '';
    };

    const showMessage = (text: string, type: MessageType, duration: number = 3000) => { /* ... se mantiene igual ... */
      message.value = text;
      messageType.value = type;
      if (type !== 'loading') {
        setTimeout(clearMessage, duration);
      }
    };

    const addItem = async () => {
      if (!newItemName.value.trim() || !newItemCategory.value) {
        showMessage('Item name and category are required.', 'error');
        return;
      }

      isLoading.value = true;
      showMessage('Adding item...', 'loading');

      const itemPayload = {
        name: newItemName.value,
        category: newItemCategory.value,
        description: newItemDescription.value
      };

      const itemForUI: Item = {
        name: newItemName.value,
        category: newItemCategory.value,
        status: 'pending'
      };

      items.value.push(itemForUI);
      const currentItemIndex = items.value.length - 1;

      try {
        const response = await axios.post<{ data: Item, messageId: string, success: boolean, requestId: string }>(`${apiUrl}/items`, itemPayload);
        
        if (response.data && response.data.data && items.value[currentItemIndex]) {
          items.value[currentItemIndex] = { ...items.value[currentItemIndex], ...response.data.data, status: 'confirmed' };
        } else if (items.value[currentItemIndex]) {
          items.value[currentItemIndex].status = 'confirmed';
        }
        
        showMessage(`Item "${newItemName.value}" added successfully!`, 'success');
        newItemName.value = '';
        newItemCategory.value = 'food';
        newItemDescription.value = '';
      } catch (err) { // <--- Cambiar 'error' a 'err' o mantener 'error' y usarlo abajo
        console.error('Error adding item:', err);
        let errorMessage = `Failed to add item "${itemForUI.name}". Please try again.`;
        
        // Verificación de tipo para AxiosError y su estructura
        if (axios.isAxiosError(err)) { // Usar type guard de Axios
          const axiosError = err as AxiosError<ErrorResponseData>; // Hacer type assertion
          if (axiosError.response && axiosError.response.data && axiosError.response.data.details) {
            const errorDetails = axiosError.response.data.details.map(
              (d: ValidationErrorDetail) => `${d.path}: ${d.msg}` // <--- Especificar tipo para 'd'
            ).join('; ');
            errorMessage = `Validation failed: ${errorDetails}`;
          } else if (axiosError.response && axiosError.response.data && axiosError.response.data.error) {
            errorMessage = `Error: ${axiosError.response.data.error}`;
          } else if (axiosError.message) {
            errorMessage = axiosError.message;
          }
        } else if (err instanceof Error) { // Manejar otros errores estándar
            errorMessage = err.message;
        }
        
        showMessage(errorMessage, 'error', 5000);
        items.value.splice(currentItemIndex, 1);
      } finally {
        isLoading.value = false;
        if (messageType.value === 'loading') {
            clearMessage();
        }
      }
    };

    onMounted(() => {
      console.log("VUE_APP_API_URL used by App.vue:", process.env.VUE_APP_API_URL);
      console.log("Effective API base URL for App.vue:", apiUrl);
    });

    return {
      newItemName,
      newItemCategory,
      newItemDescription,
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