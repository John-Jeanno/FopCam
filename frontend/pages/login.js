import { useEffect, useState } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'
import { motion } from 'framer-motion'
import { EyeIcon, EyeSlashIcon, ArrowLeftIcon } from '@heroicons/react/24/outline'
import { useTranslation } from 'next-i18next'
import { serverSideTranslations } from 'next-i18next/serverSideTranslations'

export default function Login() {
  const { t } = useTranslation('common')
  const [form, setForm] = useState({ username: '', password: '' })
  const [msg, setMsg] = useState(null)
  const [loading, setLoading] = useState(false)
  const [showPassword, setShowPassword] = useState(false)
  const router = useRouter()

  useEffect(() => {
    if (router.query.registered === '1') {
      setMsg({
        type: 'success',
        text: t('registeredSuccess')
      })
    }
  }, [router.query.registered, t])

  const formatErrorText = (errorData, fallback) => {
    if (!errorData) return fallback
    if (typeof errorData === 'string') return errorData
    if (typeof errorData.detail === 'string') return errorData.detail
    if (typeof errorData.message === 'string') return errorData.message
    if (errorData.detail) return JSON.stringify(errorData.detail)
    if (errorData.message) return JSON.stringify(errorData.message)
    return JSON.stringify(errorData)
  }

  const submit = async e => {
    e.preventDefault()
    setLoading(true)
    setMsg(null)

    const apiUrl =
      process.env.NEXT_PUBLIC_API_URL?.trim().replace(/\/$/, '') ||
      (process.env.NODE_ENV === 'production'
        ? 'https://5nmg.l.time4vps.cloud'
        : 'http://127.0.0.1:8000')

    try {
      const res = await fetch(`${apiUrl}/api/auth/token/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form)
      })

      if (res.ok) {
        const data = await res.json()
        
        // Store tokens in localStorage for development
        if (data.access && data.refresh) {
          localStorage.setItem('access_token', data.access)
          localStorage.setItem('refresh_token', data.refresh)
          localStorage.setItem('access', data.access)
          localStorage.setItem('refresh', data.refresh)
        }
        
        // Try to get profile with token from localStorage
        const accessToken = localStorage.getItem('access_token')
        const profileRes = await fetch(apiUrl + '/api/auth/profile/', {
          headers: {
            'Authorization': `Bearer ${accessToken}`
          }
        })

        if (profileRes.ok) {
          const profile = await profileRes.json()
          const isProducerCandidate = profile?.role === 'producer' || !!profile?.shop_id
          const redirectUrl = router.query.next || (isProducerCandidate ? '/producer/dashboard' : '/client/dashboard')
          setMsg({ type: 'success', text: t('successRedirect') })
          router.replace(redirectUrl)
        } else {
          setMsg({ type: 'success', text: t('successRedirect') })
          router.replace('/')
        }
      } else {
        const error = await res.json().catch(() => null)
        const fallbackMessage = res.status === 401 || res.status === 400 ? t('invalidCredentials') : t('serverUnavailable')
        setMsg({
          type: 'error',
          text: `Erreur ${res.status} : ${formatErrorText(error, fallbackMessage)}`
        })
      }
    } catch (error) {
      console.error('Login error:', error)
      setMsg({
        type: 'error',
        text: `${t('serverUnavailable')} Vérifiez que le backend est démarré.`
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-900 via-future-800 to-focal-900 flex items-center justify-center p-4">
      {/* Background Pattern */}
      <div className="absolute inset-0 opacity-10">
        <div className="absolute inset-0" style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23ffffff' fill-opacity='0.1'%3E%3Ccircle cx='30' cy='30' r='2'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")`,
        }}></div>
      </div>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="relative w-full max-w-md"
      >
        {/* Back Button */}
        <Link href="/" className="inline-flex items-center text-future-300 hover:text-white transition-colors mb-8">
          <ArrowLeftIcon className="w-5 h-5 mr-2" />
          {t('home')}
        </Link>

        {/* Login Card */}
        <div className="glass-effect rounded-3xl p-8 shadow-2xl">
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.2 }}
            className="text-center mb-8"
          >
            <div className="w-40 h-40 rounded-2xl flex items-center justify-center mx-auto mb-4 overflow-hidden bg-white/10">
              <img src={`${process.env.NEXT_PUBLIC_BASE_PATH || ''}/fopcam-logo.png`} alt="FopCam" className="w-full h-full object-contain" />
            </div>
            <p className="text-future-300">{t('title')}</p>
          </motion.div>

          <form onSubmit={submit} className="space-y-6">
            <motion.div
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.3 }}
            >
              <label className="block text-sm font-medium text-future-200 mb-2">
                {t('usernameLabel')}
              </label>
              <input
                type="text"
                value={form.username}
                onChange={e => setForm({ ...form, username: e.target.value })}
                className="input-field bg-white/10 border-white/20 text-white placeholder-future-400 focus:border-fopcam-400 focus:ring-fopcam-400/20"
                placeholder={t('usernamePlaceholder')}
                required
              />
            </motion.div>

            <motion.div
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.4 }}
            >
              <label className="block text-sm font-medium text-future-200 mb-2">
                {t('passwordLabel')}
              </label>
              <div className="relative">
                <input
                  type={showPassword ? "text" : "password"}
                  value={form.password}
                  onChange={e => setForm({ ...form, password: e.target.value })}
                  className="input-field bg-white/10 border-white/20 text-white placeholder-future-400 focus:border-fopcam-400 focus:ring-fopcam-400/20 pr-12"
                  placeholder={t('passwordPlaceholder')}
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2 text-future-400 hover:text-future-200 transition-colors"
                >
                  {showPassword ? (
                    <EyeSlashIcon className="w-5 h-5" />
                  ) : (
                    <EyeIcon className="w-5 h-5" />
                  )}
                </button>
              </div>
            </motion.div>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.5 }}
            >
              <button
                type="submit"
                disabled={loading}
                className="w-full btn-primary bg-gradient-fopcam hover:bg-gradient-fopcam disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
              >
                {loading ? (
                  <div className="flex items-center justify-center">
                    <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>
                    {t('loading')}
                  </div>
                ) : (
                  t('button')
                )}
              </button>
            </motion.div>
          </form>

          {/* Message */}
          {msg && (
            <motion.div
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              className={`mt-6 p-4 rounded-xl ${
                msg.type === 'success'
                  ? 'bg-fopcam-500/20 border border-fopcam-400/30 text-fopcam-200'
                  : 'bg-red-500/20 border border-red-400/30 text-red-200'
              }`}
            >
              {msg.text}
            </motion.div>
          )}

          {/* Links */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.6 }}
            className="mt-8 text-center space-y-2"
          >
            <p className="text-future-300">
              {t('registerPrompt')}{' '}
              <Link href="/register" className="text-fopcam-400 hover:text-fopcam-300 font-medium transition-colors">
                {t('registerLink')}
              </Link>
            </p>
            <p className="text-future-400 text-sm">
              <a href="#" className="hover:text-future-300 transition-colors">
                {t('forgotPassword')}
              </a>
            </p>
          </motion.div>
        </div>


        {/* Footer */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.8 }}
          className="text-center mt-8 text-white/80 text-sm px-4"
        >
          <p className="break-words">© 2025 FopCam - Le premier réseau social et marketplace pour connecter vendeurs et consommateurs en circuit court</p>
        </motion.div>
      </motion.div>
    </div>
  )
}

export async function getServerSideProps({ locale }) {
  return {
    props: {
      ...(await serverSideTranslations(locale, ['common'])),
    },
  }
}
