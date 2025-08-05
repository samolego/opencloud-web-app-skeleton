<template>
  <main class="oc-p">
    <h1>Hello developer!</h1>
    <p>Great to see that you want to learn how to build web apps for OpenCloud.</p>
    <p>
      Grab a coffee and follow
      <a href="https://github.com/opencloud-eu/web-app-skeleton" target="_blank">our instructions</a
      >. Happy coding!
    </p>
    <div class="oc-mt-m oc-p-s oc-border oc-border-radius">
      <h3>Test Toggle</h3>
      <p>
        <strong>Test Value:</strong>
        <span :class="testValue ? 'oc-text-success' : 'oc-text-danger'">
          {{ testValue ? 'ON' : 'OFF' }}
        </span>
      </p>
      <p class="oc-text-muted oc-text-small">
        This is a simple test to verify component updates are working
      </p>
      <div class="oc-mt-s">
        <button class="oc-button oc-button-outline" @click="toggleValue">
          Toggle: {{ testValue ? 'Turn OFF' : 'Turn ON' }}
        </button>
      </div>
      <div class="oc-mt-s">
        <p class="oc-text-small">Current time: {{ currentTime }}</p>
      </div>
    </div>
  </main>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'

const testValue = ref(true)
const currentTime = ref('')

const toggleValue = () => {
  testValue.value = !testValue.value
  console.log('Toggled testValue to:', testValue.value)
}

onMounted(() => {
  currentTime.value = new Date().toLocaleString()
  console.log('Hello.vue component mounted at:', currentTime.value)
})
</script>

<style scoped>
.oc-text-success {
  color: #28a745;
  font-weight: bold;
}

.oc-text-danger {
  color: #dc3545;
  font-weight: bold;
}

.oc-button {
  padding: 8px 16px;
  border: 1px solid #ccc;
  border-radius: 4px;
  background: white;
  cursor: pointer;
}

.oc-button:hover {
  background: #f5f5f5;
}

code {
  background-color: #f1f3f4;
  padding: 2px 4px;
  border-radius: 3px;
  font-family: monospace;
}
</style>
