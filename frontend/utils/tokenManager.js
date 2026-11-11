const PRODUCTION_API_URL = 'https://5nmg.l.time4vps.cloud'
const API_URL =
  process.env.NEXT_PUBLIC_API_URL ||
  (process.env.NODE_ENV === 'production'
    ? PRODUCTION_API_URL
    : 'http://127.0.0.1:8000')

const isJwtToken = token => {
  return typeof token === 'string' && token.split('.').length === 3
}

const getTokenFromStorage = (...keys) => {
  for (const key of keys) {
    const token = localStorage.getItem(key)
    if (token && isJwtToken(token)) {
      return token
    }
  }
  return null
}

export function getAccessToken() {
  return getTokenFromStorage('access_token', 'access')
}

export function getRefreshToken() {
  return getTokenFromStorage('refresh_token', 'refresh')
}

/**
 * Refresh the JWT access token using the refresh token
 */
export async function refreshAccessToken() {
  try {
    const refreshToken = getRefreshToken()
    if (!refreshToken) {
      console.warn('No valid refresh token available')
      clearTokens()
      return null
    }

    const response = await fetch(`${API_URL}/api/auth/token/refresh/`, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh: refreshToken })
    })

    if (response.ok) {
      const data = await response.json()
      if (data.access) {
        localStorage.setItem('access_token', data.access)
        localStorage.setItem('access', data.access)
        return data.access
      }
      clearTokens()
      return null
    }

    console.warn('Refresh token invalid - user needs to re-login')
    clearTokens()
    return null
  } catch (error) {
    console.error('Error refreshing token:', error)
    clearTokens()
    return null
  }
}

/**
 * Get a valid access token, refreshing if necessary
 */
export async function getValidAccessToken() {
  const token = getAccessToken()
  return token || null
}

/**
 * Make a fetch request with automatic token refresh
 * Works with or without authentication - if user is authenticated, adds Authorization header
 * If not authenticated, makes the request without auth (for public endpoints)
 */
export async function fetchWithAuth(url, options = {}) {
  const token = getAccessToken()
  const headers = { ...options.headers }

  if (token) {
    headers['Authorization'] = `Bearer ${token}`
  }

  // Ensure cookies (httpOnly) are sent when backend relies on them
  const fetchOptions = { ...options, headers, credentials: options.credentials || 'include' }

  let response = await fetch(url, fetchOptions)

  if (response.status === 401 && token) {
    console.log('Token expired, attempting refresh...')
    const newToken = await refreshAccessToken()

    if (newToken) {
      headers.Authorization = `Bearer ${newToken}`
      const retryOptions = { ...options, headers, credentials: options.credentials || 'include' }
      response = await fetch(url, retryOptions)
    } else {
      // Keep auth handling at the page/component level instead of forcing a redirect here.
      // The caller can inspect response.status and decide whether to redirect to login.
      return response
    }
  }

  return response
}

/**
 * Clear stored tokens
 */
export function clearTokens() {
  localStorage.removeItem('access_token')
  localStorage.removeItem('access')
  localStorage.removeItem('refresh_token')
  localStorage.removeItem('refresh')
}

/**
 * Check if user has a valid token
 */
export function hasValidToken() {
  return !!getAccessToken()
}
