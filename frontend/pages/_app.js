import '../styles/globals.css'
import Head from 'next/head'
import { appWithTranslation } from 'next-i18next'
import { useEffect, useState } from 'react'
import ErrorBoundary from '../components/ErrorBoundary'

function App({ Component, pageProps }) {
  // Handle client-side errors
  useEffect(() => {
    const handleError = (error) => {
      console.error('Application error:', error)
    }

    const handleUnhandledRejection = (event) => {
      console.error('Unhandled promise rejection:', event.reason)
    }

    window.addEventListener('error', handleError)
    window.addEventListener('unhandledrejection', handleUnhandledRejection)

    return () => {
      window.removeEventListener('error', handleError)
      window.removeEventListener('unhandledrejection', handleUnhandledRejection)
    }
  }, [])

  return (
    <ErrorBoundary>
      <Head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="theme-color" content="#101b36" />
        <link rel="manifest" href={`${process.env.NEXT_PUBLIC_BASE_PATH || ''}/manifest.webmanifest`} />
        <link rel="icon" href={`${process.env.NEXT_PUBLIC_BASE_PATH || ''}/fopcam-icon.svg`} type="image/svg+xml" />
        <link rel="apple-touch-icon" href={`${process.env.NEXT_PUBLIC_BASE_PATH || ''}/icon-192.png`} />
      </Head>
      <Component {...pageProps} />
      <PWAInstallButton />
    </ErrorBoundary>
  )
}

function PWAInstallButton() {
  const [installPrompt, setInstallPrompt] = useState(null)
  const basePath = process.env.NEXT_PUBLIC_BASE_PATH || ''

  useEffect(() => {
    if (!('serviceWorker' in navigator)) return

    navigator.serviceWorker
      .register(`${basePath}/sw.js`, { scope: `${basePath}/` })
      .catch((error) => console.error('Impossible d’enregistrer le service worker :', error))

    const handleInstallPrompt = (event) => {
      event.preventDefault()
      setInstallPrompt(event)
    }
    const handleInstalled = () => setInstallPrompt(null)

    window.addEventListener('beforeinstallprompt', handleInstallPrompt)
    window.addEventListener('appinstalled', handleInstalled)

    return () => {
      window.removeEventListener('beforeinstallprompt', handleInstallPrompt)
      window.removeEventListener('appinstalled', handleInstalled)
    }
  }, [basePath])

  if (!installPrompt) return null

  const install = async () => {
    try {
      await installPrompt.prompt()
      await installPrompt.userChoice
      setInstallPrompt(null)
    } catch (error) {
      console.error('Impossible d’installer FopCam :', error)
    }
  }

  return (
    <button
      type="button"
      onClick={install}
      className="fixed bottom-4 right-4 z-50 rounded-full bg-fopcam-600 px-4 py-3 text-sm font-semibold text-white shadow-lg hover:bg-fopcam-700"
    >
      Installer FopCam
    </button>
  )
}

export default appWithTranslation(App)
