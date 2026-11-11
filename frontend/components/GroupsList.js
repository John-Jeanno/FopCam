import React, { useState, useEffect } from 'react'
import Link from 'next/link'
import { UsersIcon, PlusIcon, LockClosedIcon, GlobeAltIcon } from '@heroicons/react/24/outline'
import { fetchWithAuth } from '../utils/tokenManager'

const GroupsList = ({ user }) => {
  const [groups, setGroups] = useState([])
  const [loading, setLoading] = useState(true)
  const [showCreateModal, setShowCreateModal] = useState(false)

  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  useEffect(() => {
    if (user) {
      loadGroups()
    }
  }, [user])

  const loadGroups = async () => {
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/`)
      if (response.ok) {
        const data = await response.json()
        setGroups(data)
      }
    } catch (error) {
      console.error('Erreur lors du chargement des groupes:', error)
    } finally {
      setLoading(false)
    }
  }

  const joinGroup = async (groupId) => {
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/${groupId}/join/`, {
        method: 'POST'
      })

      if (response.ok) {
        loadGroups()
      }
    } catch (error) {
      console.error('Erreur lors de l\'adhésion au groupe:', error)
    }
  }

  if (loading) {
    return (
      <div className="flex justify-center items-center py-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-fopcam-600"></div>
      </div>
    )
  }

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Header */}
      <div className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Groupes Communautaires</h1>
          <p className="text-gray-600 mt-2">Rejoignez des communautés d'intérêt et partagez vos expériences</p>
        </div>
        {user && (
          <button
            onClick={() => setShowCreateModal(true)}
            className="btn-primary flex items-center space-x-2"
          >
            <PlusIcon className="w-5 h-5" />
            <span>Créer un groupe</span>
          </button>
        )}
      </div>

      {/* Groups Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {groups.map((group) => (
          <div key={group.id} className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow">
            {/* Cover Image */}
            <div className="h-32 bg-gradient-to-r from-fopcam-400 to-future-400 relative">
              {group.cover_image && (
                <img
                  src={group.cover_image}
                  alt={group.name}
                  className="w-full h-full object-cover"
                />
              )}
              <div className="absolute top-3 right-3">
                {group.group_type === 'private' ? (
                  <LockClosedIcon className="w-6 h-6 text-white bg-black bg-opacity-50 rounded-full p-1" />
                ) : (
                  <GlobeAltIcon className="w-6 h-6 text-white bg-black bg-opacity-50 rounded-full p-1" />
                )}
              </div>
            </div>

            {/* Content */}
            <div className="p-6">
              <h3 className="text-xl font-semibold text-gray-900 mb-2">{group.name}</h3>
              <p className="text-gray-600 text-sm mb-4 line-clamp-2">{group.description}</p>

              {/* Stats */}
              <div className="flex items-center justify-between text-sm text-gray-500 mb-4">
                <div className="flex items-center space-x-1">
                  <UsersIcon className="w-4 h-4" />
                  <span>{group.member_count} membres</span>
                </div>
                <span>{group.post_count} publications</span>
              </div>

              {/* Category */}
              {group.category_name && (
                <span className="inline-block bg-fopcam-100 text-fopcam-800 text-xs px-2 py-1 rounded-full mb-4">
                  {group.category_name}
                </span>
              )}

              {/* Action Button */}
              <div className="flex justify-between items-center">
                <Link
                  href={`/groups/${group.slug}`}
                  className="btn-secondary text-sm flex-1 mr-2"
                >
                  Voir le groupe
                </Link>

                {group.is_member ? (
                  <span className="text-green-600 text-sm font-medium">Membre</span>
                ) : (
                  <button
                    onClick={() => joinGroup(group.id)}
                    className="btn-primary text-sm"
                  >
                    Rejoindre
                  </button>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>

      {groups.length === 0 && (
        <div className="text-center py-12">
          <UsersIcon className="w-16 h-16 text-gray-300 mx-auto mb-4" />
          <h3 className="text-xl font-medium text-gray-900 mb-2">Aucun groupe trouvé</h3>
          <p className="text-gray-600 mb-6">Soyez le premier à créer un groupe communautaire !</p>
          {user && (
            <button
              onClick={() => setShowCreateModal(true)}
              className="btn-primary"
            >
              Créer le premier groupe
            </button>
          )}
        </div>
      )}

      {/* Create Group Modal */}
      {showCreateModal && (
        <CreateGroupModal
          onClose={() => setShowCreateModal(false)}
          onCreate={loadGroups}
        />
      )}
    </div>
  )
}

export default GroupsList