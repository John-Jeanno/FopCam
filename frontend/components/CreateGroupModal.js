import React, { useState, useEffect } from 'react'
import { XMarkIcon, PhotoIcon } from '@heroicons/react/24/outline'
import { fetchWithAuth } from '../utils/tokenManager'

const CreateGroupModal = ({ isOpen, onClose, onCreate }) => {
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    group_type: 'public',
    category: '',
    location: '',
    rules: ''
  })
  const [coverImage, setCoverImage] = useState(null)
  const [avatarImage, setAvatarImage] = useState(null)
  const [categories, setCategories] = useState([])
  const [loading, setLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  useEffect(() => {
    if (isOpen) {
      loadCategories()
    }
  }, [isOpen])

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

  const handleInputChange = (e) => {
    const { name, value } = e.target
    setFormData(prev => ({
      ...prev,
      [name]: value
    }))
  }

  const handleFileChange = (e, type) => {
    const file = e.target.files[0]
    if (type === 'cover') {
      setCoverImage(file)
    } else if (type === 'avatar') {
      setAvatarImage(file)
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setErrorMessage('')
    setLoading(true)

    try {
      const token = localStorage.getItem('access_token') || localStorage.getItem('access')
      if (!token) {
        setErrorMessage('Vous devez être connecté pour créer un groupe.')
        return
      }

      const submitData = new FormData()

      // Ajouter les champs texte
      Object.keys(formData).forEach(key => {
        if (formData[key]) {
          submitData.append(key, formData[key])
        }
      })

      // Ajouter les images
      if (coverImage) {
        submitData.append('cover_image', coverImage)
      }
      if (avatarImage) {
        submitData.append('avatar', avatarImage)
      }

      const response = await fetchWithAuth(`${apiUrl}/api/groups/`, {
        method: 'POST',
        body: submitData
      })

      if (response.ok) {
        const newGroup = await response.json()
        onCreate(newGroup)
        onClose()
        // Reset form
        setFormData({
          name: '',
          description: '',
          group_type: 'public',
          category: '',
          location: '',
          rules: ''
        })
        setCoverImage(null)
        setAvatarImage(null)
      } else {
        const error = await response.json().catch(() => null)
        const detail = error?.detail || error || 'Impossible de créer le groupe. Vérifiez les informations et réessayez.'
        setErrorMessage(typeof detail === 'string' ? detail : JSON.stringify(detail))
        console.error('Erreur lors de la création du groupe:', error)
      }
    } catch (error) {
      console.error('Erreur lors de la création du groupe:', error)
    } finally {
      setLoading(false)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div className="p-6 border-b border-gray-200">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-bold text-gray-900">Créer un nouveau groupe</h2>
            <button
              onClick={onClose}
              className="p-2 hover:bg-gray-100 rounded-full transition-colors"
            >
              <XMarkIcon className="w-6 h-6" />
            </button>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* Nom du groupe */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Nom du groupe *
            </label>
            <input
              type="text"
              name="name"
              value={formData.name}
              onChange={handleInputChange}
              required
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
              placeholder="Entrez le nom de votre groupe"
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Description *
            </label>
            <textarea
              name="description"
              value={formData.description}
              onChange={handleInputChange}
              required
              rows={3}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
              placeholder="Décrivez votre groupe et ses objectifs"
            />
          </div>

          {/* Type de groupe */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Type de groupe *
            </label>
            <select
              name="group_type"
              value={formData.group_type}
              onChange={handleInputChange}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
            >
              <option value="public">Public - Tout le monde peut voir et rejoindre</option>
              <option value="private">Privé - Visible mais nécessite une approbation</option>
              <option value="secret">Secret - Invisible, invitation seulement</option>
            </select>
          </div>

          {/* Catégorie */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Catégorie
            </label>
            <select
              name="category"
              value={formData.category}
              onChange={handleInputChange}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
            >
              <option value="">Sélectionner une catégorie</option>
              {categories.map((category) => (
                <option key={category.id} value={category.id}>
                  {category.translated_name || category.name}
                </option>
              ))}
            </select>
          </div>

          {/* Images */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Image de couverture */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Image de couverture
              </label>
              <div className="relative">
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => handleFileChange(e, 'cover')}
                  className="hidden"
                  id="cover-image"
                />
                <label
                  htmlFor="cover-image"
                  className="flex items-center justify-center w-full h-32 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-fopcam-500 transition-colors"
                >
                  {coverImage ? (
                    <img
                      src={URL.createObjectURL(coverImage)}
                      alt="Cover preview"
                      className="w-full h-full object-cover rounded-lg"
                    />
                  ) : (
                    <div className="text-center">
                      <PhotoIcon className="w-8 h-8 text-gray-400 mx-auto mb-2" />
                      <span className="text-sm text-gray-500">Image de couverture</span>
                    </div>
                  )}
                </label>
              </div>
            </div>

            {/* Avatar du groupe */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Avatar du groupe
              </label>
              <div className="relative">
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => handleFileChange(e, 'avatar')}
                  className="hidden"
                  id="avatar-image"
                />
                <label
                  htmlFor="avatar-image"
                  className="flex items-center justify-center w-full h-32 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-fopcam-500 transition-colors"
                >
                  {avatarImage ? (
                    <img
                      src={URL.createObjectURL(avatarImage)}
                      alt="Avatar preview"
                      className="w-full h-full object-cover rounded-full"
                    />
                  ) : (
                    <div className="text-center">
                      <PhotoIcon className="w-8 h-8 text-gray-400 mx-auto mb-2" />
                      <span className="text-sm text-gray-500">Avatar du groupe</span>
                    </div>
                  )}
                </label>
              </div>
            </div>
          </div>

          {/* Règles */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Règles du groupe (optionnel)
            </label>
            <textarea
              name="rules"
              value={formData.rules}
              onChange={handleInputChange}
              rows={3}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
              placeholder="Définissez les règles et guidelines de votre groupe"
            />
          </div>

          {/* Erreur */}
          {errorMessage && (
            <div className="rounded-lg bg-red-50 border border-red-200 text-red-700 px-4 py-3">
              {errorMessage}
            </div>
          )}

          {/* Actions */}
          <div className="flex space-x-4 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 btn-secondary"
              disabled={loading}
            >
              Annuler
            </button>
            <button
              type="submit"
              className="flex-1 btn-primary"
              disabled={loading}
            >
              {loading ? 'Création...' : 'Créer le groupe'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default CreateGroupModal