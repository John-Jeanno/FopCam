import { useEffect, useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/router'
import { serverSideTranslations } from 'next-i18next/serverSideTranslations'
import { ArrowLeftIcon } from '@heroicons/react/24/outline'
import StoriesBar from '../../components/StoriesBar'
import CreateStoryModal from '../../components/CreateStoryModal'
import { fetchWithAuth } from '../../utils/tokenManager'

const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

const StoriesPage = () => {
  const router = useRouter()
  const [stories, setStories] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [showCreateModal, setShowCreateModal] = useState(false)

  useEffect(() => {
    const loadStories = async () => {
      setLoading(true)
      setError(null)

      try {
        const response = await fetch(`${apiUrl}/api/stories/`)
        if (!response.ok) {
          throw new Error(`Statut ${response.status}`)
        }

        const data = await response.json()
        const storiesData = Array.isArray(data) ? data : data.results || []
        setStories(storiesData)
      } catch (err) {
        console.error('Erreur chargement des stories :', err)
        setError('Impossible de charger les stories pour le moment.')
      } finally {
        setLoading(false)
      }
    }

    loadStories()
  }, [])

  const handleCreateStory = async (formData) => {
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/stories/`, {
        method: 'POST',
        body: formData
      })

      if (!response.ok) {
        const errorData = await response.json().catch(() => null)
        const message = errorData?.detail || errorData?.message || 'Erreur lors de la création de la story.'
        throw new Error(message)
      }

      const newStory = await response.json()
      setStories(prev => [newStory, ...prev])
      setShowCreateModal(false)
    } catch (err) {
      console.error('Erreur création story :', err)
      alert(err.message || 'Impossible de créer la story.')
    }
  }

  const handleViewStory = async (storyId) => {
    try {
      await fetchWithAuth(`${apiUrl}/api/stories/${storyId}/view/`, {
        method: 'POST'
      })
    } catch (err) {
      console.error('Erreur marquage story vue :', err)
    }
  }

  const handleLikeStory = async (storyId) => {
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/stories/${storyId}/like/`, {
        method: 'POST'
      })

      if (response.ok) {
        setStories(prev => prev.map(story =>
          story.id === storyId
            ? { ...story, is_liked: !story.is_liked, likes_count: (story.likes_count || 0) + (story.is_liked ? -1 : 1) }
            : story
        ))
      }
    } catch (err) {
      console.error('Erreur like story :', err)
    }
  }

  return (
    <div className="min-h-screen bg-future-50 text-future-900">
      <header className="border-b border-future-800 bg-future-950/95 backdrop-blur sticky top-0 z-50">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-6">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => router.push('/')}
              className="inline-flex items-center gap-2 rounded-full border border-future-700 bg-white/5 px-4 py-2 text-sm font-medium text-future-200 hover:bg-future-100/10 transition-colors"
            >
              <ArrowLeftIcon className="w-4 h-4" />
              Retour
            </button>
            <h1 className="text-xl font-bold text-future-100">Histoires</h1>
          </div>

          <button
            type="button"
            onClick={() => setShowCreateModal(true)}
            className="rounded-full bg-fopcam-800 px-5 py-3 text-sm font-semibold text-white hover:bg-fopcam-900 transition"
          >
            Publier une story
          </button>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-4 py-10 sm:px-6">
        <div className="mb-8 rounded-3xl border border-future-200 bg-white shadow-sm overflow-hidden">
          <StoriesBar
            stories={stories}
            onCreateStory={() => setShowCreateModal(true)}
            onViewStory={handleViewStory}
            onLikeStory={handleLikeStory}
          />
        </div>

        <div className="space-y-6">
          {loading && (
            <div className="rounded-3xl border border-dashed border-future-300 bg-white/80 p-10 text-center text-future-600">
              Chargement des histoires...
            </div>
          )}

          {error && (
            <div className="rounded-3xl border border-red-200 bg-red-50 p-8 text-red-700">
              {error}
            </div>
          )}

          {!loading && stories.length === 0 && (
            <div className="rounded-3xl border border-future-200 bg-white p-10 text-center text-future-600">
              Aucune histoire disponible pour le moment.
            </div>
          )}

          <div className="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
            {stories.map((story) => (
              <div key={story.id} className="rounded-3xl border border-future-200 bg-white p-6 shadow-sm">
                <div className="flex items-center gap-4 mb-5">
                  <img
                    src={story.author?.profile_image || '/default-avatar.png'}
                    alt={story.author?.username}
                    className="h-14 w-14 rounded-full object-cover"
                  />
                  <div>
                    <p className="font-semibold text-future-900">{story.author?.username}</p>
                    <p className="text-sm text-future-500">
                      {story.story_type === 'image' ? 'Image' : story.story_type === 'video' ? 'Vidéo' : 'Texte'}
                    </p>
                  </div>
                </div>
                <div className="mb-5 text-future-700">
                  {story.story_type === 'text' ? (
                    <div className="rounded-2xl border border-future-100 bg-future-50 p-4 text-sm text-future-700">
                      {story.content || 'Aucun texte fourni'}
                    </div>
                  ) : (
                    <div className="overflow-hidden rounded-3xl bg-slate-950">
                      <img
                        src={story.story_type === 'image' ? story.image || '/default-avatar.png' : story.thumbnail || story.image || '/default-avatar.png'}
                        alt={story.story_type}
                        className="h-48 w-full object-cover"
                      />
                    </div>
                  )}
                </div>

                <div className="flex flex-wrap items-center justify-between gap-3 text-sm text-future-600">
                  <span>{new Date(story.created_at).toLocaleDateString('fr-FR')}</span>
                  <span>{story.is_viewed ? 'Vue' : 'Non vue'}</span>
                </div>

                <div className="mt-6 flex flex-wrap gap-3">
                  <button
                    type="button"
                    onClick={() => handleViewStory(story.id)}
                    className="inline-flex items-center justify-center rounded-full border border-future-300 bg-future-950/5 px-4 py-2 text-sm font-medium text-future-900 hover:bg-future-100 transition"
                  >
                    Voir l’histoire
                  </button>
                  <button
                    type="button"
                    onClick={() => handleLikeStory(story.id)}
                    className="inline-flex items-center justify-center rounded-full bg-fopcam-600 px-4 py-2 text-sm font-semibold text-white hover:bg-fopcam-700 transition"
                  >
                    {story.is_liked ? 'Retirer le like' : 'J’aime'}
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </main>

      <CreateStoryModal
        isOpen={showCreateModal}
        onClose={() => setShowCreateModal(false)}
        onCreate={handleCreateStory}
      />
    </div>
  )
}

export async function getServerSideProps({ locale }) {
  return {
    props: {
      ...(await serverSideTranslations(locale, ['common']))
    }
  }
}

export default StoriesPage
