import React, { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/router'
import { UsersIcon, MapPinIcon, CalendarIcon, PlusIcon, MagnifyingGlassIcon, FilterIcon } from '@heroicons/react/24/outline'
import CreateGroupModal from '../../components/CreateGroupModal'
import { fetchWithAuth } from '../../utils/tokenManager'

const GroupsPage = () => {
  const [groups, setGroups] = useState([])
  const [categories, setCategories] = useState([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedCategory, setSelectedCategory] = useState('')
  const [selectedType, setSelectedType] = useState('')
  const [showCreateModal, setShowCreateModal] = useState(false)
  const router = useRouter()
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  useEffect(() => {
    loadGroups()
    loadCategories()
  }, [searchTerm, selectedCategory, selectedType])

  const loadCategories = async () => {
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/categories/`)
      if (response.ok) {
        const data = await response.json()
        const categoriesData = Array.isArray(data) ? data : data.results || []
        // Trier par nom traduit (si disponible) ou par name pour l'affichage alphabétique
        categoriesData.sort((a, b) => (a.translated_name || a.name).localeCompare(b.translated_name || b.name, 'fr'))
        setCategories(categoriesData)
      }
    } catch (error) {
      console.error('Erreur lors du chargement des catégories:', error)
    }
  }

  const loadGroups = async () => {
    try {
      const params = new URLSearchParams()
      if (searchTerm) params.append('search', searchTerm)
      if (selectedCategory) params.append('category', selectedCategory)
      if (selectedType) params.append('type', selectedType)

      const response = await fetchWithAuth(`${apiUrl}/api/groups/?${params}`)
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
        // Recharger les groupes pour mettre à jour le statut
        loadGroups()
      }
    } catch (error) {
      if (error.message.includes('Session expired')) {
        router.push('/login')
      } else {
        console.error('Erreur lors de l\'adhésion au groupe:', error)
      }
    }
  }

  const getGroupTypeLabel = (type) => {
    switch (type) {
      case 'public': return 'Public'
      case 'private': return 'Privé'
      case 'secret': return 'Secret'
      default: return type
    }
  }

  const getGroupTypeColor = (type) => {
    switch (type) {
      case 'public': return 'bg-green-100 text-green-800'
      case 'private': return 'bg-yellow-100 text-yellow-800'
      case 'secret': return 'bg-red-100 text-red-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-fopcam-600"></div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50">
      {/* Header */}
      <div className="bg-white/80 backdrop-blur-lg border-b border-future-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
            <div>
              <div className="flex flex-wrap items-center gap-3 mb-3">
                <Link
                  href="/"
                  className="inline-flex items-center rounded-full border border-future-200 bg-white px-3 py-2 text-sm font-medium text-future-700 hover:bg-future-50 transition"
                >
                  Accueil
                </Link>
                <span className="text-sm text-future-500">/ Communautés</span>
              </div>
              <h1 className="text-3xl font-bold text-future-900">Communautés</h1>
              <p className="text-future-600 mt-2">Rejoignez des groupes d'intérêt et connectez-vous avec des personnes partageant vos passions</p>
            </div>
            <button
              onClick={() => setShowCreateModal(true)}
              className="btn-primary flex items-center space-x-2"
            >
              <PlusIcon className="w-5 h-5" />
              <span>Créer un groupe</span>
            </button>
          </div>
        </div>
      </div>

      {/* Filtres */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="bg-white rounded-2xl shadow-lg p-6 mb-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* Recherche */}
            <div className="relative">
              <MagnifyingGlassIcon className="absolute left-3 top-3 h-5 w-5 text-gray-400" />
              <input
                type="text"
                placeholder="Rechercher des groupes..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
              />
            </div>

            {/* Filtre par type */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Type de groupe
              </label>
              <select
                value={selectedType}
                onChange={(e) => setSelectedType(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
              >
                <option value="">Tous les types</option>
                <option value="public">Public</option>
                <option value="private">Privé</option>
                <option value="secret">Secret</option>
              </select>
            </div>

            {/* Type de catégories */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Type de catégories
              </label>
              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
              >
                <option value="">Toutes les catégories</option>
                {categories.map((category) => (
                  <option key={category.id} value={category.id}>
                    {category.translated_name || category.name}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>

        {/* Liste des groupes */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {groups.map((group) => (
            <div key={group.id} className="bg-white rounded-2xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow">
              {/* Image de couverture */}
              <div className="h-32 bg-gradient-to-r from-fopcam-400 to-future-500 relative">
                {group.cover_image && (
                  <img
                    src={group.cover_image}
                    alt={group.name}
                    className="w-full h-full object-cover"
                  />
                )}
                <div className="absolute top-4 right-4">
                  <span className={`px-2 py-1 rounded-full text-xs font-medium ${getGroupTypeColor(group.group_type)}`}>
                    {getGroupTypeLabel(group.group_type)}
                  </span>
                </div>
              </div>

              {/* Contenu */}
              <div className="p-6">
                <div className="flex items-start space-x-3 mb-4">
                  {group.avatar ? (
                    <img
                      src={group.avatar}
                      alt={group.name}
                      className="w-12 h-12 rounded-full object-cover"
                    />
                  ) : (
                    <div className="w-12 h-12 rounded-full bg-fopcam-100 flex items-center justify-center">
                      <UsersIcon className="w-6 h-6 text-fopcam-600" />
                    </div>
                  )}
                  <div className="flex-1">
                    <h3 className="font-semibold text-gray-900 text-lg">{group.name}</h3>
                    <p className="text-sm text-gray-500">{group.category_name}</p>
                  </div>
                </div>

                <p className="text-gray-600 text-sm mb-4 line-clamp-3">{group.description}</p>

                <div className="flex items-center justify-between text-sm text-gray-500 mb-4">
                  <div className="flex items-center space-x-1">
                    <UsersIcon className="w-4 h-4" />
                    <span>{group.member_count} membres</span>
                  </div>
                  {group.location && (
                    <div className="flex items-center space-x-1">
                      <MapPinIcon className="w-4 h-4" />
                      <span>{group.location}</span>
                    </div>
                  )}
                </div>

                {/* Actions */}
                <div className="flex space-x-2">
                  {group.is_member ? (
                    <Link
                      href={`/groups/${group.id}`}
                      className="flex-1 btn-secondary text-center"
                    >
                      Voir le groupe
                    </Link>
                  ) : (
                    <button
                      onClick={() => joinGroup(group.id)}
                      className="flex-1 btn-primary text-center"
                    >
                      {group.group_type === 'public' ? 'Rejoindre' : 'Demander à rejoindre'}
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
            <h3 className="text-lg font-medium text-gray-900 mb-2">Aucun groupe trouvé</h3>
            <p className="text-gray-500">Essayez de modifier vos filtres ou créez le premier groupe !</p>
          </div>
        )}
      </div>

      {/* Create Group Modal */}
      <CreateGroupModal
        isOpen={showCreateModal}
        onClose={() => setShowCreateModal(false)}
        onCreate={() => {
          setShowCreateModal(false)
          loadGroups()
        }}
      />
    </div>
  )
}

export default GroupsPage