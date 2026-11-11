const { i18n } = require('./next-i18next.config')

/** @type {import('next').NextConfig} */
const PRODUCTION_API_URL = 'https://5nmg.l.time4vps.cloud/fopcam-api'
const PRODUCTION_WS_URL = 'wss://5nmg.l.time4vps.cloud'
const BASE_PATH = process.env.NEXT_BASE_PATH || ''

const nextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  basePath: BASE_PATH,
  poweredByHeader: false,
  env: {
    NEXT_PUBLIC_API_URL:
      process.env.NEXT_PUBLIC_API_URL ||
      (process.env.NODE_ENV === 'production' ? PRODUCTION_API_URL : 'http://127.0.0.1:8000'),
    NEXT_PUBLIC_WS_URL:
      process.env.NEXT_PUBLIC_WS_URL ||
      (process.env.NODE_ENV === 'production' ? PRODUCTION_WS_URL : 'http://127.0.0.1:8000'),
    NEXT_PUBLIC_BASE_PATH: BASE_PATH,
  },
  i18n,
}

module.exports = nextConfig
