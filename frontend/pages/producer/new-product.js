import { useState, useEffect } from 'react'
import { useRouter } from 'next/router'
import { motion } from 'framer-motion'
import { ArrowLeftIcon, PhotoIcon, TagIcon, BuildingStorefrontIcon } from '@heroicons/react/24/outline'
import { fetchWithAuth, getAccessToken, clearTokens } from '../../utils/tokenManager'

export default function NewProduct() {
  const [form, setForm] = useState({
    shop: '',
    category_id: '',
    category_name: '',
    title: '',
    description: '',
    price: '',
    quantity: 1
  })
  const [files, setFiles] = useState([])
  const [video, setVideo] = useState(null)
  const [msg, setMsg] = useState(null)
  const [loading, setLoading] = useState(false)
  const [categories, setCategories] = useState([])
  const [shops, setShops] = useState([])
  const router = useRouter()

  useEffect(() => {
    const token = getAccessToken()
    if (!token) {
      clearTokens()
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

    // Charger les boutiques de l'utilisateur
    const loadShop = async () => {
      try {
        const res = await fetchWithAuth(process.env.NEXT_PUBLIC_API_URL + '/api/shops/my/')
        if (res.ok) {
          const data = await res.json()
          if (data && data.id) {
            setShops([data])
            setForm(prev => ({ ...prev, shop: data.id }))
          }
        }
      } catch (err) {
        console.log('Pas de boutique', err)
      }
    }

    loadShop()
  }, [])

  const submit = async e => {
    e.preventDefault()
    setLoading(true)
    setMsg(null)

    const token = getAccessToken()
    if (!token) {
      clearTokens()
      setMsg({ type: 'error', text: 'Vous devez être connecté' })
      router.replace('/login')
      return
    }

    if (!form.shop) {
      setMsg({ type: 'error', text: 'Veuillez créer une boutique d\'abord' })
      setLoading(false)
      return
    }

    const trimmedCategoryName = form.category_name?.trim()
    if (!form.category_id && !trimmedCategoryName) {
      setMsg({ type: 'error', text: 'Veuillez sélectionner une catégorie ou en saisir une nouvelle.' })
      setLoading(false)
      return
    }

    const fd = new FormData()
    fd.append('shop_id', form.shop)
    if (form.category_id) {
      fd.append('category_id', form.category_id)
    } else {
      fd.append('category_name', trimmedCategoryName)
    }
    fd.append('title', form.title)
    fd.append('description', form.description)
    fd.append('price', form.price)
    fd.append('quantity', form.quantity)
    // append up to 10 images
    if (files && files.length > 0) {
      for (let i = 0; i < Math.min(files.length, 10); i++) {
        fd.append('images', files[i])
      }
    }
    // append video if present (single)
    if (video) {
      fd.append('video', video)
    }

    try {
      const res = await fetchWithAuth(process.env.NEXT_PUBLIC_API_URL + '/api/products/', {
        method: 'POST',
        body: fd
      })

      if (res.ok) {
        setMsg({ type: 'success', text: 'Produit créé avec succès !' })
        setForm({
          shop: form.shop,
          category_id: '',
          category_name: '',
          title: '',
          description: '',
          price: '',
          quantity: 1
        })
        setFiles([])
        setVideo(null)
        setTimeout(() => router.push('/producer/dashboard'), 2000)
      } else {
        const error = await res.json().catch(() => null)
        setMsg({
          type: 'error',
          text: error?.detail || error?.non_field_errors?.join(' ') || JSON.stringify(error) || 'Erreur lors de la création du produit'
        })
      }
    } catch (error) {
      setMsg({ type: 'error', text: error.message?.includes('Session expired') ? 'Session expirée, veuillez vous reconnecter.' : 'Erreur de connexion au serveur' })
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
              <TagIcon className="w-8 h-8 text-white" />
            </div>
            <h1 className="text-3xl font-bold text-white mb-2">Nouveau produit</h1>
            <p className="text-future-300">Ajoutez un produit à votre boutique</p>
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
            {/* Shop Selection */}
            {shops.length > 0 && (
              <motion.div
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.3 }}
              >
                <label className="block text-sm font-medium text-future-200 mb-2">
                  Boutique <span className="text-red-400">*</span>
                </label>
                <div className="relative">
                  <select
                    value={form.shop}
                    onChange={e => setForm({ ...form, shop: e.target.value })}
                    className="input-field bg-white/10 border-white/20 text-white focus:border-fopcam-400 focus:ring-fopcam-400/20"
                    required
                  >
                    <option value="">Sélectionnez une boutique</option>
                    {shops.map(shop => (
                      <option key={shop.id} value={shop.id}>
                        {shop.name}
                      </option>
                    ))}
                  </select>
                  <BuildingStorefrontIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 text-future-400 w-5 h-5" />
                </div>
                {shops.length === 0 && (
                  <p className="text-future-400 text-sm mt-2">
                    Vous devez d'abord créer une boutique.
                    <a href="/producer/create-shop" className="text-fopcam-400 hover:text-fopcam-300 ml-1">
                      Créer une boutique
                    </a>
                  </p>
                )}
              </motion.div>
            )}

            {/* Category Selection */}
            <motion.div
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.4 }}
            >
              <label className="block text-sm font-medium text-future-200 mb-2">
                Catégorie <span className="text-red-400">*</span>
              </label>
              <div className="relative">
                <select
                  value={form.category_id}
                  onChange={e => setForm({ ...form, category_id: e.target.value, category_name: '' })}
                  className="input-field bg-white/10 border-white/20 text-white focus:border-fopcam-400 focus:ring-fopcam-400/20"
                >
                  <option value="">Sélectionnez une catégorie existante</option>
                  {categories.map(cat => (
                    <option key={cat.id} value={cat.id}>
                      {cat.translated_name || cat.name}
                    </option>
                  ))}
                </select>
                <TagIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 text-future-400 w-5 h-5" />
              </div>
              <p className="text-future-400 text-sm mt-2">
                Si la catégorie souhaitée n'est pas listée, saisissez-en une nouvelle ci-dessous.
              </p>
              <input
                type="text"
                value={form.category_name}
                onChange={e => setForm({ ...form, category_name: e.target.value, category_id: '' })}
                className="input-field mt-3 bg-white/10 border-white/20 text-white placeholder-future-400 focus:border-fopcam-400 focus:ring-fopcam-400/20"
                placeholder="Ex. Alimentation fermière, Service traiteur, Artisanat local"
              />
            </motion.div>

            {/* Product Fields */}
            <div className="grid md:grid-cols-2 gap-6">
              {inputFields.map((field, index) => (
                <motion.div
                  key={field.name}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.5 + index * 0.1 }}
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
              transition={{ delay: 0.9 }}
            >
              <label className="block text-sm font-medium text-future-200 mb-2">
                Photos / Vidéo du produit (optionnel — max 10 images et 1 vidéo)
              </label>
              <div className="relative">
                <input
                  type="file"
                  accept="image/*,video/*"
                  multiple
                  onChange={e => {
                    const all = Array.from(e.target.files)
                    let imgs = []
                    let vid = null
                    for (const f of all) {
                      if (f.type && f.type.startsWith('video/')) {
                        if (!vid) vid = f
                      } else if (f.type && f.type.startsWith('image/')) {
                        imgs.push(f)
                      }
                    }
                    if (imgs.length > 10) {
                      setMsg({ type: 'error', text: 'Maximum 10 images — seules les 10 premières ont été gardées.' })
                      imgs = imgs.slice(0, 10)
                    }
                    setFiles(imgs)
                    setVideo(vid)
                  }}
                  className="input-field bg-white/10 border-white/20 text-white placeholder-future-400 focus:border-fopcam-400 focus:ring-fopcam-400/20 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-medium file:bg-fopcam-400 file:text-white hover:file:bg-fopcam-500"
                />
                <PhotoIcon className="absolute left-3 top-1/2 transform -translate-y-1/2 text-future-400 w-5 h-5" />
              </div>
              {(files && files.length > 0) || video ? (
                <>
                  {files && files.length > 0 && (
                    <>
                      <p className="text-future-400 text-sm mt-2">{files.length} / 10 images sélectionnées</p>
                      <div className="mt-2 grid grid-cols-5 gap-2">
                        {files.map((f, idx) => (
                          <img
                            key={idx}
                            src={URL.createObjectURL(f)}
                            alt={`Aperçu ${idx + 1}`}
                            className="w-24 h-24 rounded-lg object-cover border-2 border-fopcam-400"
                          />
                        ))}
                      </div>
                    </>
                  )}

                  {video && (
                    <div className="mt-4">
                      <p className="text-future-400 text-sm mb-2">Aperçu vidéo</p>
                      <video controls className="w-64 h-40 rounded-lg border-2 border-fopcam-400">
                        <source src={URL.createObjectURL(video)} type={video.type} />
                        Votre navigateur ne supporte pas la lecture vidéo.
                      </video>
                    </div>
                  )}
                </>
              ) : null}
            </motion.div>

            {/* Submit Button */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 1.0 }}
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
                    Création en cours...
                  </div>
                ) : (
                  'Créer le produit'
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
