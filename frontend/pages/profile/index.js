import { useEffect, useState } from 'react'
import { useRouter } from 'next/router'

const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

export default function ProfileRedirectPage() {
  const router = useRouter()
  const [error, setError] = useState(null)

  useEffect(() => {
    async function loadCurrentProfile() {
      const token = localStorage.getItem('access_token') || localStorage.getItem('access')
      if (!token) {
        router.replace('/login')
        return
      }

      try {
        const response = await fetch(`${apiUrl}/api/auth/profile/`, {
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
        })

        if (!response.ok) {
          router.replace('/login')
          return
        }

        const profile = await response.json()
        const username = profile?.username || profile?.user?.username
        if (username) {
          router.replace(`/profile/${encodeURIComponent(username)}`)
          return
        }

        router.replace('/login')
      } catch (err) {
        console.error('Erreur de redirection profile:', err)
        setError('Impossible de charger votre profil.')
      }
    }

    loadCurrentProfile()
  }, [router])

  return (
    <div className="min-h-screen flex items-center justify-center px-4">
      <div className="text-center">
        {error ? (
          <p className="text-red-600">{error}</p>
        ) : (
          <p>Redirection vers votre profil…</p>
        )}
      </div>
    </div>
  )
}
