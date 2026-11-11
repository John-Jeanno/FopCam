import { useState } from 'react'

export default function SeedData() {
  const [status, setStatus] = useState('Appuyez sur le bouton pour créer des données de démonstration.')
  const [loading, setLoading] = useState(false)

  const handleSeed = async () => {
    setLoading(true)
    setStatus('Génération en cours...')

    const token = localStorage.getItem('access')
    if (!token) {
      setStatus('Vous devez être connecté en tant qu’administrateur pour lancer le seed.')
      setLoading(false)
      return
    }

    const res = await fetch(process.env.NEXT_PUBLIC_API_URL + '/api/seed-sample-data/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer ' + token,
      },
    })

    if (res.ok) {
      const data = await res.json()
      setStatus('Données créées. ' + JSON.stringify(data.created))
    } else {
      const error = await res.json().catch(() => null)
      setStatus('Erreur : ' + (error?.detail || res.statusText))
    }

    setLoading(false)
  }

  return (
    <div style={{ maxWidth: 720, margin: '2rem auto', padding: '1rem' }}>
      <h1>Seed de données Agriculture / Vétérinaire</h1>
      <p>
        Cette page déclenche la création d’exemples de boutiques, produits, messages et notifications.
        Connectez-vous en tant qu’administrateur puis appuyez sur le bouton.
      </p>
      <button
        onClick={handleSeed}
        disabled={loading}
        style={{
          backgroundColor: '#2563eb',
          color: '#fff',
          padding: '0.75rem 1.25rem',
          border: 'none',
          borderRadius: 8,
          cursor: loading ? 'not-allowed' : 'pointer',
          marginTop: 16,
        }}
      >
        {loading ? 'Chargement...' : 'Créer des données de démonstration'}
      </button>
      <div style={{ marginTop: 20, whiteSpace: 'pre-line' }}>{status}</div>
    </div>
  )
}
