import { useState, useEffect } from 'react'
import { useRouter } from 'next/router'
import { motion } from 'framer-motion'
import { ArrowLeftIcon, PhotoIcon, TagIcon, PencilIcon } from '@heroicons/react/24/outline'
import { fetchWithAuth, getAccessToken } from '../../../utils/tokenManager'

export default function EditProduct() {
  const router = useRouter()
  const { id } = router.query
  const [form, setForm] = useState({
    title: '',
    description: '',
    price: '',
    quantity: 1,
    category_id: ''
  })
  const [file, setFile] = useState(null)
  const [currentImage, setCurrentImage] = useState(null)
  const [msg, setMsg] = useState(null)
  const [loading, setLoading] = useState(false)
  const [loadingData, setLoadingData] = useState(true)
  const [categories, setCategories] = useState([])

  useEffect(() => {
    const token = getAccessToken()
    if (!token) {
      router.replace('/login')
      return
    }

    // Charger les catégories (filtrer pour les produits seulement)
    fetch(process.env.NEXT_PUBLIC_API_URL + '/api/categories/')
      .then(r => r.json())
      .then(data => {
        const categoriesData = Array.isArray(data) ? data : data?.results || []
        const productCategories = categoriesData
          .filter(cat => cat.category_type === 'product')
          .sort((a, b) => (a.translated_name || a.name).localeCompare(b.translated_name || b.name, 'fr'))
        setCategories(productCategories)
      })
      .catch(err => console.log('Erreur chargement catégories'))

    // Charger les données du produit
    if (id) {
      fetchWithAuth(process.env.NEXT_PUBLIC_API_URL + '/api/products/' + id + '/')
        .then(r => {
          if (!r.ok) throw new Error('Impossible de charger le produit')
          return r.json()
        })
        .then(data => {
          setForm({
            title: data.title || '',
            description: data.description || '',
            price: data.price || '',
            quantity: data.quantity || 1,
            category_id: data.category ? data.category.id : ''
          })
          if (data.image) {
            setCurrentImage(data.image)
          }
          setLoadingData(false)
        })
        .catch(err => {
          console.log('Erreur chargement produit', err)
          setLoadingData(false)
        })
    }
  }, [id])

  const submit = async e => {
    e.preventDefault()
    if (!id) {
      setMsg({ type: 'error', text: 'Impossible de modifier : identifiant du produit introuvable.' })
      return
    }

    setLoading(true)
    setMsg(null)

    const token = getAccessToken()
    if (!token) {
      setMsg({ type: 'error', text: 'Vous devez être connecté' })
      setLoading(false)
      return
    }

    if (!form.category_id) {
      setMsg({ type: 'error', text: 'Veuillez sélectionner une catégorie avant de sauvegarder.' })
      setLoading(false)
      return
    }

    const fd = new FormData()
    fd.append('title', form.title)
    fd.append('description', form.description)
    fd.append('price', form.price)
    fd.append('quantity', form.quantity)
    fd.append('category_id', form.category_id)
    if (file) fd.append('image', file)

    try {
      const res = await fetchWithAuth(process.env.NEXT_PUBLIC_API_URL + '/api/products/' + id + '/', {
        method: 'PATCH',
        body: fd
      })

      if (res.ok) {
        setMsg({ type: 'success', text: 'Produit modifié avec succès !' })
        setTimeout(() => router.push('/producer/dashboard'), 2000)
      } else {
        let errorText = 'Erreur lors de la modification du produit'
        try {
          const error = await res.json()
          errorText = error?.detail || error?.message || JSON.stringify(error)
        } catch (_) {
          // ignore invalid json
        }
        setMsg({ type: 'error', text: errorText })
      }
    } catch (error) {
      setMsg({ type: 'error', text: 'Erreur de connexion au serveur' })
    } finally {
      setLoading(false)
    }
  }

  const inputFields = [
    {
      name: 'title',
      label: 'Titre du produit',
      type: 'text',
      placeholder: 'Tomates bio du jardin',
      required: true
    },
    {
      name: 'description',
      label: 'Description',
      type: 'textarea',
      placeholder: 'Décrivez votre produit, ses qualités, son origine...',
      required: true
    },
    {
      name: 'price',
      label: 'Prix (FCFA)',
      type: 'number',
      placeholder: '5000',
      step: '0.01',
      required: true
    },
    {
      name: 'quantity',
      label: 'Quantité disponible',
      type: 'number',
      placeholder: '10',
      min: '1',
      required: true
    }
  ]

  if (loadingData) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-future-900 via-future-800 to-fopcam-900 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-fopcam-400"></div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-900 via-future-800 to-fopcam-900 p-4">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-8"
        >
          <button
            onClick={() => router.back()}
            className="inline-flex items-center text-future-300 hover:text-white transition-colors mb-4"
          >
            <ArrowLeftIcon className="w-5 h-5 mr-2" />
            Retour
          </button>

          <div className="text-center">
            <div className="w-16 h-16 bg-gradient-fopcam rounded-2xl flex items-center justify-center mx-auto mb-4">
              <PencilIcon className="w-8 h-8 text-white" />
            </div>
            <h1 className="text-3xl font-bold text-white mb-2">Modifier le produit</h1>
            <p className="text-future-300">Mettez à jour les informations de votre produit</p>
          </div>
        </motion.div>

        {/* Form */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="glass-effect rounded-3xl p-8 shadow-2xl"
        >
          <form onSubmit={submit} className="space-y-6" encType="multipart/form-data">
            {/* Category Selection */}
            <motion.div
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.3 }}
            >
              <label className="block text-sm font-medium text-future-200 mb-2">
                Catégorie <span className="text-red-400">*</span>
              </label>
              <div className="relative">
                <select
                  value={form.category_id}
                  onChange={e => setForm({ ...form, category_id: e.target.value })}
                  className="input-field bg-white/10 border-white/20 text-white focus:border-fopcam-400 focus:ring-fopcam-400/20"
                  required
                >
                  <option value="" disabled hidden>Sélectionnez une catégorie</option>
                  {categories.map(cat => (
                    <option key={cat.id} value={cat.id}>
                      {cat.name}
                    </option>
                  ))}
                </select>
                <TagIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 text-future-400 w-5 h-5" />
              </div>
            </motion.div>

            {/* Product Fields */}
            <div className="grid md:grid-cols-2 gap-6">
              {inputFields.map((field, index) => (
                <motion.div
                  key={field.name}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.4 + index * 0.1 }}
                  className={field.name === 'description' ? 'md:col-span-2' : ''}
                >
                  <label className="block text-sm font-medium text-future-200 mb-2">
                    {field.label} {field.required && <span className="text-red-400">*</span>}
                  </label>
                  {field.type === 'textarea' ? (
                    <textarea
                      name={field.name}
                      value={form[field.name]}
                      onChange={e => setForm({ ...form, [field.name]: e.target.value })}
                      className="input-field bg-white/10 border-white/20 text-white placeholder-future-400 focus:border-fopcam-400 focus:ring-fopcam-400/20 min-h-[100px] resize-vertical"
                      placeholder={field.placeholder}
                      required={field.required}
                    />
                  ) : (
                    <input
                      type={field.type}
                      name={field.name}
                      value={form[field.name]}
                      onChange={e => setForm({ ...form, [field.name]: e.target.value })}
                      className="input-field bg-white/10 border-white/20 text-white placeholder-future-400 focus:border-fopcam-400 focus:ring-fopcam-400/20"
                      placeholder={field.placeholder}
                      step={field.step}
                      min={field.min}
                      required={field.required}
                    />
                  )}
                </motion.div>
              ))}
            </div>

            {/* Image Upload */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.8 }}
            >
              <label className="block text-sm font-medium text-future-200 mb-2">
                Photo du produit (optionnel)
              </label>
              <div className="relative">
                <input
                  type="file"
                  accept="image/*"
                  onChange={e => setFile(e.target.files[0])}
                  className="input-field bg-white/10 border-white/20 text-white placeholder-future-400 focus:border-fopcam-400 focus:ring-fopcam-400/20 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-medium file:bg-fopcam-400 file:text-white hover:file:bg-fopcam-500"
                />
                <PhotoIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 text-future-400 w-5 h-5" />
              </div>

              {/* Image Preview */}
              <div className="mt-4 flex gap-4">
                {currentImage && !file && (
                  <div>
                    <p className="text-future-300 text-sm mb-2">Image actuelle :</p>
                    <img
                      src={process.env.NEXT_PUBLIC_API_URL + currentImage}
                      alt="Image actuelle"
                      className="w-24 h-24 rounded-lg object-cover border-2 border-future-400"
                    />
                  </div>
                )}
                {file && (
                  <div>
                    <p className="text-future-300 text-sm mb-2">Nouvelle image :</p>
                    <img
                      src={URL.createObjectURL(file)}
                      alt="Aperçu"
                      className="w-24 h-24 rounded-lg object-cover border-2 border-fopcam-400"
                    />
                  </div>
                )}
              </div>
            </motion.div>

            {/* Submit Button */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.9 }}
              className="pt-4"
            >
              <button
                type="submit"
                disabled={loading}
                className="w-full btn-primary bg-gradient-fopcam hover:bg-gradient-fopcam disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
              >
                {loading ? (
                  <div className="flex items-center justify-center">
                    <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>
                    Modification en cours...
                  </div>
                ) : (
                  'Modifier le produit'
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
        </motion.div>
      </div>
    </div>
  )
}