import axios from 'axios'
import * as SecureStore from 'expo-secure-store'

const API_BASE_URL = 'http://127.0.0.1:8000'

const client = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json'
  }
})

client.interceptors.request.use(async config => {
  const token = await SecureStore.getItemAsync('access_token')
  if (token && config.headers) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

client.interceptors.response.use(
  response => response,
  async error => {
    if (error.response?.status === 401) {
      const refreshToken = await SecureStore.getItemAsync('refresh_token')
      if (refreshToken) {
        try {
          const resp = await axios.post(`${API_BASE_URL}/api/auth/token/refresh/`, {
            refresh: refreshToken
          })
          await SecureStore.setItemAsync('access_token', resp.data.access)
          error.config.headers.Authorization = `Bearer ${resp.data.access}`
          return axios(error.config)
        } catch (refreshError) {
          await SecureStore.deleteItemAsync('access_token')
          await SecureStore.deleteItemAsync('refresh_token')
        }
      }
    }
    return Promise.reject(error)
  }
)

export async function login(email, password) {
  const response = await client.post('/api/auth/token/', { email, password })
  await SecureStore.setItemAsync('access_token', response.data.access)
  if (response.data.refresh) {
    await SecureStore.setItemAsync('refresh_token', response.data.refresh)
  }
  return response.data
}

export async function register(payload) {
  return client.post('/api/auth/register/', payload)
}

export async function getProfile() {
  return client.get('/api/auth/profile/')
}

export async function fetchProducts(params) {
  return client.get('/api/products/', { params })
}

export async function fetchProduct(productId) {
  return client.get(`/api/products/${productId}/`)
}

export async function fetchShop(shopId) {
  return client.get(`/api/shops/${shopId}/`)
}

export async function fetchGroups(params) {
  return client.get('/api/groups/', { params })
}

export async function fetchMessages(room) {
  return client.get('/api/messages/', { params: { room } })
}

export async function sendMessage(payload) {
  return client.post('/api/messages/', payload)
}

export async function fetchCategories() {
  return client.get('/api/categories/')
}

export async function createOrder(payload) {
  return client.post('/api/orders/', payload)
}

export async function logout() {
  await SecureStore.deleteItemAsync('access_token')
  await SecureStore.deleteItemAsync('refresh_token')
}

export default client
