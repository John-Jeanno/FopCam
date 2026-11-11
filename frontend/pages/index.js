import { useEffect, useState, useRef, useCallback, useMemo } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/router'
import { useTranslation } from 'next-i18next'
import { serverSideTranslations } from 'next-i18next/serverSideTranslations'
import {
  ShoppingBagIcon,
  UserIcon,
  StarIcon,
  TruckIcon,
  ChatBubbleBottomCenterIcon,
  MapPinIcon,
  ChevronDownIcon,
  HeartIcon,
  ChatBubbleLeftIcon,
  UserPlusIcon,
  PhotoIcon,
  VideoCameraIcon,
  MicrophoneIcon,
  PencilSquareIcon,
  ShareIcon,
  ArrowPathRoundedSquareIcon,
  FaceSmileIcon,
  HomeIcon,
} from '@heroicons/react/24/outline'
import { HeartIcon as HeartIconSolid } from '@heroicons/react/24/solid'
import { useRealtimeNotifications } from '../hooks/useRealtime'
import StoriesBar from '../components/StoriesBar'
import CreateStoryModal from '../components/CreateStoryModal'
import PostViewer from '../components/PostViewer'
import { fetchWithAuth } from '../utils/tokenManager'

const POSTS_PAGE_SIZE = 5

const featureItems = [
  {
    icon: TruckIcon,
    title: 'Livraison rapide',
    description: 'Recevez vos produits frais directement du vendeur en quelques heures.'
  },
  {
    icon: StarIcon,
    title: 'Qualité garantie',
    description: 'Tous les vendeurs sont vérifiés et leurs produits sont certifiés.'
  },
  {
    icon: UserIcon,
    title: 'Communauté locale',
    description: 'Soutenez les fermes de votre région et achetez en circuit court.'
  }
]

const FALLBACK_CATEGORIES = [
  { id: 'agriculture', name: 'Agriculture' },
  { id: 'alimentation', name: 'Alimentation' },
  { id: 'artisanat', name: 'Artisanat' },
  { id: 'beaute', name: 'Beauté' },
  { id: 'commerce', name: 'Commerce' },
  { id: 'sante', name: 'Santé' },
  { id: 'immobilier', name: 'Immobilier' },
  { id: 'technologie', name: 'Technologie' },
  { id: 'transport', name: 'Transport' },
  { id: 'restauration', name: 'Restauration' },
  { id: 'automobile', name: 'Automobile' },
  { id: 'cosmetique', name: 'Cosmétique' },
  { id: 'mobilier-bureautique', name: 'Mobilier & Bureautique' },
  { id: 'energie', name: 'Énergie' }
]

const BUSINESS_SECTOR_CATEGORIES = [
  { id: 'agriculture', name: 'Agriculture' },
  { id: 'alimentation', name: 'Alimentation' },
  { id: 'artisanat', name: 'Artisanat' },
  { id: 'beaute', name: 'Beauté' },
  { id: 'commerce', name: 'Commerce' },
  { id: 'sante', name: 'Santé' },
  { id: 'immobilier', name: 'Immobilier' },
  { id: 'technologie', name: 'Technologie' },
  { id: 'transport', name: 'Transport' },
  { id: 'restauration', name: 'Restauration' },
  { id: 'automobile', name: 'Automobile' },
  { id: 'cosmetique', name: 'Cosmétique' },
  { id: 'mobilier-bureautique', name: 'Mobilier & Bureautique' },
  { id: 'energie', name: 'Énergie' }
]

const FALLBACK_PRODUCTS = []

const FALLBACK_PRODUCERS = [
  {
    id: 'u1',
    user: { username: 'amandine', first_name: 'Amandine' },
    shop_name: 'Terres Bio',
    profile_image: '/default-avatar.png',
    bio: 'Productrice engagée en agriculture biologique.',
    verified: true,
    products_count: 12,
    followers_count: 340,
    rating: 4.8,
    likes_count: 245
  },
  {
    id: 'u2',
    user: { username: 'mamadou', first_name: 'Mamadou' },
    shop_name: 'Ferme du Lac',
    profile_image: '/default-avatar.png',
    bio: 'Vendeur local de fruits et légumes de saison.',
    verified: false,
    products_count: 8,
    followers_count: 215,
    rating: 4.5,
    likes_count: 187
  },
  {
    id: 'u3',
    user: { username: 'fatou', first_name: 'Fatou' },
    shop_name: 'Le Potager',
    profile_image: '/default-avatar.png',
    bio: 'Spécialiste en maraîchage durable.',
    verified: true,
    products_count: 14,
    followers_count: 492,
    rating: 4.9,
    likes_count: 356
  }
]

const FALLBACK_GROUPS = [
  { id: 'g1', name: 'Agriculture durable', description: 'Échangez autour des bonnes pratiques agricoles locales.', members_count: 69 },
  { id: 'g2', name: 'Marché bio', description: 'Trouvez et partagez vos meilleurs produits bio.', members_count: 33 },
  { id: 'g3', name: 'Vendeurs artisans', description: 'Communauté d’artisans et vendeurs de proximité.', members_count: 41 }
]

const FALLBACK_POSTS = [
  {
    id: 'post1',
    content: 'Bienvenue sur FopCam ! Découvrez des vendeurs locaux engagés.',
    group: 'g1',
    post_type: 'image',
    image: 'https://images.unsplash.com/photo-1519985176271-adb1088fa94c?auto=format&fit=crop&w=900&q=80',
    created_at: '2026-05-15T08:00:00.000Z',
    likes_count: 12,
    comments_count: 4,
    reposts_count: 1,
    author: { username: 'FopCam', profile_image: '/default-avatar.png', is_producer: false }
  },
  {
    id: 'post2',
    content: 'Nouveau produit disponible : jus de mangue pressé à froid.',
    group: 'g2',
    post_type: 'image',
    image: 'https://images.unsplash.com/photo-1506806732259-39c2d0268443?auto=format&fit=crop&w=900&q=80',
    created_at: '2026-05-14T13:30:00.000Z',
    likes_count: 8,
    comments_count: 2,
    reposts_count: 0,
    author: { username: 'Terres Bio', profile_image: '/default-avatar.png', is_producer: true }
  },
  {
    id: 'post3',
    content: 'Nos tomates cerises bio sont cueillies ce matin et prêtes à être livrées en circuit court.',
    group: 'g1',
    post_type: 'image',
    image: 'https://images.unsplash.com/photo-1567306226416-28f0efdc88ce?auto=format&fit=crop&w=900&q=80',
    created_at: '2026-05-16T10:15:00.000Z',
    likes_count: 24,
    comments_count: 6,
    reposts_count: 3,
    author: { username: 'La Ferme du Lac', profile_image: '/default-avatar.png', is_producer: true }
  },
  {
    id: 'post4',
    content: 'Week-end du marché bio : profitez de -10% sur tous les légumes de saison.',
    group: 'g2',
    post_type: 'image',
    image: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=900&q=80',
    hashtags: ['marchébio', 'légumes', 'promo'],
    created_at: '2026-05-16T14:45:00.000Z',
    likes_count: 19,
    comments_count: 5,
    reposts_count: 2,
    author: { username: 'Terroir & Co', profile_image: '/default-avatar.png', is_producer: true }
  },
  {
    id: 'post5',
    content: 'Découvrez notre nouveau panier découverte avec œufs, miel et pain maison.',
    group: 'g3',
    post_type: 'image',
    image: 'https://images.unsplash.com/photo-1515484491392-0b7b9cd8b1c2?auto=format&fit=crop&w=900&q=80',
    created_at: '2026-05-16T18:30:00.000Z',
    likes_count: 34,
    comments_count: 9,
    reposts_count: 5,
    author: { username: 'Marché Bio', profile_image: '/default-avatar.png', is_producer: true }
  }
]

const FALLBACK_STORIES = [
  {
    id: 's1',
    author: { id: 'u1', username: 'Amandine', profile_image: '/default-avatar.png' },
    story_type: 'text',
    content: 'Journée de récolte au verger. Venez voir nos mangues !',
    created_at: new Date().toISOString(),
    is_viewed: false,
    is_liked: false
  },
  {
    id: 's2',
    author: { id: 'u2', username: 'Mamadou', profile_image: '/default-avatar.png' },
    story_type: 'text',
    content: 'Notre nouvelle collection de légumes de saison est arrivée.',
    created_at: new Date().toISOString(),
    is_viewed: false,
    is_liked: false
  }
]

export default function Home({ 
  initialProducts = [], 
  initialCategories = [], 
  initialProducers = [],
  initialPosts = [],
  initialGroups = [],
  initialStories = []
}) {
  const { t } = useTranslation('common')
  const router = useRouter()
  const scrollToSection = useCallback((id) => {
    if (!id || typeof document === 'undefined') return
    const element = document.getElementById(id)
    if (element) {
      element.scrollIntoView({ behavior: 'smooth', block: 'start' })
      window.history.replaceState(null, '', `#${id}`)
    }
  }, [])
  const apiUrl = process.env.NEXT_PUBLIC_API_URL?.trim().replace(/\/$/, '') || 'http://127.0.0.1:8000'
  const buildMediaUrl = (path) => {
    if (!path) return null
    // Accept string URL, object with `url` prop, or arrays
    const resolved = typeof path === 'string' ? path : Array.isArray(path) ? path[0] : (path && path.url) ? path.url : null
    if (!resolved) return null
    if (resolved.startsWith('http')) return resolved
    return `${apiUrl}${resolved.startsWith('/') ? '' : '/'}${resolved}`
  }

  const refreshFeed = useCallback(async () => {
    setIsLoadingPosts(true)
    setPage(1)
    try {
      const response = await fetch(`${apiUrl}/api/posts/?page=1&page_size=${POSTS_PAGE_SIZE}`)
      if (!response.ok) {
        console.warn('refreshFeed: failed to fetch posts', response.status)
        return
      }
      const data = await response.json()
      const latestPosts = Array.isArray(data) ? data : data.results || []
      setPosts(latestPosts.length > 0 ? latestPosts : FALLBACK_POSTS)
      setHasMorePosts(latestPosts.length >= POSTS_PAGE_SIZE)
    } catch (error) {
      console.error('Erreur rafraîchissement du fil:', error)
    } finally {
      setIsLoadingPosts(false)
    }
  }, [apiUrl])

  const handleHomeClick = useCallback((event) => {
    if (event) {
      event.preventDefault()
    }
    refreshFeed()
    scrollToSection('feed')
  }, [refreshFeed, scrollToSection])

  const [showStoryModal, setShowStoryModal] = useState(false)
  const [stories, setStories] = useState([])
  const [allNotifications, setAllNotifications] = useState([])
  const [likedProducts, setLikedProducts] = useState(new Set())
  const [friendRequests, setFriendRequests] = useState({})
  const [loadingFriend, setLoadingFriend] = useState({})
  const [currentUser, setCurrentUser] = useState(null)
  const [posts, setPosts] = useState(initialPosts)
  const [products, setProducts] = useState(initialProducts)
  const [producers, setProducers] = useState(initialProducers)
  const [categories, setCategories] = useState(initialCategories)
  const [groups, setGroups] = useState(initialGroups)
  const [page, setPage] = useState(1)
  const [hasMorePosts, setHasMorePosts] = useState(initialPosts.length >= POSTS_PAGE_SIZE)
  const [isLoadingPosts, setIsLoadingPosts] = useState(false)
  const [likedPosts, setLikedPosts] = useState(new Set())
  const [postContent, setPostContent] = useState('')
  const [selectedUsers, setSelectedUsers] = useState(new Set())
  const [selectedCategory, setSelectedCategory] = useState('')
  const [selectedPostCategories, setSelectedPostCategories] = useState(new Set())
  const [selectedBusinessCategories, setSelectedBusinessCategories] = useState(new Set())
  const [customBusinessCategories, setCustomBusinessCategories] = useState([])
  const [customServiceCategories, setCustomServiceCategories] = useState([])
  const [customBusinessCategory, setCustomBusinessCategory] = useState('')
  const [customServiceCategory, setCustomServiceCategory] = useState('')
  // Default to no group selected so publishing to the main feed is possible
  const [selectedGroup, setSelectedGroup] = useState('')
  const [selectedMediaType, setSelectedMediaType] = useState('text')
  const [mediaFiles, setMediaFiles] = useState([])
  const [mediaPreviews, setMediaPreviews] = useState([])
  const [commentInputs, setCommentInputs] = useState({})
  const [openComments, setOpenComments] = useState(new Set())
  const [postComments, setPostComments] = useState({})
  const [loadingComments, setLoadingComments] = useState({})
  const [activeSharePostId, setActiveSharePostId] = useState(null)
  const [activeRepostPostId, setActiveRepostPostId] = useState(null)
  const [repostCommentInputs, setRepostCommentInputs] = useState({})
  const postsObserverRef = useRef(null)

  // New state for additional features
  const [showEmojiPicker, setShowEmojiPicker] = useState(false)
  const [showLocationPicker, setShowLocationPicker] = useState(false)
  const [showGifPicker, setShowGifPicker] = useState(false)
  const [showUserTagger, setShowUserTagger] = useState(false)
  const [showMoreOptions, setShowMoreOptions] = useState(false)
  const [selectedEmoji, setSelectedEmoji] = useState('')
  const [selectedLocation, setSelectedLocation] = useState('')
  const [taggedUsers, setTaggedUsers] = useState(new Set())
  const [showCreatePostModal, setShowCreatePostModal] = useState(false)
  const [selectedBgColor, setSelectedBgColor] = useState(null)
  const [selectedPrivacy, setSelectedPrivacy] = useState('public')
  const [showPrivacyMenu, setShowPrivacyMenu] = useState(false)
  const [searchScope, setSearchScope] = useState('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [searchCategoryFilter, setSearchCategoryFilter] = useState('')
  const [searchResultsActive, setSearchResultsActive] = useState(false)
  const [editingPostId, setEditingPostId] = useState(null)
  const [editPostContent, setEditPostContent] = useState('')
  const [editPostPrivacy, setEditPostPrivacy] = useState('public')
  const [editMediaFile, setEditMediaFile] = useState(null)
  const [editMediaPreview, setEditMediaPreview] = useState(null)
  const [postMenuOpen, setPostMenuOpen] = useState(null)
  const [isEditingPost, setIsEditingPost] = useState(false)
  const currentUserId = currentUser?.user?.id || currentUser?.id || null

  // Post viewer modal state
  const [viewerOpen, setViewerOpen] = useState(false)
  const [viewerMediaList, setViewerMediaList] = useState([])
  const [viewerIndex, setViewerIndex] = useState(0)
  const [carouselIndices, setCarouselIndices] = useState({})

  const buildPostMediaList = (post) => {
    const items = []
    if (post.images && Array.isArray(post.images) && post.images.length > 0) {
      items.push(...post.images
        .filter(Boolean)
        .map((src) => ({ type: 'image', src: buildMediaUrl(src), alt: post.title || 'Image du post' }))
      )
    } else if (post.image) {
      items.push({ type: 'image', src: buildMediaUrl(post.image), alt: post.title || 'Image du post' })
    }

    if (post.video) {
      items.push({ type: 'video', src: buildMediaUrl(post.video), alt: post.title || 'Vidéo du post' })
    }

    return items.filter(item => item.src)
  }

  const openViewer = (mediaList, startIndex = 0) => {
    setViewerMediaList(mediaList)
    setViewerIndex(Math.max(0, startIndex))
    setViewerOpen(true)
  }

  const closeViewer = () => {
    setViewerOpen(false)
    setViewerMediaList([])
    setViewerIndex(0)
  }

  const handleCarouselNavigation = (postId, direction) => {
    setCarouselIndices((prev) => {
      const currentIndex = Number(prev[postId] || 0)
      const postItem = posts.find((post) => post.id === postId)
      const images = postItem?.images || []
      if (!images.length) return prev

      let nextIndex = currentIndex
      if (direction === 'next') {
        nextIndex = (currentIndex + 1) % images.length
      } else if (direction === 'prev') {
        nextIndex = (currentIndex - 1 + images.length) % images.length
      }

      return { ...prev, [postId]: nextIndex }
    })
  }

  // Force page visibilité après hydratation
  useEffect(() => {
    const timer = setTimeout(() => {
      if (typeof document !== 'undefined') {
        document.body.style.display = 'block'
      }
    }, 100)
    return () => clearTimeout(timer)
  }, [])

  const { notifications: realtimeNotifications, unreadCount, clearAll, isConnected } = useRealtimeNotifications(null, null)

  const getRefreshToken = () => {
    const token = localStorage.getItem('refresh_token') || localStorage.getItem('refresh')
    if (!token || typeof token !== 'string' || token.split('.').length !== 3) {
      localStorage.removeItem('refresh_token')
      localStorage.removeItem('refresh')
      return null
    }
    return token
  }

  // Récupérer l'utilisateur courant
  const refreshAccessToken = async () => {
    const refreshToken = getRefreshToken()
    if (!refreshToken) return null

    try {
      const res = await fetch(`${apiUrl}/api/auth/token/refresh/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refresh: refreshToken })
      })

      if (!res.ok) {
        localStorage.removeItem('refresh_token')
        localStorage.removeItem('refresh')
        return null
      }

      const data = await res.json()
      if (data.access) {
        localStorage.setItem('access_token', data.access)
        localStorage.setItem('access', data.access)
      }
      return data.access || null
    } catch (err) {
      console.error('Erreur refresh token:', err)
      localStorage.removeItem('refresh_token')
      localStorage.removeItem('refresh')
      return null
    }
  }

  useEffect(() => {
    if (typeof window !== 'undefined' && window.location.hash) {
      const sectionId = window.location.hash.substring(1)
      const section = document.getElementById(sectionId)
      if (section) {
        setTimeout(() => {
          section.scrollIntoView({ behavior: 'smooth', block: 'start' })
        }, 50)
      }
    }

    if (typeof document !== 'undefined') {
      document.documentElement.style.scrollBehavior = 'smooth'
    }

    const loadCurrentUser = async () => {
      let token = localStorage.getItem('access_token')
      if (!token) return

      const fetchProfile = async () => {
        const res = await fetch(`${apiUrl}/api/auth/profile/`, {
          headers: { 'Authorization': `Bearer ${token}` }
        })
        if (res.ok) {
          return await res.json()
        }
        if (res.status === 401 || res.status === 403) {
          return null
        }
        throw new Error(`Profile fetch failed with ${res.status}`)
      }

      let profile = await fetchProfile()
      if (!profile) {
        token = await refreshAccessToken()
        if (token) {
          profile = await fetchProfile()
        } else {
          localStorage.removeItem('access_token')
          localStorage.removeItem('access')
        }
      }

      if (profile) {
        const normalizedProfile = {
          ...profile,
          id: profile.user?.id || profile.id,
          user_id: profile.user?.id || profile.id
        }
        setCurrentUser(normalizedProfile)
      }
    }

    loadCurrentUser().catch(err => {
      console.error('Erreur récupération utilisateur:', err.message || err)
    })
  }, [])



  useEffect(() => {
    setAllNotifications(realtimeNotifications)
  }, [realtimeNotifications])

  const normalizedCategories = useMemo(() => categories || [], [categories])
  const normalizedProducts = useMemo(() => products || [], [products])
  const normalizedProducers = useMemo(() => producers || [], [producers])

  const searchResults = useMemo(() => {
    const query = searchQuery.trim().toLowerCase()
    if (!searchResultsActive || !query) return []

    const matches = (value) => value?.toString().toLowerCase().includes(query)
    const results = []

    if (searchScope === 'all' || searchScope === 'categories') {
      normalizedCategories.forEach((category) => {
        const categoryLabel = translateCategoryName(category.name || category.slug || category.id)
        if (matches(categoryLabel) || matches(category.slug) || matches(category.id)) {
          results.push({ type: 'category', item: category })
        }
      })
    }

    if (searchScope === 'all' || searchScope === 'products') {
      normalizedProducts.forEach((product) => {
        const productCategoryName = translateCategoryName(product.category?.name || product.category || '')
        if (
          matches(product.title) ||
          matches(product.description) ||
          matches(product.shop?.name) ||
          matches(productCategoryName)
        ) {
          if (
            !searchCategoryFilter ||
            searchCategoryFilter === product.category?.id ||
            searchCategoryFilter === product.category ||
            searchCategoryFilter === productCategoryName
          ) {
            results.push({ type: 'product', item: product })
          }
        }
      })
    }

    if (searchScope === 'all' || searchScope === 'producers') {
      normalizedProducers.forEach((producer) => {
        if (
          matches(producer.shop_name) ||
          matches(producer.bio) ||
          matches(producer.user?.username) ||
          matches(producer.user?.first_name)
        ) {
          results.push({ type: 'producer', item: producer })
        }
      })
    }

    return results.slice(0, 20)
  }, [searchQuery, searchScope, searchCategoryFilter, normalizedCategories, normalizedProducts, normalizedProducers, searchResultsActive])

  const handleSearchSubmit = useCallback((event) => {
    event.preventDefault()
    setSearchResultsActive(true)
  }, [])

  const handleClearSearch = useCallback(() => {
    setSearchQuery('')
    setSearchScope('all')
    setSearchCategoryFilter('')
    setSearchResultsActive(false)
  }, [])

  useEffect(() => {
    const loadFallbackData = async () => {
      console.log('Loading fallback data, initialProducts.length:', initialProducts.length)
      try {
        if (initialProducts.length === 0) {
          console.log('Fetching products...')
          const res = await fetch(`${apiUrl}/api/products/?page_size=12`)
          console.log('Products response status:', res.status)
          if (res.ok) {
            const data = await res.json()
            const productsData = Array.isArray(data) ? data : data.results || []
            console.log('Products loaded:', productsData.length)
            if (productsData.length > 0) {
              setProducts(productsData)
            } else {
              setProducts(FALLBACK_PRODUCTS)
            }
          } else {
            console.error('Failed to fetch products:', res.status)
            setProducts(FALLBACK_PRODUCTS)
          }
        }
      } catch (error) {
        console.warn('Impossible de charger les produits en fallback:', error)
        if (initialProducts.length === 0) {
          setProducts(FALLBACK_PRODUCTS)
        }
      }

      try {
        if (initialProducers.length === 0) {
          console.log('Fetching producers...')
          const res = await fetch(`${apiUrl}/api/profiles/?role=producer`)
          console.log('Producers response status:', res.status)
          if (res.ok) {
            const data = await res.json()
            const producersData = Array.isArray(data) ? data : data.results || []
            console.log('Producers loaded:', producersData.length)
            if (producersData.length > 0) {
              setProducers(producersData)
            } else {
              setProducers(FALLBACK_PRODUCERS)
            }
          } else {
            console.error('Failed to fetch producers:', res.status)
            setProducers(FALLBACK_PRODUCERS)
          }
        }
      } catch (error) {
        console.warn('Impossible de charger les vendeurs en fallback:', error)
        if (initialProducers.length === 0) {
          setProducers(FALLBACK_PRODUCERS)
        }
      }

      try {
        if (initialCategories.length === 0) {
          console.log('Fetching categories...')
          const res = await fetch(`${apiUrl}/api/categories/`)
          console.log('Categories response status:', res.status)
          if (res.ok) {
            const data = await res.json()
            const categoriesData = Array.isArray(data) ? data : data.results || []
            // Trier par nom traduit (si disponible) ou par name pour l'affichage alphabétique
            categoriesData.sort((a, b) => (a.translated_name || a.name).localeCompare(b.translated_name || b.name, 'fr'))
            console.log('Categories loaded:', categoriesData.length)
            if (categoriesData.length > 0) {
              setCategories(categoriesData)
            } else {
              setCategories(FALLBACK_CATEGORIES)
            }
          } else {
            console.error('Failed to fetch categories:', res.status)
            setCategories(FALLBACK_CATEGORIES)
          }
        }
      } catch (error) {
        console.warn('Impossible de charger les catégories en fallback:', error)
        if (initialCategories.length === 0) {
          setCategories(FALLBACK_CATEGORIES)
        }
      }

      try {
        if (initialGroups.length === 0) {
          console.log('Fetching groups...')
          const res = await fetch(`${apiUrl}/api/groups/?page_size=50`)
          console.log('Groups response status:', res.status)
          if (res.ok) {
            const data = await res.json()
            const groupsData = Array.isArray(data) ? data : data.results || []
            console.log('Groups loaded:', groupsData.length)
            if (groupsData.length > 0) {
              setGroups(groupsData.slice(0, 10))
            } else {
              setGroups(FALLBACK_GROUPS)
            }
          } else {
            console.error('Failed to fetch groups:', res.status)
            setGroups(FALLBACK_GROUPS)
          }
        }
      } catch (error) {
        console.warn('Impossible de charger les groupes en fallback:', error)
        if (initialGroups.length === 0) {
          setGroups(FALLBACK_GROUPS)
        }
      }

      try {
        if (initialPosts.length === 0) {
          console.log('Fetching posts...')
          const res = await fetch(`${apiUrl}/api/posts/?page=1&page_size=${POSTS_PAGE_SIZE}`)
          console.log('Posts response status:', res.status)
          if (res.ok) {
            const data = await res.json()
            const posts = Array.isArray(data) ? data : data.results || []
            console.log('Posts loaded:', posts.length)
            if (posts.length > 0) {
              setPosts(posts)
              setHasMorePosts(posts.length >= POSTS_PAGE_SIZE)
            } else {
              setPosts(FALLBACK_POSTS)
              setHasMorePosts(FALLBACK_POSTS.length >= POSTS_PAGE_SIZE)
            }
          } else {
            console.error('Failed to fetch posts:', res.status)
            setPosts(FALLBACK_POSTS)
            setHasMorePosts(FALLBACK_POSTS.length >= POSTS_PAGE_SIZE)
          }
        }
      } catch (error) {
        console.warn('Impossible de charger les posts en fallback:', error)
        if (initialPosts.length === 0) {
          setPosts(FALLBACK_POSTS)
          setHasMorePosts(FALLBACK_POSTS.length >= POSTS_PAGE_SIZE)
        }
      }

      try {
        if (initialStories.length === 0) {
          console.log('Fetching stories...')
          const res = await fetch(`${apiUrl}/api/stories/`)
          console.log('Stories response status:', res.status)
          if (res.ok) {
            const data = await res.json()
            const storiesData = Array.isArray(data) ? data : data.results || []
            console.log('Stories loaded:', storiesData.length)
            if (storiesData.length > 0) {
              setStories(storiesData)
            } else {
              setStories(FALLBACK_STORIES)
            }
          } else {
            console.error('Failed to fetch stories:', res.status)
            setStories(FALLBACK_STORIES)
          }
        }
      } catch (error) {
        console.warn('Impossible de charger les stories en fallback:', error)
        if (initialStories.length === 0) {
          setStories(FALLBACK_STORIES)
        }
      }
    }

    loadFallbackData()
  }, [apiUrl, initialProducts.length, initialProducers.length, initialCategories.length, initialGroups.length, initialPosts.length, initialStories.length])

  // Ne pas sélectionner automatiquement un groupe — l'utilisateur choisit explicitement.

  // Charger les stories depuis initialStories
  useEffect(() => {
    if (initialStories && initialStories.length > 0) {
      setStories(initialStories)
    } else {
      // Fallback: générer les stories des vendeurs si pas de stories depuis l'API
      const sampleStories = producers.map((producer, index) => ({
        id: producer.id || index,
        author: {
          id: producer.user?.id || index,
          username: producer.user?.username || producer.shop_name || `Vendeur ${index + 1}`,
          profile_image: producer.profile_image || '/default-avatar.png'
        },
        story_type: 'text',
        content: `${producer.user?.first_name || producer.user?.username || 'Vendeur'} présente ses meilleures offres.`,
        created_at: new Date().toISOString(),
        views_count: 12 + index * 3,
        is_viewed: false,
        is_liked: false
      }))
      setStories(sampleStories)
    }
  }, [initialStories, producers])

  useEffect(() => {
    const loadStoriesFromApi = async () => {
      const token = getAuthToken()
      if (!token) return

      try {
        const response = await fetch(`${apiUrl}/api/stories/`, {
          headers: { Authorization: `Bearer ${token}` }
        })

        if (!response.ok) {
          console.warn('Impossible de charger les stories depuis l’API :', response.status)
          return
        }

        const data = await response.json()
        setStories(Array.isArray(data) ? data : data.results || [])
      } catch (error) {
        console.error('Erreur chargement stories:', error)
      }
    }

    loadStoriesFromApi()
  }, [currentUser])

  // Trier les produits par popularité
  const featuredProducts = [...products]
    .sort((a, b) => (b.views_count || 0) - (a.views_count || 0))
    .slice(0, 6)

  const latestProducts = products.slice(0, 6)

  console.log('Current state - products:', products.length, 'producers:', producers.length, 'posts:', posts.length, 'featuredProducts:', featuredProducts.length, 'latestProducts:', latestProducts.length)

  const stats = [
    { label: 'Produits', value: products.length, icon: ShoppingBagIcon },
    { label: 'Catégories', value: categories.length, icon: StarIcon },
    { label: 'Vendeurs', value: producers.length, icon: UserIcon }
  ]

  const handleStoryCreate = async (formData) => {
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/stories/`, {
        method: 'POST',
        body: formData,
        credentials: 'include'
      })

      if (!response.ok) {
        let message = `Erreur ${response.status}`
        try {
          const errorData = await response.json()
          message = errorData.detail || errorData.message || JSON.stringify(errorData)
        } catch (e) {
          const text = await response.text().catch(() => null)
          if (text) message = text
        }
        console.error('Erreur création story:', message)
        alert(`Erreur lors de la création de la story : ${message}`)
        return
      }

      const newStory = await response.json()
      // Ajouter la nouvelle story à la liste
      setStories(prev => [newStory, ...prev])
      console.log('Story créée avec succès:', newStory)
    } catch (error) {
      console.error('Erreur lors de la création de la story:', error)
      alert('Erreur lors de la création de la story. Veuillez réessayer.')
    }
  }

  // Gérer l'ajout au panier
  const handleAddToCart = (product) => {
    if (!currentUser) {
      router.push(`/login?next=${encodeURIComponent(router.asPath)}`)
      return
    }

    const cart = JSON.parse(localStorage.getItem('cart') || '[]')
    cart.push({
      product_id: product.id,
      title: product.title,
      price: product.price,
      qty: 1,
      shop_id: product.shop?.id,
      shop_name: product.shop?.name
    })
    localStorage.setItem('cart', JSON.stringify(cart))
    alert('Produit ajouté au panier')
  }

  // Gérer le like de produit
  const handleLikeProduct = (productId) => {
    setLikedProducts(prev => {
      const newSet = new Set(prev)
      if (newSet.has(productId)) {
        newSet.delete(productId)
      } else {
        newSet.add(productId)
      }
      return newSet
    })
  }

  const getAuthToken = () => localStorage.getItem('access_token') || localStorage.getItem('access')

  const handleLogout = () => {
    localStorage.removeItem('access_token')
    localStorage.removeItem('access')
    localStorage.removeItem('refresh_token')
    localStorage.removeItem('refresh')
    setCurrentUser(null)
    router.push('/login')
  }

  const handleRequireLogin = (actionLabel) => {
    if (!currentUser) {
      router.push('/login')
      return false
    }
    return true
  }

  // Modifier un post
  const handleEditPost = (post) => {
    setEditingPostId(post.id)
    setEditPostContent(post.content)
    setEditPostPrivacy(post.privacy || 'public')
    setEditMediaFile(null)
    setEditMediaPreview(null)
    setIsEditingPost(true)
    setPostMenuOpen(null)
  }

  const handleEditMediaFileChange = (event) => {
    const file = event.target.files?.[0] || null
    setEditMediaFile(file)
    if (file) {
      setEditMediaPreview(URL.createObjectURL(file))
    } else {
      setEditMediaPreview(null)
    }
  }

  useEffect(() => {
    return () => {
      if (editMediaPreview && editMediaPreview.startsWith('blob:')) {
        URL.revokeObjectURL(editMediaPreview)
      }
    }
  }, [editMediaPreview])

  // Sauvegarder la modification du post
  const handleSaveEditPost = async () => {
    if (!editingPostId) return

    try {
      const token = getAuthToken()
      if (!token) {
        alert('Vous devez être connecté pour modifier.')
        return
      }

      const postToEdit = posts.find((post) => post.id === editingPostId)
      const endpoint = postToEdit?.group
        ? `${apiUrl}/api/group-posts/${editingPostId}/`
        : `${apiUrl}/api/posts/${editingPostId}/`

      const formData = new FormData()
      formData.append('content', editPostContent)
      formData.append('privacy', editPostPrivacy)

      if (editMediaFile) {
        if (editMediaFile.type.startsWith('image/')) {
          formData.append('image', editMediaFile)
        } else if (editMediaFile.type.startsWith('video/')) {
          formData.append('video', editMediaFile)
        }
      }

      const response = await fetch(
        endpoint,
        {
          method: 'PATCH',
          headers: {
            Authorization: `Bearer ${token}`
          },
          body: formData
        }
      )

      if (!response.ok) {
        const errorData = await response.json()
        console.error('Erreur modification:', errorData)
        alert('Impossible de modifier le post.')
        return
      }

      const updatedPost = await response.json()
      setPosts(prev => prev.map(post => post.id === editingPostId ? updatedPost : post))

      // Réinitialiser
      setEditingPostId(null)
      setEditPostContent('')
      setEditPostPrivacy('public')
      setEditMediaFile(null)
      setIsEditingPost(false)
      alert('Post modifié avec succès !')
    } catch (error) {
      console.error('Erreur modification post:', error)
      alert('Une erreur est survenue lors de la modification.')
    }
  }

  // Supprimer un post
  const handleDeletePost = async (postId) => {
    if (!confirm('Êtes-vous sûr de vouloir supprimer ce post ?')) return

    try {
      const token = getAuthToken()
      if (!token) {
        alert('Vous devez être connecté pour supprimer.')
        return
      }

      const response = await fetch(
        `${apiUrl}/api/group-posts/${postId}/`,
        {
          method: 'DELETE',
          headers: {
            Authorization: `Bearer ${token}`
          }
        }
      )

      if (!response.ok) {
        alert('Impossible de supprimer le post.')
        return
      }

      setPosts(prev => prev.filter(post => post.id !== postId))
      setPostMenuOpen(null)
      alert('Post supprimé avec succès !')
    } catch (error) {
      console.error('Erreur suppression post:', error)
      alert('Une erreur est survenue lors de la suppression.')
    }
  }


  const cleanRepostContent = (content = '') => {
    return content.replace(/^(?:(?:Republier|Repartagé)\s*:\s*)+/gi, '').trim()
  }

  const fetchCommentsForPost = async (postId) => {
    const token = getAuthToken()
    if (!token) return

    setLoadingComments(prev => ({ ...prev, [postId]: true }))
    try {
      const res = await fetch(`${apiUrl}/api/group-post-comments/?post=${postId}`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      if (!res.ok) return
      const data = await res.json()
      setPostComments(prev => ({ ...prev, [postId]: data }))
    } catch (err) {
      console.error('Erreur chargement commentaires:', err)
    } finally {
      setLoadingComments(prev => ({ ...prev, [postId]: false }))
    }
  }

  const toggleComments = async (postId) => {
    let willOpen = false
    setOpenComments(prev => {
      const newSet = new Set(prev)
      if (newSet.has(postId)) {
        newSet.delete(postId)
      } else {
        newSet.add(postId)
        willOpen = true
      }
      return newSet
    })

    if (willOpen) {
      await fetchCommentsForPost(postId)
    }
  }

  const submitComment = async (postId) => {
    if (!handleRequireLogin('commenter')) return

    const content = (commentInputs[postId] || '').trim()
    if (!content) {
      alert('Veuillez écrire un commentaire avant de l’envoyer.')
      return
    }

    const token = getAuthToken()
    if (!token) {
      alert('Session expirée. Veuillez vous reconnecter.')
      return
    }

    // If the postId is not a numeric id (e.g. fallback/demo posts like 'post1'),
    // avoid calling the API (which expects an integer PK) and simulate a local comment
    if (typeof postId !== 'number' && !/^\d+$/.test(String(postId))) {
      const fakeComment = {
        id: `local-${Date.now()}`,
        post: postId,
        author: { username: currentUser?.username || 'Vous', first_name: currentUser?.first_name },
        content,
        created_at: new Date().toISOString(),
        is_active: true
      }
      setPostComments(prev => ({
        ...prev,
        [postId]: [fakeComment, ...(prev[postId] || [])]
      }))
      setCommentInputs(prev => ({ ...prev, [postId]: '' }))
      setPosts(prevPosts => prevPosts.map(post => post.id === postId
        ? { ...post, comments_count: Number(post.comments_count ?? 0) + 1 }
        : post
      ))
      alert('Commentaire (mode démo) ajouté localement.')
      return
    }

    try {
      const res = await fetch(`${apiUrl}/api/group-post-comments/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`
        },
        body: JSON.stringify({ post: postId, content })
      })
      if (!res.ok) {
        const err = await res.json().catch(() => null)
        const message = err?.detail || err?.message || `Erreur ${res.status}`
        alert(`Impossible d’envoyer le commentaire : ${message}`)
        console.error('Erreur création commentaire:', err)
        return
      }
      const data = await res.json()
      setPostComments(prev => ({
        ...prev,
        [postId]: [data, ...(prev[postId] || [])]
      }))
      setCommentInputs(prev => ({ ...prev, [postId]: '' }))
      setPosts(prevPosts => prevPosts.map(post => post.id === postId
        ? { ...post, comments_count: Number(post.comments_count ?? 0) + 1 }
        : post
      ))
      alert('Commentaire envoyé !')
    } catch (err) {
      console.error('Erreur création commentaire:', err)
      alert('Impossible d’envoyer le commentaire. Vérifiez votre connexion.')
    }
  }

  const openShareWindow = (url) => {
    window.open(url, '_blank', 'noopener,noreferrer')
  }

  const shareToNetwork = (post, network) => {
    const postUrl = typeof window !== 'undefined'
      ? `${window.location.origin}${router.asPath.split('#')[0]}`
      : ''
    const text = `${post.content || 'Découvrez ce post'}\n${postUrl}`
    let url = ''

    switch (network) {
      case 'whatsapp':
        url = `https://wa.me/?text=${encodeURIComponent(text)}`
        break
      case 'linkedin':
        url = `https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(postUrl)}`
        break
      case 'facebook':
        url = `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(postUrl)}`
        break
      case 'instagram':
        url = `https://www.instagram.com/`
        break
      default:
        return
    }

    openShareWindow(url)
    setActiveSharePostId(null)
    setPosts(prevPosts => prevPosts.map(item => item.id === post.id
      ? { ...item, shares_count: Number(item.shares_count ?? item.share_count ?? 0) + 1 }
      : item
    ))
  }

  const handleSharePost = async (postId) => {
    if (!handleRequireLogin('partager')) return
    const post = posts.find(item => item.id === postId)
    if (!post) return

    if (navigator.share) {
      const postUrl = typeof window !== 'undefined'
        ? `${window.location.origin}${router.asPath.split('#')[0]}`
        : ''
      try {
        await navigator.share({
          title: 'FopCam',
          text: post.content || 'Découvrez ce post',
          url: postUrl
        })
        setPosts(prevPosts => prevPosts.map(item => item.id === post.id
          ? { ...item, shares_count: Number(item.shares_count ?? item.share_count ?? 0) + 1 }
          : item
        ))
        return
      } catch (err) {
        console.error('Partage natif annulé ou impossible:', err)
      }
    }

    setActiveSharePostId(postId)
  }

  const handleLikePost = async (postId) => {
    if (!handleRequireLogin('aimer')) return

    setLikedPosts(prev => {
      const newSet = new Set(prev)
      const isAlreadyLiked = newSet.has(postId)

      setPosts(prevPosts =>
        prevPosts.map(post => {
          if (post.id !== postId) return post
          const currentLikes = Number(post.likes_count ?? 0)
          return {
            ...post,
            likes_count: Math.max(0, currentLikes + (isAlreadyLiked ? -1 : 1))
          }
        })
      )

      if (isAlreadyLiked) {
        newSet.delete(postId)
      } else {
        newSet.add(postId)
      }
      return newSet
    })
  }

  const handleFeedAction = (postId, action) => {
    if (action === 'commenter') {
      if (!handleRequireLogin('commenter')) return
      toggleComments(postId)
      return
    }
    if (action === 'partager') {
      handleSharePost(postId)
      return
    }
    if (action === 'republier') {
      toggleRepostBox(postId)
      return
    }
    if (!handleRequireLogin(action)) return
    console.log(`Action ${action} disponible pour les utilisateurs connectés`)
  }

  const toggleRepostBox = (postId) => {
    if (!handleRequireLogin('republier')) return
    setActiveRepostPostId(prev => (prev === postId ? null : postId))
  }

  const handleRepost = async (postId) => {
    if (!handleRequireLogin('republier')) return

    const post = posts.find(item => item.id === postId)
    if (!post) {
      alert('Publication introuvable.')
      return
    }

    const token = getAuthToken()
    if (!token) {
      alert('Session expirée. Veuillez vous reconnecter.')
      return
    }

    const comment = (repostCommentInputs[postId] || '').trim()
    const baseContent = cleanRepostContent(post.content || '')
    let repostContent = baseContent ? `Republier : ${baseContent}` : 'Republier'
    if (!baseContent && comment) {
      repostContent = comment
    } else if (comment) {
      repostContent = `${repostContent}\n\n${comment}`
    }

    const formData = new FormData()
    formData.append('group', post.group)
    formData.append('content', repostContent)
    formData.append('post_type', post.post_type || 'text')
    formData.append('repost_of', postId)

    try {
      const res = await fetch(`${apiUrl}/api/group-posts/`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`
        },
        body: formData
      })
      if (!res.ok) {
        const err = await res.json().catch(() => null)
        const message = err?.detail || err?.message || `Erreur ${res.status}`
        alert(`Impossible de republier : ${message}`)
        console.error('Erreur republication:', err)
        return
      }
      const data = await res.json()
      setPosts(prev => [data, ...prev])
      setPosts(prevPosts => prevPosts.map(item => item.id === postId
        ? { ...item, reposts_count: Number(item.reposts_count ?? 0) + 1 }
        : item
      ))
      setActiveRepostPostId(null)
      setRepostCommentInputs(prev => ({ ...prev, [postId]: '' }))
      alert('Publication republiée !')
    } catch (err) {
      console.error('Erreur republication:', err)
      alert('Impossible de republier pour le moment. Vérifiez votre connexion.')
    }
  }

  const taggableUsers = producers.slice(0, 6)
  const categoryTranslationMap = {
    accounting: 'Comptabilité',
    'agricultural equipment': 'Équipement agricole',
    agriculture: 'Agriculture',
    airlines: 'Compagnies aériennes',
    alimentation: 'Alimentation',
    announcements: 'Annonces',
    aquaculture: 'Aquaculture',
    'artificial intelligence': 'Intelligence artificielle',
    artisanat: 'Artisanat',
    'arts and culture': 'Arts et culture',
    automotive: 'Automobile',
    'automotive services': 'Services automobiles',
    banking: 'Banque',
    beauté: 'Beauté',
    'cosmetics': 'Cosmétique',
    'poultry farming': 'Agriculture',
    'dairy farming': 'Agriculture',
    'crop cultivation': 'Culture de plantes',
    livestock: 'Agriculture',
    'seeds and fertilizers': 'Graines et engrais',
    'equipment agricultural': 'Équipement agricole',
    'beauty services': 'Services de beauté',
    books: 'Livres',
    catering: 'Restauration',
    chemicals: 'Produits chimiques',
    construction: 'Construction',
    consulting: 'Conseil',
    cybersecurity: 'Cybersécurité',
    'data science': 'Science des données',
    'dental care': 'Soins dentaires',
    education: 'Éducation',
    'educational materials': 'Matériel pédagogique',
    electronics: 'Électronique',
    'environmental services': 'Services environnementaux',
    'event planning': 'Organisation d’événements',
    finance: 'Finance',
    fitness: 'Fitness',
    'government services': 'Services publics',
    'health information': 'Information santé',
    hospitals: 'Hôpitaux',
    clinics: 'Cliniques',
    pharmaceuticals: 'Produits pharmaceutiques',
    'medical equipment': 'Matériel médical',
    hotels: 'Hôtellerie',
    restaurants: 'Restaurants',
    tourism: 'Tourisme',
    transportation: 'Transport',
    logistics: 'Logistique',
    retail: 'Commerce de détail',
    ecommerce: 'E-commerce',
    fashion: 'Mode',
    electronics: 'Électronique',
    'home goods': 'Articles ménagers',
    manufacturing: 'Manufacture',
    automotive: 'Automobile',
    textiles: 'Textile',
    chemicals: 'Produits chimiques',
    machinery: 'Machinerie',
    'food processing': 'Agroalimentaire',
    hospitality: 'Hôtellerie',
    'real estate': 'Immobilier',
    'real estate sales': 'Vente immobilière',
    'property management': 'Gestion immobilière',
    'public administration': 'Administration publique',
    'law enforcement': 'Forces de l’ordre',
    'health information': 'Information santé',
    'social services': 'Services sociaux',
    'government information': 'Information gouvernementale',
    'community events': 'Événements communautaires',
    announcements: 'Annonces',
    'lost and found': 'Objets trouvés',
    volunteering: 'Bénévolat',
    'non-profit': 'Associations',
    charity: 'Charité',
    'religious services': 'Services religieux',
    'arts and culture': 'Arts et culture',
    'science and research': 'Science et recherche',
    miscellaneous: 'Divers',
    'software development': 'Développement logiciel',
    hardware: 'Matériel',
    'cloud computing': 'Cloud',
    'mobile apps': 'Applications mobiles',
    'web development': 'Développement web',
    'cybersecurity': 'Cybersécurité',
    'data science': 'Science des données',
    'machine learning': 'Apprentissage automatique',
    'artificial intelligence': 'Intelligence artificielle'
  }
  const defaultCategoryOptions = [
    'Agriculture',
    'Alimentation',
    'Automobile',
    'Cosmétique',
    'Mobilier & Bureautique',
    'Artisanat',
    'Commerce',
    'Industrie',
    'Technologie',
    'Mode',
    'Beauté',
    'Santé',
    'Éducation',
    'Voyage',
    'Immobilier',
    'Finance',
    'Restauration',
    'Énergie',
    'Transport',
    'Culture',
    'Services',
    'Logistique'
  ]
  const translateCategoryName = (name) => {
    if (!name) return ''
    const lower = String(name).toLowerCase()
    return categoryTranslationMap[lower] || categoryTranslationMap[lower.replace(/\s+/g, ' ')] || name
  }
  const categoryOptions = Array.from(new Set([
    ...categories.map((category) => category.name || category.slug),
    ...defaultCategoryOptions
  ])).map((name) => ({ value: name, label: translateCategoryName(name) }))
    .sort((a, b) => a.label.localeCompare(b.label, 'fr', { sensitivity: 'base' }))

  const serviceCategoryOptions = (categories || [])
    .filter((category) => category.category_type && category.category_type !== 'product')
    .map((category) => ({
      value: category.slug || category.name,
      label: translateCategoryName(category.name || category.slug)
    }))

  const defaultServiceCategories = [
    { value: 'offres-demploi', label: 'Offres d’emploi' },
    { value: 'annonces', label: 'Annonces' },
    { value: 'recrutement', label: 'Recrutement' },
    { value: 'avis', label: 'Avis' },
    { value: 'services-professionnels', label: 'Services professionnels' }
  ]

  const availableServiceCategories = serviceCategoryOptions.length > 0 ? serviceCategoryOptions : defaultServiceCategories

  const businessCategoryOptions = (categories || [])
    .filter((category) => (category.category_type || 'product') === 'product')
    .map((category) => ({
      value: category.slug || category.name,
      label: translateCategoryName(category.name || category.slug)
    }))

  const defaultBusinessCategories = BUSINESS_SECTOR_CATEGORIES.map((category) => ({
    value: category.id,
    label: category.name
  }))

  const availableBusinessCategories = businessCategoryOptions.length > 0 ? businessCategoryOptions : defaultBusinessCategories

  const sectorOptions = [
    'Agriculture',
    'Alimentation',
    'Artisanat',
    'Commerce',
    'Services',
    'Technologie',
    'Transport',
    'Hôtellerie',
    'BTP',
    'Finance',
    'Immobilier',
    'Culture',
    'Mode',
    'Beauté',
    'Santé',
    'Éducation',
    'Énergie',
    'Environnement',
    'Logistique'
  ]

  const toggleSelectedUser = (userId) => {
    setSelectedUsers((prev) => {
      const next = new Set(prev)
      if (next.has(userId)) {
        next.delete(userId)
      } else {
        next.add(userId)
      }
      return next
    })
  }

  const handleMediaFileChange = (event) => {
    const files = Array.from(event.target.files || [])
    setMediaFiles(files)
    const previews = files.map(file => URL.createObjectURL(file))
    setMediaPreviews(previews)
  }

  const removeMediaFile = (index) => {
    setMediaFiles(prev => prev.filter((_, i) => i !== index))
    setMediaPreviews(prev => {
      const newPreviews = prev.filter((_, i) => i !== index)
      if (prev[index] && prev[index].startsWith('blob:')) {
        URL.revokeObjectURL(prev[index])
      }
      return newPreviews
    })
  }

  useEffect(() => {
    return () => {
      mediaPreviews.forEach(preview => {
        if (preview && preview.startsWith('blob:')) URL.revokeObjectURL(preview)
      })
    }
  }, [mediaPreviews])

  useEffect(() => {
    if (selectedMediaType === 'text') {
      setMediaFiles([])
      setMediaPreviews([])
    }
  }, [selectedMediaType])

  // New handlers for additional features
  const handleEmojiSelect = (emoji) => {
    setSelectedEmoji(emoji)
    setPostContent(prev => prev + emoji)
    setShowEmojiPicker(false)
  }

  const handleLocationSelect = (location) => {
    setSelectedLocation(location)
    setPostContent(prev => prev + ` 📍 ${location}`)
    setShowLocationPicker(false)
  }

  const handleGifSelect = (gifUrl) => {
    setSelectedMediaType('gif')
    setMediaFiles([{ url: gifUrl, type: 'gif' }])
    setMediaPreviews([gifUrl])
    setShowGifPicker(false)
  }

  const handleUserTag = (userId) => {
    setTaggedUsers(prev => {
      const newSet = new Set(prev)
      if (newSet.has(userId)) {
        newSet.delete(userId)
      } else {
        newSet.add(userId)
      }
      return newSet
    })
  }

  const handleMoreOptions = (option) => {
    // Handle additional options like scheduling, privacy settings, etc.
    alert(`Option "${option}" sélectionnée`)
    setShowMoreOptions(false)
  }

  const handleTogglePostCategory = (categoryValue) => {
    setSelectedPostCategories((prev) => {
      const next = new Set(prev)
      if (next.has(categoryValue)) {
        next.delete(categoryValue)
      } else {
        next.add(categoryValue)
      }
      return next
    })
  }

  const handleToggleBusinessCategory = (categoryValue) => {
    setSelectedBusinessCategories((prev) => {
      const next = new Set(prev)
      if (next.has(categoryValue)) {
        next.delete(categoryValue)
      } else {
        next.add(categoryValue)
      }
      return next
    })
  }

  const addCustomBusinessCategory = () => {
    const normalized = customBusinessCategory?.trim()
    if (!normalized) return
    if (customBusinessCategories.includes(normalized) || selectedBusinessCategories.has(normalized)) {
      setCustomBusinessCategory('')
      return
    }
    setCustomBusinessCategories(prev => [...prev, normalized])
    setCustomBusinessCategory('')
  }

  const addCustomServiceCategory = () => {
    const normalized = customServiceCategory?.trim()
    if (!normalized) return
    if (customServiceCategories.includes(normalized) || selectedPostCategories.has(normalized)) {
      setCustomServiceCategory('')
      return
    }
    setCustomServiceCategories(prev => [...prev, normalized])
    setCustomServiceCategory('')
  }

  const removeCustomBusinessCategory = (category) => {
    setCustomBusinessCategories(prev => prev.filter((item) => item !== category))
  }

  const removeCustomServiceCategory = (category) => {
    setCustomServiceCategories(prev => prev.filter((item) => item !== category))
  }

  const handleCreatePost = async () => {
    if (!handleRequireLogin('publier')) return

    const group = selectedGroup || ''

    if (selectedMediaType === 'text' && !postContent.trim() && !selectedBgColor) {
      alert('Veuillez écrire un message ou choisir une couleur de fond avant de publier.')
      return
    }

    if (selectedMediaType !== 'text' && mediaFiles.length === 0) {
      alert('Veuillez sélectionner au moins un fichier pour votre publication.')
      return
    }

    const formData = new FormData()
    const backendPostType = selectedMediaType === 'photo' ? 'image' : selectedMediaType === 'gif' ? 'image' : selectedMediaType

    // If a group is selected, publish to the group endpoint; otherwise publish to the main feed
    if (group) formData.append('group', group)
    formData.append('content', postContent)
    formData.append('post_type', backendPostType)
    formData.append('privacy', selectedPrivacy)

    // Add tagged users
    if (taggedUsers.size > 0) {
      Array.from(taggedUsers).forEach(userId => {
        formData.append('tagged_users', userId)
      })
    }

    if (selectedMediaType === 'gif' && mediaFiles.length > 0 && mediaFiles[0].url) {
      formData.append('images', JSON.stringify(mediaFiles.map(f => f.url)))
    } else if (mediaFiles.length > 0) {
      const imageFiles = []
      mediaFiles.forEach(file => {
        if (file.type && file.type.startsWith('video/')) {
          if (!formData.has('video')) formData.append('video', file)
        } else {
          imageFiles.push(file)
        }
      })
      if (imageFiles.length > 0) {
        formData.append('image', imageFiles[0])
        if (imageFiles.length > 1) {
          for (let i = 1; i < imageFiles.length; i++) {
            formData.append(`image_${i}`, imageFiles[i])
          }
        }
      }
    }

    const selectedHashtags = Array.from(new Set([
      ...Array.from(selectedPostCategories),
      ...Array.from(selectedBusinessCategories),
      ...customServiceCategories,
      ...customBusinessCategories
    ]))

    if (selectedHashtags.length > 0) {
      formData.append('hashtags', JSON.stringify(selectedHashtags))
    }

    try {
      const endpoint = group ? `${apiUrl}/api/group-posts/` : `${apiUrl}/api/posts/`
      const response = await fetchWithAuth(endpoint, {
        method: 'POST',
        body: formData
      })
      const data = await response.json()
      if (!response.ok) {
        console.error('Erreur création publication:', response.status, data)
        const errorMessage = data?.detail || data?.message || data?.error || (typeof data === 'string' ? data : JSON.stringify(data))
        alert(`Impossible de publier : ${errorMessage}`)
        return
      }

      // Debug: log server response and new posts head
      console.log('POST /api/group-posts/ response:', data)
      setPosts(prev => [data, ...prev])
      console.log('Posts after insert:', (posts || []).length + 1)
      // Reset all form state
      setPostContent('')
      setSelectedUsers(new Set())
      setSelectedCategory('')
      setSelectedPostCategories(new Set())
      setSelectedBusinessCategories(new Set())
      setSelectedMediaType('text')
      setMediaFiles([])
      setMediaPreviews([])
      setSelectedPrivacy('public')
      setSelectedEmoji('')
      setSelectedLocation('')
      setTaggedUsers(new Set())
      setSelectedBgColor(null)
      setShowEmojiPicker(false)
      setShowLocationPicker(false)
      setShowGifPicker(false)
      setShowUserTagger(false)
      setShowMoreOptions(false)
      setShowCreatePostModal(false)
    } catch (error) {
      console.error('Erreur création publication:', error)
      alert('Une erreur est survenue lors de la publication.')
    }
  }

  const loadMorePosts = useCallback(async () => {
    if (!hasMorePosts || isLoadingPosts) return

    setIsLoadingPosts(true)
    const nextPage = page + 1

    try {
      const response = await fetch(`${apiUrl}/api/posts/?page=${nextPage}&page_size=${POSTS_PAGE_SIZE}`)
      if (!response.ok) {
        setHasMorePosts(false)
        return
      }

      const data = await response.json()
      let nextPosts = []
      if (Array.isArray(data)) {
        nextPosts = data
      } else if (data && data.results) {
        nextPosts = data.results
      }

      if (nextPosts.length > 0) {
        setPosts(prev => [...prev, ...nextPosts])
        setPage(nextPage)
        setHasMorePosts(nextPosts.length >= POSTS_PAGE_SIZE)
      } else {
        setHasMorePosts(false)
      }
    } catch (err) {
      console.error('Erreur chargement posts:', err)
      setHasMorePosts(false)
    } finally {
      setIsLoadingPosts(false)
    }
  }, [page, hasMorePosts, isLoadingPosts])

  useEffect(() => {
    if (!postsObserverRef.current || !hasMorePosts || isLoadingPosts) return

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          loadMorePosts()
        }
      })
    }, { root: null, rootMargin: '300px', threshold: 0.1 })

    observer.observe(postsObserverRef.current)
    return () => observer.disconnect()
  }, [loadMorePosts, hasMorePosts, isLoadingPosts])

  // Envoyer une demande d'ami
  const handleSendFriendRequest = async (receiverId, buttonKey) => {
    if (!currentUser) {
      router.push('/login')
      return
    }

    if (!receiverId) {
      console.error('Impossible d’envoyer la demande : receiverId introuvable.', { receiverId, buttonKey })
      alert('Impossible d’envoyer la demande d’amitié. Réessayez plus tard.')
      return
    }

    const requestKey = buttonKey || receiverId
    setLoadingFriend(prev => ({ ...prev, [requestKey]: true }))
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/friends/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ receiver_id: receiverId })
      })

      if (response.ok) {
        setFriendRequests(prev => ({
          ...prev,
          [requestKey]: 'sent'
        }))
      } else {
        const error = await response.json().catch(() => null)
        console.error('Erreur:', error)
        alert(error?.detail || 'Impossible d’envoyer la demande d’amitié.')
      }
    } catch (err) {
      console.error('Erreur envoi demande amitié:', err)
      alert('Erreur réseau lors de l’envoi de la demande d’amitié.')
    } finally {
      setLoadingFriend(prev => ({ ...prev, [requestKey]: false }))
    }
  }

  return (
    <div className="min-h-screen bg-future-50 text-future-900">
      <header className="border-b border-future-800 bg-future-950/95 backdrop-blur sticky top-0 z-50">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-6">
          <Link href="/" onClick={handleHomeClick} className="inline-flex items-center gap-2 text-2xl font-bold text-future-100">
            <HomeIcon className="w-6 h-6 text-future-100" />
            FopCam
          </Link>

          <nav className="hidden items-center gap-8 text-sm font-medium text-future-300 md:flex">
            <Link href="/groups" className="hover:text-future-100 transition-colors">
              Communautés
            </Link>
            <Link href="/stories" className="hover:text-future-100 transition-colors">
              Histoires
            </Link>
            <Link href="/reels" className="hover:text-future-100 transition-colors">
              Clips
            </Link>
            <Link href="/game" className="hover:text-future-100 transition-colors">
              Jeu
            </Link>
            <a href="#products" onClick={(e) => { e.preventDefault(); scrollToSection('products') }} className="hover:text-future-100 transition-colors">
              {t('nav.products')}
            </a>
            <a href="#producers" onClick={(e) => { e.preventDefault(); scrollToSection('producers') }} className="hover:text-future-100 transition-colors">
              Vendeurs
            </a>
            <a href="#feed" onClick={(e) => { e.preventDefault(); scrollToSection('feed') }} className="hover:text-future-100 transition-colors">
              Fil d'actualité
            </a>
          </nav>

          <div className="flex items-center gap-3">
            {currentUser ? (
              <>
                <Link href="/messages" className="text-future-200 hover:text-future-100">
                  <ChatBubbleBottomCenterIcon className="w-5 h-5" />
                </Link>
                <Link href="/profile" className="rounded-full bg-future-700 px-4 py-2 text-sm font-medium text-white hover:bg-future-600 transition-colors">
                  Mon profil
                </Link>
                {(currentUser?.role === 'producer' || currentUser?.shop_id || currentUser?.profile?.shop_id) && (
                  <Link
                    href="/producer/dashboard"
                    className="rounded-full bg-white border border-future-700 px-4 py-2 text-sm font-medium text-future-700 hover:bg-future-100 hover:text-future-900 transition-colors"
                  >
                    Ma boutique
                  </Link>
                )}
                <button
                  type="button"
                  onClick={handleLogout}
                  className="rounded-full border border-future-700 px-4 py-2 text-sm font-medium text-future-200 hover:border-future-100 hover:text-future-100 transition-colors"
                >
                  Déconnexion
                </button>
              </>
            ) : (
              <>
                <Link href="/login" className="rounded-full border border-future-700 px-4 py-2 text-sm font-medium text-future-200 hover:border-future-100 hover:text-future-100 transition-colors">
                  {t('login')}
                </Link>
                <Link href="/register" className="rounded-full bg-future-700 px-4 py-2 text-sm font-medium text-white hover:bg-future-600 transition-colors">
                  {t('register')}
                </Link>
              </>
            )}
          </div>
        </div>
      </header>

      <main>
        {/* SECTION STORIES */}
        <section className="mx-auto max-w-7xl px-4 py-20 sm:px-6">
          <div className="flex items-center justify-between gap-4 mb-8">
            <div>
              <p className="text-sm font-semibold uppercase tracking-[0.3em] text-fopcam-700">📸 Stories</p>
              <h2 className="mt-3 text-3xl font-bold tracking-tight text-future-900">Découvrez les histoires de nos vendeurs</h2>
            </div>
            <button
              onClick={() => setShowStoryModal(true)}
              className="rounded-full bg-fopcam-800 px-5 py-3 text-sm font-semibold text-white hover:bg-fopcam-900 transition"
            >
              Publier une story
            </button>
          </div>
          <div className="rounded-3xl border border-future-200 bg-white shadow-sm overflow-hidden">
            <StoriesBar
              stories={stories}
              onCreateStory={() => setShowStoryModal(true)}
              onViewStory={async (storyId) => {
                try {
                  const token = getAuthToken()
                  if (!token) return
                  
                  await fetch(`${apiUrl}/api/stories/${storyId}/view/`, {
                    method: 'POST',
                    headers: { Authorization: `Bearer ${token}` }
                  })
                } catch (error) {
                  console.error('Erreur lors du marquage de la story comme vue:', error)
                }
              }}
              onLikeStory={async (storyId) => {
                try {
                  const token = getAuthToken()
                  if (!token) return
                  
                  await fetch(`${apiUrl}/api/stories/${storyId}/like/`, {
                    method: 'POST',
                    headers: { Authorization: `Bearer ${token}` }
                  })
                  
                  // Mettre à jour l'état local
                  setStories(prev => prev.map(story => 
                    story.id === storyId 
                      ? { ...story, is_liked: !story.is_liked }
                      : story
                  ))
                } catch (error) {
                  console.error('Erreur lors du like de la story:', error)
                }
              }}
            />
          </div>
        </section>

        {/* SECTION RECHERCHE AVANCÉE */}
        <section id="advanced-search" className="py-20">
          <div className="mx-auto max-w-7xl px-4 sm:px-6">
            <div className="flex flex-col gap-6 md:flex-row md:items-end md:justify-between mb-12">
              <div>
                <p className="text-sm font-semibold uppercase tracking-[0.3em] text-fopcam-700">🔎 Recherche avancée</p>
                <h2 className="mt-3 text-4xl font-bold tracking-tight text-future-900">Trouvez des catégories, produits ou vendeurs</h2>
                <p className="mt-2 text-future-600">Recherchez par mot-clé, filtrez par secteur ou explorez les meilleurs vendeurs.</p>
              </div>
              <button
                type="button"
                onClick={handleClearSearch}
                className="inline-flex items-center rounded-3xl border border-future-300 bg-white px-5 py-3 text-sm font-semibold text-future-900 shadow-sm transition hover:bg-future-100"
              >
                Réinitialiser
              </button>
            </div>

            <form onSubmit={handleSearchSubmit} className="grid gap-4 xl:grid-cols-[1.4fr_0.8fr]">
              <div className="grid gap-4 md:grid-cols-2">
                <label className="space-y-2">
                  <span className="text-sm font-medium text-future-500">Mot-clé</span>
                  <input
                    type="search"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="Rechercher une catégorie, un produit ou un vendeur"
                    className="w-full rounded-3xl border border-white/10 bg-white px-4 py-3 text-future-900 shadow-sm transition focus:border-fopcam-400 focus:ring-2 focus:ring-fopcam-400/20"
                  />
                </label>
                <label className="space-y-2">
                  <span className="text-sm font-medium text-future-500">Portée</span>
                  <select
                    value={searchScope}
                    onChange={(e) => setSearchScope(e.target.value)}
                    className="w-full rounded-3xl border border-white/10 bg-white px-4 py-3 text-future-900 shadow-sm transition focus:border-fopcam-400 focus:ring-2 focus:ring-fopcam-400/20"
                  >
                    <option value="all">Toutes les catégories</option>
                    <option value="categories">Catégories</option>
                    <option value="products">Produits</option>
                    <option value="producers">Vendeurs</option>
                  </select>
                </label>
                <label className="space-y-2">
                  <span className="text-sm font-medium text-future-500">Filtrer par catégorie</span>
                  <select
                    value={searchCategoryFilter}
                    onChange={(e) => setSearchCategoryFilter(e.target.value)}
                    className="w-full rounded-3xl border border-white/10 bg-white px-4 py-3 text-future-900 shadow-sm transition focus:border-fopcam-400 focus:ring-2 focus:ring-fopcam-400/20"
                  >
                    <option value="">Toutes les catégories</option>
                    {categoryOptions.map((option) => (
                      <option key={option.value} value={option.value} className="bg-white text-future-900">
                        {option.label}
                      </option>
                    ))}
                  </select>
                </label>
              </div>

              <div className="flex flex-col justify-end gap-4">
                <button
                  type="submit"
                  className="inline-flex items-center justify-center rounded-3xl bg-fopcam-700 px-6 py-4 text-sm font-semibold text-white shadow-lg shadow-fopcam-700/20 transition hover:bg-fopcam-600"
                >
                  Lancer la recherche
                </button>
                <div className="rounded-3xl border border-white/10 bg-white/80 p-5 text-future-600 shadow-sm">
                  <p className="text-sm font-semibold text-future-900">Conseil</p>
                  <p className="mt-2 text-sm">Utilisez des mots-clés comme « cosmétique », « mobilier », « vendeur local » ou le nom d’un produit pour affiner les résultats.</p>
                </div>
              </div>
            </form>

            {searchResultsActive && (
              <div className="mt-10 rounded-3xl border border-future-200 bg-white p-6 shadow-sm">
                <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between mb-6">
                  <div>
                    <p className="text-sm uppercase tracking-[0.3em] text-fopcam-700">Résultats</p>
                    <h3 className="mt-2 text-2xl font-bold text-future-900">{searchResults.length} résultat{searchResults.length > 1 ? 's' : ''}</h3>
                  </div>
                  <p className="text-sm text-future-500">Recherche : «{searchQuery || '...'}»</p>
                </div>

                {searchResults.length === 0 ? (
                  <div className="rounded-3xl border border-dashed border-future-200 bg-future-50 p-10 text-center text-future-500">
                    Aucune correspondance trouvée. Essayez un autre mot-clé ou élargissez la portée.
                  </div>
                ) : (
                  <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
                    {searchResults.map((result, idx) => {
                      if (result.type === 'category') {
                        return (
                          <div key={`${result.type}-${result.item.id || result.item.name}-${idx}`} className="rounded-3xl border border-future-200 bg-future-50 p-6">
                            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-fopcam-700">Catégorie</p>
                            <h4 className="mt-4 text-xl font-bold text-future-900">{translateCategoryName(result.item.name || result.item.title)}</h4>
                            <p className="mt-3 text-sm text-future-600">Explorez les produits associés et découvrez des offres dans ce secteur.</p>
                          </div>
                        )
                      }

                      if (result.type === 'product') {
                        return (
                          <div key={`${result.type}-${result.item.id || result.item.title}-${idx}`} className="rounded-3xl border border-future-200 bg-white p-6 shadow-sm">
                            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-fopcam-700">Produit</p>
                            <h4 className="mt-4 text-xl font-bold text-future-900">{result.item.title}</h4>
                            <p className="mt-2 text-sm text-future-500 line-clamp-2">{result.item.description || 'Description non disponible.'}</p>
                            <div className="mt-4 flex items-center justify-between text-sm text-future-600">
                              <span>{result.item.shop?.name || 'Vendeur'}</span>
                              <span>{result.item.price ? `${result.item.price} FCFA` : 'Prix indisponible'}</span>
                            </div>
                          </div>
                        )
                      }

                      return (
                        <div key={`${result.type}-${result.item.id || result.item.shop_name}-${idx}`} className="rounded-3xl border border-future-200 bg-white p-6 shadow-sm">
                          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-fopcam-700">Vendeur</p>
                          <h4 className="mt-4 text-xl font-bold text-future-900">{result.item.shop_name || result.item.user?.username}</h4>
                          <p className="mt-2 text-sm text-future-500 line-clamp-2">{result.item.bio || 'Aucun descriptif disponible.'}</p>
                        </div>
                      )
                    })}
                  </div>
                )}
              </div>
            )}
          </div>
        </section>

        {/* HERO SECTION */}
        <section className="overflow-hidden py-20">
          <div className="mx-auto grid max-w-7xl gap-12 px-4 py-4 sm:px-6 lg:grid-cols-2 lg:items-center">
            <div>
              <span className="inline-flex items-center rounded-full bg-fopcam-100 px-3 py-1 text-sm font-semibold text-fopcam-700">
                {isConnected ? 'En ligne' : 'Hors ligne'}
              </span>
              <h1 className="mt-6 text-4xl font-extrabold tracking-tight text-future-900 sm:text-5xl">
                Achetez directement des vendeurs locaux
              </h1>
              <p className="mt-6 max-w-2xl text-lg leading-8 text-future-600">
                FopCam est un réseau social et marketplace qui connecte les vendeurs locaux avec les consommateurs. Découvrez des produits frais, construisez une communauté et soutenez l'économie locale.
              </p>
              <div className="mt-10 flex flex-col gap-4 sm:flex-row">
                <Link href="/game" className="inline-flex items-center justify-center rounded-full bg-fopcam-800 px-8 py-3 text-sm font-semibold text-white shadow-lg shadow-fopcam-500/20 transition hover:bg-fopcam-900">
                  Jouer maintenant
                </Link>
                <a href="#products" className="inline-flex items-center justify-center rounded-full border border-future-300 bg-white px-8 py-3 text-sm font-semibold text-future-700 transition hover:border-fopcam-600 hover:text-fopcam-700">
                  Découvrir les produits
                  <ChevronDownIcon className="ml-2 h-4 w-4" />
                </a>
                <a href="#producers" className="inline-flex items-center justify-center rounded-full border border-future-300 bg-white px-8 py-3 text-sm font-semibold text-future-700 transition hover:border-fopcam-600 hover:text-fopcam-700">
                  Rencontrer les vendeurs
                </a>
              </div>

              <div className="mt-12 grid gap-4 sm:grid-cols-3">
                {stats.map((stat) => (
                  <div key={stat.label} className="rounded-3xl border border-future-200 bg-white p-6 shadow-sm">
                    <stat.icon className="h-6 w-6 text-fopcam-700" />
                    <p className="mt-4 text-3xl font-bold text-future-900">{stat.value}</p>
                    <p className="mt-2 text-sm text-future-500">{stat.label}</p>
                  </div>
                ))}
              </div>
            </div>

            <div className="relative rounded-[2rem] bg-gradient-to-br from-fopcam-800 to-fopcam-900 p-8 text-white shadow-xl shadow-fopcam-700/20">
              <div className="absolute inset-0 opacity-30" style={{ backgroundImage: 'radial-gradient(circle at 20% 20%, rgba(255,255,255,0.25), transparent 25%), radial-gradient(circle at 80% 30%, rgba(255,255,255,0.16), transparent 20%)' }} />
              <div className="relative space-y-6">
                <div className="rounded-3xl border border-white/10 bg-white/10 p-5 backdrop-blur-sm">
                  <p className="text-sm uppercase tracking-[0.2em] text-white/70">🌟 Produit en vedette</p>
                  <h2 className="mt-3 text-3xl font-bold text-white">{featuredProducts[0]?.title || 'Produits locaux'}</h2>
                  <p className="mt-2 text-sm text-white/80">{featuredProducts[0]?.description || 'Découvrez une sélection de produits frais et responsables.'}</p>
                  <div className="mt-4 flex items-center gap-3 text-sm text-white/75">
                    <span>{featuredProducts[0]?.shop?.name || 'Vendeur local'}</span>
                    <span className="h-1 w-1 rounded-full bg-white/70" />
                    <span className="text-lg font-bold">{featuredProducts[0]?.price ? `${featuredProducts[0].price} CFA` : 'Prix variable'}</span>
                  </div>
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                  {featuredProducts.slice(1, 3).map((product) => (
                    <div key={product.id} className="rounded-3xl border border-white/10 bg-white/10 p-4 hover:bg-white/20 transition">
                      <h3 className="text-lg font-semibold text-white">{product.title}</h3>
                      <p className="mt-2 text-sm text-white/70 line-clamp-2">{product.description}</p>
                      <p className="mt-3 text-sm font-bold text-fopcam-300">{product.price ? `${product.price} CFA` : 'Nous contacter'}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* SECTION PRODUITS EN VEDETTES */}
        <section id="featured" className="py-20">
          <div className="mx-auto max-w-7xl px-4 sm:px-6">
            <div className="flex flex-col gap-6 md:flex-row md:items-end md:justify-between mb-12">
              <div>
                <p className="text-sm font-semibold uppercase tracking-[0.3em] text-fopcam-700">⭐ En vedette</p>
                <h2 className="mt-3 text-4xl font-bold tracking-tight text-future-900">Les produits les plus populaires</h2>
                <p className="mt-2 text-future-600">Découvrez les favoris de notre communauté</p>
              </div>
              <Link href="/products" className="text-sm font-semibold text-fopcam-700 hover:text-fopcam-900 transition">
                Voir tous les produits →
              </Link>
            </div>

            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {featuredProducts.map((product) => (
                <div key={product.id} className="group overflow-hidden rounded-3xl border border-future-200 bg-white shadow-sm transition hover:-translate-y-2 hover:shadow-lg">
                  <div className="aspect-[4/3] bg-gradient-to-br from-fopcam-50 to-future-100 relative overflow-hidden">
                    <img
                      src={buildMediaUrl(product.image) || '/default-product.png'}
                      alt={product.title}
                      loading="lazy"
                      decoding="async"
                      className="h-full w-full object-cover group-hover:scale-110 transition duration-500"
                    />
                    <button
                      onClick={() => handleLikeProduct(product.id)}
                      className="absolute top-3 right-3 p-2 bg-white rounded-full shadow-md hover:shadow-lg transition"
                    >
                      {likedProducts.has(product.id) ? (
                        <HeartIconSolid className="w-5 h-5 text-red-500" />
                      ) : (
                        <HeartIcon className="w-5 h-5 text-future-400" />
                      )}
                    </button>
                  </div>
                  <div className="p-6">
                    <div className="flex items-start justify-between mb-3">
                      <div>
                        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-future-500">{product.shop?.name || 'Vendeur'}</p>
                        <h3 className="mt-2 text-xl font-bold text-future-900">{product.title}</h3>
                      </div>
                      <div className="flex items-center gap-1 bg-fopcam-100 px-2 py-1 rounded-full">
                        <StarIcon className="w-3 h-3 text-fopcam-700" />
                        <span className="text-xs font-semibold text-fopcam-700">{(product.rating || 4.5).toFixed(1)}</span>
                      </div>
                    </div>
                    <p className="text-sm leading-6 text-future-600 line-clamp-2">{product.description}</p>
                    <div className="mt-6 flex items-center justify-between">
                      <span className="text-xl font-bold text-fopcam-800">{product.price ? `${product.price} CFA` : 'À partir de 0 CFA'}</span>
                      <div className="flex items-center gap-3">
                        <Link href={`/products/${product.id}?buy=1`} className="inline-flex items-center gap-2 rounded-full border border-fopcam-300 bg-white px-4 py-2 text-sm font-semibold text-fopcam-700 hover:bg-fopcam-100 transition">
                          Commander
                        </Link>
                        <button
                          onClick={() => handleAddToCart(product)}
                          className="inline-flex items-center justify-center p-2 rounded-full bg-fopcam-700 text-white hover:bg-fopcam-800 transition"
                        >
                          <ShoppingBagIcon className="w-5 h-5" />
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section id="latest" className="py-20">
          <div className="mx-auto max-w-7xl px-4 sm:px-6">
            <div className="flex flex-col gap-6 md:flex-row md:items-end md:justify-between mb-12">
              <div>
                <p className="text-sm font-semibold uppercase tracking-[0.3em] text-fopcam-700">🆕 Nouveautés</p>
                <h2 className="mt-3 text-4xl font-bold tracking-tight text-future-900">Derniers produits ajoutés</h2>
                <p className="mt-2 text-future-600">Découvrez les nouveautés fraîchement publiées par nos vendeurs.</p>
              </div>
              <Link href="/products" className="text-sm font-semibold text-fopcam-700 hover:text-fopcam-900">
                Voir tous les produits →
              </Link>
            </div>

            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {latestProducts.map((product) => (
                <div key={product.id} className="group overflow-hidden rounded-3xl border border-future-200 bg-white shadow-sm transition hover:-translate-y-2 hover:shadow-lg">
                  <div className="aspect-[4/3] bg-future-100 overflow-hidden">
                    <img
                      src={buildMediaUrl(product.image) || '/default-product.png'}
                      alt={product.title}
                      loading="lazy"
                      decoding="async"
                      className="h-full w-full object-cover transition duration-500"
                    />
                  </div>
                  <div className="p-6">
                    <p className="text-xs font-semibold uppercase tracking-[0.2em] text-future-500">{product.shop?.name || 'Vendeur local'}</p>
                    <h3 className="mt-3 text-xl font-bold text-future-900">{product.title}</h3>
                    <p className="mt-3 text-sm leading-6 text-future-600 line-clamp-2">{product.description}</p>
                    <div className="mt-4 flex items-center justify-between">
                      <span className="text-lg font-bold text-fopcam-800">{product.price ? `${product.price} CFA` : 'Prix variable'}</span>
                      <Link href={`/products/${product.id}`} className="text-sm font-semibold text-fopcam-700 hover:text-fopcam-900">
                        Voir
                      </Link>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* SECTION GROUPES */}
        <section id="groups" className="scroll-mt-28 py-20">
          <div className="mx-auto max-w-7xl px-4 sm:px-6">
            <div className="flex flex-col gap-6 md:flex-row md:items-end md:justify-between mb-12">
              <div>
                <p className="text-sm font-semibold uppercase tracking-[0.3em] text-fopcam-700">👥 Groupes</p>
                <h2 className="mt-3 text-4xl font-bold tracking-tight text-future-900">Rejoignez des communautés locales</h2>
                <p className="mt-2 text-future-600">Partagez, discutez et trouvez des partenaires autour de vos centres d’intérêt.</p>
              </div>
              <Link href="/groups" className="text-sm font-semibold text-fopcam-700 hover:text-fopcam-900">
                Voir tous les groupes →
              </Link>
            </div>

            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {groups.slice(0, 6).map((group) => (
                <div key={group.id} className="rounded-3xl border border-future-200 bg-white p-6 shadow-sm hover:shadow-lg transition">
                  <p className="text-xs font-semibold uppercase tracking-[0.2em] text-future-500">Groupe</p>
                  <h3 className="mt-4 text-2xl font-bold text-future-900">{group.name}</h3>
                  <p className="mt-3 text-sm leading-6 text-future-600">{group.description || 'Rejoignez ce groupe pour échanger avec des vendeurs et consommateurs locaux.'}</p>
                  <div className="mt-6 flex items-center justify-between">
                    <span className="text-sm font-semibold text-fopcam-700">{group.members_count ?? 20} membres</span>
                    <button className="inline-flex items-center justify-center rounded-full bg-fopcam-800 px-4 py-2 text-sm font-semibold text-white hover:bg-fopcam-900 transition">
                      Rejoindre
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* SECTION PRODUCTEURS AVEC INTERACTIONS SOCIALES */}
        <section id="producers" className="scroll-mt-28 mx-auto max-w-7xl px-4 py-20 sm:px-6">
          <div className="flex flex-col gap-6 md:flex-row md:items-end md:justify-between mb-12">
            <div>
              <p className="text-sm font-semibold uppercase tracking-[0.3em] text-fopcam-700">👨‍🌾 Vendeurs</p>
              <h2 className="mt-3 text-4xl font-bold tracking-tight text-future-900">Nos vendeurs partenaires</h2>
              <p className="mt-2 text-future-600">Connectez-vous avec les vendeurs, suivez leurs boutiques et devenez amis</p>
            </div>
            <Link href="/profile" className="text-sm font-semibold text-fopcam-700 hover:text-fopcam-900">
              Voir tous les vendeurs →
            </Link>
          </div>

          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {producers.slice(0, 6).map((producer) => (
              <div key={producer.id} className="group rounded-3xl border border-future-200 bg-white p-6 shadow-sm hover:shadow-lg transition">
                <div className="relative mb-4">
                  <img
                    src={buildMediaUrl(producer.profile_image) || '/default-avatar.png'}
                    alt={producer.user?.username || producer.shop_name}
                    loading="lazy"
                    decoding="async"
                    className="w-full h-48 rounded-2xl object-cover group-hover:scale-105 transition duration-500"
                  />
                  <div className="absolute top-3 right-3 inline-flex items-center rounded-full bg-fopcam-700 px-3 py-1 text-xs font-semibold text-white">
                    {producer.verified ? '✓ Vérifié' : 'En attente'}
                  </div>
                </div>

                <div className="flex items-start gap-3 mb-4">
                  <div>
                    <p className="text-lg font-bold text-future-900">{producer.user?.first_name || producer.user?.username || producer.shop_name}</p>
                    <p className="text-sm font-semibold text-fopcam-700">{producer.shop_name}</p>
                  </div>
                </div>

                <p className="text-sm leading-5 text-future-600 line-clamp-3 mb-6">{producer.bio || 'Vendeur local engagé dans la production responsable.'}</p>

                {/* Interactions sociales */}
                <div className="space-y-3">
                  {/* Voir la boutique */}
                  <Link
                    href={producer.shop_id ? `/shop/${producer.shop_id}` : `/profile/${producer.user?.username || producer.id}`}
                    className="w-full inline-flex items-center justify-center gap-2 rounded-full border border-fopcam-300 bg-fopcam-50 px-4 py-2 text-sm font-semibold text-fopcam-700 hover:bg-fopcam-100 transition"
                  >
                    <ShoppingBagIcon className="w-4 h-4" />
                    Voir la boutique
                  </Link>

                  <div className="grid grid-cols-2 gap-3">
                    {/* Devenir ami */}
                    <button
                      onClick={() => handleSendFriendRequest(producer.user?.id, producer.id)}
                      disabled={loadingFriend[producer.id] || friendRequests[producer.id] === 'sent'}
                      className={`inline-flex items-center justify-center gap-2 rounded-full py-2 text-sm font-semibold transition ${
                        friendRequests[producer.id] === 'sent'
                          ? 'bg-green-100 text-green-700 border border-green-300'
                          : 'border border-future-300 bg-white text-future-700 hover:bg-future-50'
                      } ${loadingFriend[producer.id] ? 'opacity-50 cursor-not-allowed' : ''}`}
                    >
                      <UserPlusIcon className="w-4 h-4" />
                      {friendRequests[producer.id] === 'sent' ? 'Demandé' : 'Devenir ami'}
                    </button>

                    {/* Discuter */}
                    <Link
                      href={`/messages?user=${producer.user?.id || producer.id}`}
                      className="inline-flex items-center justify-center gap-2 rounded-full border border-fopcam-300 bg-fopcam-50 px-4 py-2 text-sm font-semibold text-fopcam-700 hover:bg-fopcam-100 transition"
                    >
                      <ChatBubbleBottomCenterIcon className="w-4 h-4" />
                      Discuter
                    </Link>
                  </div>
                </div>

                {/* Stats */}
                <div className="mt-6 grid grid-cols-4 gap-3 border-t border-future-100 pt-4">
                  <div className="text-center">
                    <p className="text-2xl font-bold text-fopcam-700">{producer.products_count || 0}</p>
                    <p className="text-xs text-future-600">Produits</p>
                  </div>
                  <div className="text-center">
                    <p className="text-2xl font-bold text-fopcam-700">{producer.followers_count || 0}</p>
                    <p className="text-xs text-future-600">Followers</p>
                  </div>
                  <div className="text-center">
                    <p className="text-2xl font-bold text-fopcam-700">{producer.likes_count || 0}</p>
                    <p className="text-xs text-future-600">Likes</p>
                  </div>
                  <div className="text-center">
                    <div className="flex items-center justify-center gap-1">
                      <p className="text-2xl font-bold text-fopcam-700">{(producer.rating || 0).toFixed(1)}</p>
                      <span className="text-lg">⭐</span>
                    </div>
                    <p className="text-xs text-future-600">Note</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* SECTION FIL D'ACTUALITÉ */}
        <section id="feed" className="scroll-mt-28 mx-auto max-w-7xl px-4 py-20 sm:px-6">
          <div className="space-y-10">
            <div className="flex flex-col gap-6 md:flex-row md:items-end md:justify-between mb-12">
              <div>
                <p className="text-sm font-semibold uppercase tracking-[0.3em] text-fopcam-700">📰 Fil d'actualité</p>
                <h2 className="mt-3 text-4xl font-bold tracking-tight text-future-900">Suivez la communauté</h2>
                <p className="mt-2 text-future-600">Les derniers posts de nos vendeurs et acheteurs</p>
              </div>
              <Link href="/messages" className="text-sm font-semibold text-fopcam-700 hover:text-fopcam-900">
                Voir tous les posts →
              </Link>
            </div>

            <div className="rounded-3xl border border-gray-300 bg-white shadow-sm mb-10 overflow-hidden w-full">
              {/* Simple button to open modal */}
              <div className="p-4">
                <button
                  onClick={() => setShowCreatePostModal(true)}
                  className="w-full flex items-center gap-3 px-4 py-3 rounded-full bg-future-50 hover:bg-future-100 transition border border-future-200"
                >
                  <img
                    src={currentUser?.profile_image || '/default-avatar.png'}
                    alt={currentUser?.username || 'Utilisateur'}
                    className="h-10 w-10 rounded-full object-cover"
                  />
                  <span className="text-future-500">Quoi de neuf, {currentUser?.first_name || 'John'} ?</span>
                </button>
              </div>
            </div>

            {/* CREATE POST MODAL */}
            {showCreatePostModal && (
              <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 px-4">
                <div className="bg-white rounded-2xl shadow-2xl w-full max-w-3xl mx-auto max-h-[90vh] overflow-y-auto">
                  {/* Header */}
                  <div className="flex items-center justify-between px-6 py-4 border-b border-future-200">
                    <h2 className="text-xl font-bold text-future-900">Créer une publication</h2>
                    <button
                      onClick={() => setShowCreatePostModal(false)}
                      className="p-2 hover:bg-future-100 rounded-full transition"
                    >
                      <svg className="w-6 h-6 text-future-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>

                  {/* Content */}
                  <div className="p-6 space-y-4">
                    {/* User Info */}
                    <div className="flex items-center gap-3">
                      <img
                        src={currentUser?.profile_image || '/default-avatar.png'}
                        alt={currentUser?.username || 'Utilisateur'}
                        className="h-12 w-12 rounded-full object-cover"
                      />
                      <div className="flex-1">
                        <p className="font-semibold text-future-900">{currentUser?.first_name ? `${currentUser.first_name} ${currentUser.last_name || ''}` : currentUser?.username || 'Utilisateur'}</p>
                        <div className="relative inline-block">
                          <button
                            type="button"
                            onClick={() => setShowPrivacyMenu(prev => !prev)}
                            className="inline-flex items-center gap-2 rounded-full border border-future-300 bg-future-50 px-3 py-1 text-sm text-future-700 hover:bg-future-100 transition"
                          >
                            <span className="text-xs">{selectedPrivacy === 'public' ? '🌍' : '👥'}</span>
                            {selectedPrivacy === 'public' ? 'Public' : 'Amis'}
                            <span className="text-xs">▼</span>
                          </button>
                          {showPrivacyMenu && (
                            <div className="absolute left-0 mt-2 w-40 rounded-2xl border border-future-200 bg-white shadow-lg z-10">
                              <button
                                type="button"
                                onClick={() => {
                                  setSelectedPrivacy('public')
                                  setShowPrivacyMenu(false)
                                }}
                                className="w-full text-left px-4 py-3 hover:bg-future-100 transition"
                              >
                                🌍 Public
                              </button>
                              <button
                                type="button"
                                onClick={() => {
                                  setSelectedPrivacy('friends')
                                  setShowPrivacyMenu(false)
                                }}
                                className="w-full text-left px-4 py-3 hover:bg-future-100 transition"
                              >
                                👥 Amis
                              </button>
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                    <div className="rounded-2xl border border-future-200 bg-future-50 p-4">
                      <label className="block text-sm font-semibold text-future-900 mb-2">Publier dans le groupe</label>
                      {groups.length > 0 ? (
                        <select
                          value={selectedGroup}
                          onChange={(e) => setSelectedGroup(e.target.value)}
                          className="w-full rounded-2xl border border-future-300 bg-white px-4 py-3 text-future-900 outline-none focus:border-fopcam-700 transition"
                        >
                          <option value="">Publier sur mon fil (aucun groupe)</option>
                          {groups.map((group) => (
                            <option key={group.id} value={group.id}>
                              {group.name}{group.is_member ? ' (Membre)' : ''}
                            </option>
                          ))}
                        </select>
                      ) : (
                        <p className="text-sm text-future-600">Aucun groupe disponible pour le moment.</p>
                      )}
                    </div>

                    {/* Textarea with Checkmark */}
                    <div className={`relative rounded-3xl p-4 ${
                      selectedBgColor === 'magenta' ? 'bg-pink-500 text-white' :
                      selectedBgColor === 'red' ? 'bg-red-500 text-white' :
                      selectedBgColor === 'black' ? 'bg-slate-900 text-white' :
                      selectedBgColor === 'gradient1' ? 'bg-gradient-to-br from-pink-500 to-red-500 text-white' :
                      selectedBgColor === 'purple' ? 'bg-purple-600 text-white' :
                      selectedBgColor === 'gradient2' ? 'bg-gradient-to-br from-purple-500 to-pink-500 text-white' :
                      selectedBgColor === 'gradient3' ? 'bg-gradient-to-br from-orange-400 to-yellow-400 text-white' :
                      selectedBgColor === 'dark' ? 'bg-slate-800 text-white' :
                      selectedBgColor === 'gradient4' ? 'bg-gradient-to-br from-indigo-600 to-purple-600 text-white' :
                      'bg-white text-future-900'
                    }`}>
                      <textarea
                        value={postContent}
                        onChange={(e) => setPostContent(e.target.value)}
                        placeholder={`Quoi de neuf, ${currentUser?.first_name || 'John'} ?`}
                        rows={10}
                        className="w-full bg-transparent text-2xl placeholder:text-future-400 outline-none resize-none border-none p-0"
                        style={{ minHeight: '260px' }}
                      />
                      {postContent.trim() && (
                        <button
                          type="button"
                          className="absolute top-4 right-4 p-2 bg-blue-500 text-white rounded-full hover:bg-blue-600 transition shadow-md"
                        >
                          ✓
                        </button>
                      )}
                    </div>

                    {/* Color Palette */}
                    <div className="flex gap-2 overflow-x-auto pb-2">
                      {[
                        { name: 'none', bg: 'bg-white', border: true },
                        { name: 'magenta', bg: 'bg-pink-500' },
                        { name: 'red', bg: 'bg-red-500' },
                        { name: 'black', bg: 'bg-black' },
                        { name: 'gradient1', bg: 'bg-gradient-to-br from-pink-500 to-red-500' },
                        { name: 'purple', bg: 'bg-purple-600' },
                        { name: 'gradient2', bg: 'bg-gradient-to-br from-purple-500 to-pink-500' },
                        { name: 'gradient3', bg: 'bg-gradient-to-br from-orange-400 to-yellow-400' },
                        { name: 'dark', bg: 'bg-slate-800' },
                        { name: 'gradient4', bg: 'bg-gradient-to-br from-indigo-600 to-purple-600' }
                      ].map((color) => (
                        <button
                          key={color.name}
                          onClick={() => setSelectedBgColor(color.name)}
                          className={`flex-shrink-0 w-12 h-12 rounded-2xl transition ${
                            color.bg
                          } ${color.border ? 'border-2 border-future-300' : ''} ${
                            selectedBgColor === color.name ? 'ring-2 ring-offset-2 ring-blue-500' : ''
                          }`}
                        />
                      ))}
                      <button className="flex-shrink-0 w-12 h-12 rounded-2xl bg-future-100 hover:bg-future-200 transition flex items-center justify-center">
                        <span className="text-xl">→</span>
                      </button>
                    </div>

                    {/* Media Preview */}
                    {mediaPreviews.length > 0 && (
                      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                        {mediaPreviews.map((preview, index) => (
                          <div key={index} className="rounded-xl overflow-hidden bg-future-100 relative">
                            {selectedMediaType === 'photo' || (mediaFiles[index]?.type && mediaFiles[index].type.startsWith('image/')) ? (
                              <img src={preview} alt={`Prévisualisation ${index + 1}`} className="w-full max-h-40 object-cover" />
                            ) : selectedMediaType === 'audio' || (mediaFiles[index]?.type && mediaFiles[index].type.startsWith('audio/')) ? (
                              <audio controls src={preview} className="w-full" />
                            ) : selectedMediaType === 'gif' ? (
                              <img src={preview} alt="GIF Preview" className="w-full max-h-40 object-cover" />
                            ) : (
                              <video controls src={preview} className="w-full max-h-40" />
                            )}
                            <button
                              type="button"
                              onClick={() => removeMediaFile(index)}
                              className="absolute top-2 right-2 bg-red-500 hover:bg-red-600 text-white w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold"
                              title="Supprimer ce média"
                            >
                              ✕
                            </button>
                          </div>
                        ))}
                      </div>
                    )}

                    {selectedMediaType !== 'text' && mediaPreviews.length === 0 && (
                      <div className="border-2 border-dashed border-future-300 rounded-lg p-4">
                        <input
                          type="file"
                          multiple
                          accept={selectedMediaType === 'photo' ? 'image/*' : selectedMediaType === 'audio' ? 'audio/*' : 'video/*'}
                          onChange={handleMediaFileChange}
                          className="w-full"
                        />
                      </div>
                    )}

                    {/* Action Buttons */}
                    <div className="border-t border-future-200 pt-4">
                      <p className="text-sm font-semibold text-future-900 mb-3">Ajouter à votre publication</p>
                      <div className="flex gap-2 justify-center flex-wrap">
                        <button
                          onClick={() => setSelectedMediaType('photo')}
                          className="flex items-center justify-center w-10 h-10 rounded-lg hover:bg-future-100 transition"
                          title="Photo"
                        >
                          📸
                        </button>
                        <button
                          onClick={() => setSelectedMediaType('video')}
                          className="flex items-center justify-center w-10 h-10 rounded-lg hover:bg-future-100 transition"
                          title="Vidéo"
                        >
                          🎥
                        </button>
                        <button
                          onClick={() => setShowUserTagger(prev => !prev)}
                          className="flex items-center justify-center w-10 h-10 rounded-lg hover:bg-future-100 transition"
                          title="Personnes"
                        >
                          👥
                        </button>
                        <button
                          onClick={() => setShowEmojiPicker(!showEmojiPicker)}
                          className="flex items-center justify-center w-10 h-10 rounded-lg hover:bg-future-100 transition"
                          title="Humeur"
                        >
                          😊
                        </button>
                        <button
                          onClick={() => setShowLocationPicker(!showLocationPicker)}
                          className="flex items-center justify-center w-10 h-10 rounded-lg hover:bg-future-100 transition"
                          title="Lieu"
                        >
                          📍
                        </button>
                        <button
                          onClick={() => setShowGifPicker(!showGifPicker)}
                          className="flex items-center justify-center w-10 h-10 rounded-lg hover:bg-future-100 transition"
                          title="GIF"
                        >
                          GIF
                        </button>
                        <button
                          onClick={() => setShowMoreOptions(!showMoreOptions)}
                          className="flex items-center justify-center w-10 h-10 rounded-lg hover:bg-future-100 transition"
                          title="Plus"
                        >
                          ⋯
                        </button>
                      </div>

                      {(showUserTagger || taggedUsers.size > 0) && (
                        <div className="mt-4 rounded-2xl border border-future-200 bg-future-50 p-4">
                          <p className="text-sm font-semibold text-future-900 mb-2">Personnes taguées</p>
                          <div className="flex flex-wrap gap-2">
                            {taggedUsers.size > 0 ? Array.from(taggedUsers).map((userId) => {
                              const user = taggableUsers.find((item) => item.id === userId)
                              return (
                                <span key={userId} className="inline-flex items-center gap-2 rounded-full bg-white px-3 py-1 text-sm text-future-700 shadow-sm">
                                  {user?.user?.username || 'Utilisateur'}
                                  <button type="button" onClick={() => handleUserTag(userId)} className="text-future-500 hover:text-future-700">✕</button>
                                </span>
                              )
                            }) : (
                              <div className="space-y-2">
                                <p className="text-sm text-future-600">Choisissez des amis à taguer dans votre publication.</p>
                                <div className="grid grid-cols-2 gap-2">
                                  {taggableUsers.map((user) => (
                                    <button
                                      key={user.id}
                                      type="button"
                                      onClick={() => handleUserTag(user.id)}
                                      className="rounded-2xl border border-future-200 bg-white px-3 py-2 text-left text-sm hover:bg-future-100 transition"
                                    >
                                      {user.user?.username || user.name || 'Utilisateur'}
                                    </button>
                                  ))}
                                </div>
                              </div>
                            )}
                          </div>
                        </div>
                      )}

                      {showEmojiPicker && (
                        <div className="mt-4 rounded-2xl border border-future-200 bg-future-50 p-4">
                          <p className="text-sm font-semibold text-future-900 mb-2">Ajouter une humeur</p>
                          <div className="flex flex-wrap gap-2">
                            {['😊','😂','😍','😎','😢','🤔','🎉','🚀','❤️','🔥'].map((emoji) => (
                              <button
                                key={emoji}
                                type="button"
                                onClick={() => handleEmojiSelect(emoji)}
                                className="rounded-2xl border border-future-200 bg-white px-3 py-2 text-lg hover:bg-future-100 transition"
                              >
                                {emoji}
                              </button>
                            ))}
                          </div>
                        </div>
                      )}

                      {showLocationPicker && (
                        <div className="mt-4 rounded-2xl border border-future-200 bg-future-50 p-4">
                          <p className="text-sm font-semibold text-future-900 mb-2">Ajouter un lieu</p>
                          <input
                            type="text"
                            value={selectedLocation}
                            onChange={(e) => setSelectedLocation(e.target.value)}
                            placeholder="Entrez un lieu (ex : Paris, Maison, Bureau)"
                            className="w-full rounded-2xl border border-future-300 bg-white px-4 py-3 text-sm text-future-900 outline-none focus:border-blue-500 transition"
                          />
                        </div>
                      )}

                      {showGifPicker && (
                        <div className="mt-4 rounded-2xl border border-future-200 bg-future-50 p-4">
                          <p className="text-sm font-semibold text-future-900 mb-2">Choisir un GIF</p>
                          <div className="grid grid-cols-3 gap-2">
                            {['https://media.giphy.com/media/3o72FkiKGMGauydfyg/giphy.gif', 'https://media.giphy.com/media/l0MYB8Ory7Hqefo9a/giphy.gif', 'https://media.giphy.com/media/xT0GqssRweIhlz209i/giphy.gif'].map((gifUrl) => (
                              <button
                                key={gifUrl}
                                type="button"
                                onClick={() => handleGifSelect(gifUrl)}
                                className="overflow-hidden rounded-2xl border border-future-200 bg-white p-1 hover:border-blue-500 transition"
                              >
                                <img src={gifUrl} alt="GIF" className="h-24 w-full object-cover" />
                              </button>
                            ))}
                          </div>
                        </div>
                      )}

                      {showMoreOptions && (
                        <div className="mt-4 rounded-2xl border border-future-200 bg-future-50 p-4">
                          <p className="text-sm font-semibold text-future-900 mb-2">Plus d’options</p>
                          <div className="grid grid-cols-2 gap-2">
                            {['Programmer', 'Sondage', 'Événement', 'Voir plus'].map((option) => (
                              <button
                                key={option}
                                type="button"
                                onClick={() => handleMoreOptions(option)}
                                className="rounded-2xl border border-future-200 bg-white px-4 py-3 text-sm hover:bg-future-100 transition"
                              >
                                {option}
                              </button>
                            ))}
                          </div>
                        </div>
                      )}

                      <div className="grid gap-4">
                        <div className="rounded-2xl border border-future-200 bg-future-50 p-4">
                          <p className="text-sm font-semibold text-future-900 mb-2">Catégories commerciales</p>
                          <p className="text-sm text-future-600 mb-3">Choisissez les secteurs commerciaux qui correspondent à votre annonce.</p>
                          <div className="flex flex-wrap gap-2">
                            {availableBusinessCategories.map((category) => (
                              <button
                                key={category.value}
                                type="button"
                                onClick={() => handleToggleBusinessCategory(category.value)}
                                className={`rounded-full border px-4 py-2 text-sm transition ${selectedBusinessCategories.has(category.value)
                                  ? 'bg-fopcam-700 text-white border-fopcam-700'
                                  : 'bg-white text-future-700 border-future-200 hover:bg-future-100'} `}
                              >
                                {category.label}
                              </button>
                            ))}
                          </div>
                          <div className="mt-4">
                            <label className="block text-sm font-medium text-future-700 mb-2">Ajouter une catégorie libre</label>
                            <div className="flex gap-2">
                              <input
                                type="text"
                                value={customBusinessCategory}
                                onChange={(e) => setCustomBusinessCategory(e.target.value)}
                                onKeyDown={(e) => {
                                  if (e.key === 'Enter') {
                                    e.preventDefault()
                                    addCustomBusinessCategory()
                                  }
                                }}
                                placeholder="Ex. Épicerie locale, Distribution alimentaire"
                                className="w-full rounded-2xl border border-future-200 bg-white px-4 py-3 text-sm text-future-900 outline-none focus:border-fopcam-400"
                              />
                              <button
                                type="button"
                                onClick={addCustomBusinessCategory}
                                className="rounded-2xl bg-fopcam-700 px-4 py-3 text-sm font-semibold text-white hover:bg-fopcam-800 transition"
                              >
                                Ajouter
                              </button>
                            </div>
                          </div>
                          {customBusinessCategories.length > 0 && (
                            <div className="mt-3 flex flex-wrap gap-2">
                              {customBusinessCategories.map((category) => (
                                <span key={category} className="inline-flex items-center rounded-full border border-fopcam-400 bg-fopcam-50 px-3 py-1 text-sm text-future-900">
                                  {category}
                                  <button
                                    type="button"
                                    onClick={() => removeCustomBusinessCategory(category)}
                                    className="ml-2 text-future-500 hover:text-future-700"
                                  >
                                    ×
                                  </button>
                                </span>
                              ))}
                            </div>
                          )}
                        </div>

                        <div className="rounded-2xl border border-future-200 bg-white p-4">
                          <p className="text-sm font-semibold text-future-900 mb-2">Catégories de services</p>
                          <p className="text-sm text-future-600 mb-3">Sélectionnez une ou plusieurs catégories de service pour votre publication.</p>
                          <div className="flex flex-wrap gap-2">
                            {availableServiceCategories.map((category) => (
                              <button
                                key={category.value}
                                type="button"
                                onClick={() => handleTogglePostCategory(category.value)}
                                className={`rounded-full border px-4 py-2 text-sm transition ${selectedPostCategories.has(category.value)
                                  ? 'bg-fopcam-700 text-white border-fopcam-700'
                                  : 'bg-white text-future-700 border-future-200 hover:bg-future-100'} `}
                              >
                                {category.label}
                              </button>
                            ))}
                          </div>
                          <div className="mt-4">
                            <label className="block text-sm font-medium text-future-700 mb-2">Ajouter une catégorie libre</label>
                            <div className="flex gap-2">
                              <input
                                type="text"
                                value={customServiceCategory}
                                onChange={(e) => setCustomServiceCategory(e.target.value)}
                                onKeyDown={(e) => {
                                  if (e.key === 'Enter') {
                                    e.preventDefault()
                                    addCustomServiceCategory()
                                  }
                                }}
                                placeholder="Ex. Coaching personnel, Service traiteur"
                                className="w-full rounded-2xl border border-future-200 bg-white px-4 py-3 text-sm text-future-900 outline-none focus:border-fopcam-400"
                              />
                              <button
                                type="button"
                                onClick={addCustomServiceCategory}
                                className="rounded-2xl bg-fopcam-700 px-4 py-3 text-sm font-semibold text-white hover:bg-fopcam-800 transition"
                              >
                                Ajouter
                              </button>
                            </div>
                          </div>
                          {customServiceCategories.length > 0 && (
                            <div className="mt-3 flex flex-wrap gap-2">
                              {customServiceCategories.map((category) => (
                                <span key={category} className="inline-flex items-center rounded-full border border-fopcam-400 bg-fopcam-50 px-3 py-1 text-sm text-future-900">
                                  {category}
                                  <button
                                    type="button"
                                    onClick={() => removeCustomServiceCategory(category)}
                                    className="ml-2 text-future-500 hover:text-future-700"
                                  >
                                    ×
                                  </button>
                                </span>
                              ))}
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Footer - Publish Button */}
                  <div className="border-t border-future-200 p-6">
                    <button
                      type="button"
                      onClick={handleCreatePost}
                      disabled={
                        selectedMediaType === 'text'
                          ? !postContent.trim() && !selectedBgColor
                          : mediaFiles.length === 0
                      }
                      className={`w-full py-3 font-semibold rounded-lg transition ${
                        selectedMediaType === 'text'
                          ? postContent.trim() || selectedBgColor
                            ? 'bg-fopcam-700 text-white hover:bg-fopcam-800'
                            : 'bg-future-200 text-future-500 cursor-not-allowed'
                          : mediaFiles.length > 0
                            ? 'bg-fopcam-700 text-white hover:bg-fopcam-800'
                            : 'bg-future-200 text-future-500 cursor-not-allowed'
                      }`}
                    >
                      Publier
                    </button>
                  </div>
                </div>
              </div>
            )}

            {posts.length > 0 ? (
              <div className="grid gap-6 lg:grid-cols-2 xl:grid-cols-3">
                {posts.map((post) => (
                  <div key={post.id} className="rounded-3xl border border-future-200 bg-white p-5 shadow-sm hover:shadow-md transition">
                    <div className="flex items-start gap-4">
                      <button
                        type="button"
                        onClick={() => openViewer([{ type: 'image', src: buildMediaUrl(post.author?.profile_image || post.author?.profile?.profile_image) || '/default-avatar.png', alt: post.author?.username || 'Photo de profil' }], 0)}
                        className="shrink-0 rounded-full overflow-hidden border border-future-200 hover:border-fopcam-500 transition"
                        title="Voir la photo de profil"
                      >
                        <img
                          src={buildMediaUrl(post.author?.profile_image || post.author?.profile?.profile_image) || '/default-avatar.png'}
                          alt={post.author?.username || 'Auteur'}
                          loading="lazy"
                          decoding="async"
                          className="w-12 h-12 rounded-full object-cover"
                        />
                      </button>
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <p className="font-semibold text-future-900">{post.author?.first_name || post.author?.username || 'Utilisateur'}</p>
                          {post.author?.is_producer && (
                            <span className="inline-flex items-center rounded-full bg-fopcam-100 px-2 py-0.5 text-xs font-semibold text-fopcam-700">
                              ✓ Vendeur
                            </span>
                          )}
                        </div>
                        <p className="text-sm text-future-500">{post.created_at ? new Date(post.created_at).toLocaleDateString('fr-FR') : 'Aujourd’hui'}</p>
                      </div>
                      {/* Actions visibles si c'est l'auteur du post */}
                      {currentUserId === post.author?.id && (
                        <div className="flex items-center gap-2">
                          <button
                            onClick={() => handleEditPost(post)}
                            className="rounded-full border border-future-200 bg-future-50 px-3 py-2 text-sm font-medium text-future-700 hover:bg-future-100 transition"
                          >
                            Modifier
                          </button>
                          <button
                            onClick={() => handleDeletePost(post.id)}
                            className="rounded-full border border-red-200 bg-red-50 px-3 py-2 text-sm font-medium text-red-600 hover:bg-red-100 transition"
                          >
                            Supprimer
                          </button>
                          <div className="relative">
                            <button
                              onClick={() => setPostMenuOpen(postMenuOpen === post.id ? null : post.id)}
                              className="p-2 text-future-500 hover:bg-future-100 rounded-full transition"
                              aria-label="Plus d’options"
                            >
                              ⋯
                            </button>
                            {postMenuOpen === post.id && (
                              <div className="absolute right-0 mt-2 w-40 rounded-2xl bg-white border border-future-200 shadow-lg z-50">
                                <button
                                  onClick={() => handleEditPost(post)}
                                  className="w-full text-left px-4 py-2 text-sm text-future-700 hover:bg-future-50 rounded-t-2xl transition"
                                >
                                  ✏️ Modifier
                                </button>
                                <button
                                  onClick={() => handleDeletePost(post.id)}
                                  className="w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-red-50 rounded-b-2xl transition"
                                >
                                  🗑️ Supprimer
                                </button>
                              </div>
                            )}
                          </div>
                        </div>
                      )}
                    </div>

                    {(post.hashtags && post.hashtags.length > 0) && (
                      <div className="mt-4 flex flex-wrap gap-2">
                        {(Array.isArray(post.hashtags) ? post.hashtags : [post.hashtags]).map((tag) => (
                          <span key={tag} className="rounded-full bg-future-100 px-3 py-1 text-sm text-fopcam-700 border border-future-200">
                            #{tag}
                          </span>
                        ))}
                      </div>
                    )}
                    {editingPostId === post.id && isEditingPost ? (
                      <div className="mt-4 p-4 bg-future-50 rounded-2xl border border-future-200">
                        <textarea
                          value={editPostContent}
                          onChange={(e) => setEditPostContent(e.target.value)}
                          placeholder="Modifier votre publication..."
                          rows={4}
                          className="w-full rounded-2xl border border-future-200 bg-white px-4 py-3 text-future-900 outline-none placeholder:text-future-400"
                        />
                        <div className="mt-4">
                          <label className="block text-sm font-medium text-future-700">Remplacer le média</label>
                          <input
                            type="file"
                            multiple
                            accept="image/*,video/*"
                            onChange={handleEditMediaFileChange}
                            className="mt-2 block w-full text-sm text-future-700 file:mr-4 file:rounded-full file:border-0 file:bg-future-100 file:px-4 file:py-2 file:text-sm file:font-semibold file:text-future-700 hover:file:bg-future-200"
                          />
                        </div>
                        {(editMediaPreview || post.video || post.image || (post.images && post.images.length > 0)) && (
                          <div className="mt-4 rounded-2xl border border-future-200 bg-white p-3">
                            <p className="text-sm font-medium text-future-700">Aperçu du média</p>
                            {editMediaPreview ? (
                              editMediaFile?.type.startsWith('video/') ? (
                                <video controls src={editMediaPreview} className="mt-3 w-full rounded-2xl max-h-[360px]" />
                              ) : (
                                <img src={editMediaPreview} alt="Aperçu média" className="mt-3 w-full rounded-2xl object-cover max-h-[360px]" />
                              )
                            ) : post.video ? (
                              <video controls src={buildMediaUrl(post.video)} className="mt-3 w-full rounded-2xl max-h-[360px]" />
                            ) : post.image ? (
                              <img src={buildMediaUrl(post.image)} alt="Média actuel" className="mt-3 w-full rounded-2xl object-cover max-h-[360px]" />
                            ) : post.images && post.images.length > 0 ? (
                              <img src={buildMediaUrl(post.images[0])} alt="Média actuel" className="mt-3 w-full rounded-2xl object-cover max-h-[360px]" />
                            ) : null}
                          </div>
                        )}
                        <div className="mt-3 flex gap-2">
                          <button
                            onClick={handleSaveEditPost}
                            className="px-4 py-2 bg-fopcam-700 text-white rounded-full text-sm font-semibold hover:bg-fopcam-800 transition"
                          >
                            Enregistrer
                          </button>
                          <button
                            onClick={() => {
                              setEditingPostId(null)
                              setIsEditingPost(false)
                            }}
                            className="px-4 py-2 bg-future-200 text-future-700 rounded-full text-sm font-semibold hover:bg-future-300 transition"
                          >
                            Annuler
                          </button>
                        </div>
                      </div>
                    ) : (
                      <p className="mt-4 text-future-800 leading-6">{post.content}</p>
                    )}

                    {post.video ? (
                      <video
                        src={buildMediaUrl(post.video)}
                        controls
                        onClick={() => {
                          const mediaList = buildPostMediaList(post)
                          const videoIndex = mediaList.findIndex(item => item.type === 'video' && item.src === buildMediaUrl(post.video))
                          openViewer(mediaList, videoIndex >= 0 ? videoIndex : 0)
                        }}
                        className="mt-4 w-full rounded-2xl max-h-[600px] cursor-pointer"
                      />
                    ) : post.image ? (
                      <img
                        src={buildMediaUrl(post.image)}
                        alt="Post content"
                        onClick={() => {
                          const mediaList = buildPostMediaList(post)
                          const imageIndex = mediaList.findIndex(item => item.type === 'image' && item.src === buildMediaUrl(post.image))
                          openViewer(mediaList, imageIndex >= 0 ? imageIndex : 0)
                        }}
                        className="mt-4 w-full rounded-2xl object-cover max-h-[600px] cursor-pointer"
                      />
                    ) : post.images && post.images.length > 1 ? (
                      <div className="relative mt-4">
                        <img
                          src={buildMediaUrl(post.images[carouselIndices[post.id] ?? 0])}
                          alt={`Image ${Number(carouselIndices[post.id] ?? 0) + 1}`}
                          onClick={() => {
                            const mediaList = buildPostMediaList(post)
                            openViewer(mediaList, carouselIndices[post.id] ?? 0)
                          }}
                          className="w-full rounded-2xl object-cover max-h-[600px] cursor-pointer"
                        />
                        <button
                          type="button"
                          onClick={() => handleCarouselNavigation(post.id, 'prev')}
                          className="absolute left-3 top-1/2 -translate-y-1/2 rounded-full bg-white/90 p-2 text-future-700 shadow-lg hover:bg-white transition"
                          aria-label="Image précédente"
                        >
                          ‹
                        </button>
                        <button
                          type="button"
                          onClick={() => handleCarouselNavigation(post.id, 'next')}
                          className="absolute right-3 top-1/2 -translate-y-1/2 rounded-full bg-white/90 p-2 text-future-700 shadow-lg hover:bg-white transition"
                          aria-label="Image suivante"
                        >
                          ›
                        </button>
                        <div className="mt-3 flex items-center justify-center gap-2">
                          {post.images.map((_, idx) => (
                            <button
                              key={idx}
                              type="button"
                              onClick={() => setCarouselIndices(prev => ({ ...prev, [post.id]: idx }))}
                              className={`h-2 w-2 rounded-full ${idx === (carouselIndices[post.id] ?? 0) ? 'bg-fopcam-700' : 'bg-future-300'}`}
                              aria-label={`Aller à l'image ${idx + 1}`}
                            />
                          ))}
                        </div>
                      </div>
                    ) : post.images && post.images.length > 0 ? (
                      <img
                        src={buildMediaUrl(post.images[0])}
                        alt="Post content"
                        onClick={() => openViewer(buildPostMediaList(post), 0)}
                        className="mt-4 w-full rounded-2xl object-cover max-h-[600px] cursor-pointer"
                      />
                    ) : null}
                    <div className="mt-6 grid gap-3 border-t border-future-100 pt-4 sm:grid-cols-2 lg:grid-cols-4">
                      <button
                        onClick={() => handleLikePost(post.id)}
                        className="flex items-center gap-2 text-sm text-future-600 hover:text-fopcam-700 transition"
                      >
                        {likedPosts.has(post.id) ? (
                          <HeartIconSolid className="w-5 h-5 text-red-500" />
                        ) : (
                          <HeartIcon className="w-5 h-5" />
                        )}
                        <span>{post.likes_count || 0} J’aime</span>
                      </button>
                      <button
                        onClick={() => handleFeedAction(post.id, 'commenter')}
                        className="flex items-center gap-2 text-sm text-future-600 hover:text-fopcam-700 transition"
                      >
                        <ChatBubbleLeftIcon className="w-5 h-5" />
                        <span>{post.comments_count || 0} Commentaires</span>
                      </button>
                      <button
                        onClick={() => handleFeedAction(post.id, 'partager')}
                        className="flex items-center gap-2 text-sm text-future-600 hover:text-fopcam-700 transition"
                      >
                        <ShareIcon className="w-5 h-5" />
                        <span>{post.shares_count || post.share_count || 0} Partages</span>
                      </button>
                      <button
                        onClick={() => handleFeedAction(post.id, 'republier')}
                        className="flex items-center gap-2 text-sm text-future-600 hover:text-fopcam-700 transition"
                      >
                        <ArrowPathRoundedSquareIcon className="w-5 h-5" />
                        <span>{post.reposts_count || 0} Republier</span>
                      </button>
                    </div>

                    {openComments.has(post.id) && (
                      <div className="mt-4 rounded-3xl border border-future-100 bg-future-50 p-4">
                        <div className="flex flex-col gap-3 sm:flex-row sm:items-start">
                          <textarea
                            value={commentInputs[post.id] || ''}
                            onChange={(e) => setCommentInputs(prev => ({ ...prev, [post.id]: e.target.value }))}
                            placeholder="Écrire un commentaire..."
                            rows={3}
                            className="w-full rounded-3xl border border-future-200 bg-white px-4 py-3 text-future-900 outline-none placeholder:text-future-400"
                          />
                          <button
                            type="button"
                            onClick={() => submitComment(post.id)}
                            className="shrink-0 rounded-full bg-fopcam-800 px-5 py-3 text-sm font-semibold text-white hover:bg-fopcam-900 transition"
                          >
                            Envoyer
                          </button>
                        </div>

                        <div className="mt-4 space-y-3">
                          {loadingComments[post.id] ? (
                            <p className="text-sm text-future-500">Chargement des commentaires...</p>
                          ) : (postComments[post.id] || []).length > 0 ? (
                            (postComments[post.id] || []).map(comment => (
                              <div key={comment.id} className="rounded-2xl bg-white p-3 border border-future-200">
                                <p className="text-sm font-semibold text-future-900">{comment.author?.first_name || comment.author?.username || 'Utilisateur'}</p>
                                <p className="mt-1 text-sm text-future-700">{comment.content}</p>
                              </div>
                            ))
                          ) : (
                            <p className="text-sm text-future-500">Aucun commentaire pour le moment.</p>
                          )}
                        </div>
                      </div>
                    )}

                    {activeSharePostId === post.id && (
                      <div className="mt-4 grid grid-cols-2 gap-3 rounded-3xl border border-future-100 bg-future-50 p-4">
                        <button
                          type="button"
                          onClick={() => shareToNetwork(post, 'whatsapp')}
                          className="rounded-2xl border border-future-200 bg-white px-4 py-3 text-sm font-semibold text-future-700 hover:bg-future-100 transition"
                        >WhatsApp</button>
                        <button
                          type="button"
                          onClick={() => shareToNetwork(post, 'linkedin')}
                          className="rounded-2xl border border-future-200 bg-white px-4 py-3 text-sm font-semibold text-future-700 hover:bg-future-100 transition"
                        >LinkedIn</button>
                        <button
                          type="button"
                          onClick={() => shareToNetwork(post, 'facebook')}
                          className="rounded-2xl border border-future-200 bg-white px-4 py-3 text-sm font-semibold text-future-700 hover:bg-future-100 transition"
                        >Facebook</button>
                        <button
                          type="button"
                          onClick={() => shareToNetwork(post, 'instagram')}
                          className="rounded-2xl border border-future-200 bg-white px-4 py-3 text-sm font-semibold text-future-700 hover:bg-future-100 transition"
                        >Instagram</button>
                      </div>
                    )}

                    {activeRepostPostId === post.id && (
                      <div className="mt-4 rounded-3xl border border-future-100 bg-future-50 p-4">
                        <textarea
                          value={repostCommentInputs[post.id] || ''}
                          onChange={(e) => setRepostCommentInputs(prev => ({ ...prev, [post.id]: e.target.value }))}
                          placeholder="Ajouter un commentaire à la republication (optionnel)"
                          rows={3}
                          className="w-full rounded-3xl border border-future-200 bg-white px-4 py-3 text-future-900 outline-none placeholder:text-future-400"
                        />
                        <div className="mt-3 flex flex-wrap gap-3">
                          <button
                            type="button"
                            onClick={() => handleRepost(post.id)}
                            className="rounded-full bg-fopcam-800 px-4 py-2 text-sm font-semibold text-white hover:bg-fopcam-900 transition"
                          >Publier republication</button>
                          <button
                            type="button"
                            onClick={() => setActiveRepostPostId(null)}
                            className="rounded-full border border-future-200 bg-white px-4 py-2 text-sm font-semibold text-future-700 hover:bg-future-100 transition"
                          >Annuler</button>
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            ) : (
              <div className="rounded-3xl border border-dashed border-future-300 bg-white p-12 text-center">
                <p className="text-future-600">Aucun post pour le moment. Soyez le premier à partager quelque chose !</p>
              </div>
            )}

            <div ref={postsObserverRef} className="h-6" />
            {isLoadingPosts && (
              <div className="mt-8 rounded-3xl border border-future-200 bg-white p-6 text-center text-future-600 shadow-sm">
                Chargement des publications…
              </div>
            )}
            {!hasMorePosts && posts.length > 0 && (
              <div className="mt-8 rounded-3xl border border-future-200 bg-white p-6 text-center text-future-600 shadow-sm">
                Vous avez atteint la fin du fil d’actualité.
              </div>
            )}
          </div>
        </section>

      </main>

      {/* FOOTER */}
      <footer className="border-t border-future-800 bg-future-950 py-16">
        <div className="mx-auto grid max-w-7xl gap-10 px-4 sm:px-6 lg:grid-cols-3">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.3em] text-future-200">FopCam</p>
            <p className="mt-4 max-w-sm text-sm leading-7 text-future-400">Un réseau social et marketplace pour connecter vendeurs et consommateurs en circuit court.</p>
          </div>
          <div>
            <h3 className="text-sm font-semibold uppercase tracking-[0.3em] text-future-200">Navigation</h3>
            <ul className="mt-4 space-y-3 text-sm text-future-400">
              <li><Link href="/products" className="hover:text-future-100 transition">Produits</Link></li>
              <li><Link href="/messages" className="hover:text-future-100 transition">Fil d'actualité</Link></li>
              <li><Link href="/profile" className="hover:text-future-100 transition">Vendeurs</Link></li>
            </ul>
          </div>
          <div>
            <h3 className="text-sm font-semibold uppercase tracking-[0.3em] text-future-200">Contact</h3>
            <ul className="mt-4 space-y-3 text-sm text-future-400">
              <li>contact@fopcam.com</li>
              <li>+221 33 123 45 67</li>
              <li>Dakar, Sénégal</li>
            </ul>
          </div>
        </div>
        <div className="mx-auto mt-12 max-w-7xl px-4 text-center text-sm text-future-500 sm:px-6">
          &copy; 2026 FopCam. Tous les droits réservés. Un réseau social pour le commerce équitable.
        </div>
      </footer>

      <CreateStoryModal
        isOpen={showStoryModal}
        onClose={() => setShowStoryModal(false)}
        onCreate={handleStoryCreate}
      />

      <PostViewer
        isOpen={viewerOpen}
        onClose={closeViewer}
        mediaList={viewerMediaList}
        currentIndex={viewerIndex}
        onIndexChange={setViewerIndex}
      />
    </div>
  )
}

export async function getServerSideProps({ locale }) {
  try {
    const baseURL = process.env.NEXT_PUBLIC_API_URL?.trim().replace(/\/$/, '') || 'http://127.0.0.1:8000'

    const fetchJson = async (url) => {
      try {
        const res = await fetch(url)
        if (!res.ok) {
          console.warn(`getServerSideProps: failed fetch ${url} (${res.status})`)
          return { ok: false, data: null }
        }

        const data = await res.json()
        return { ok: true, data }
      } catch (error) {
        console.warn(`getServerSideProps: exception fetching ${url}:`, error)
        return { ok: false, data: null }
      }
    }

    const [
      productsRes,
      categoriesRes,
      producersRes,
      postsRes,
      groupsRes,
      storiesRes
    ] = await Promise.all([
      fetchJson(`${baseURL}/api/products/`),
      fetchJson(`${baseURL}/api/categories/`),
      fetchJson(`${baseURL}/api/profiles/?role=producer`),
      fetchJson(`${baseURL}/api/posts/?page=1&page_size=${POSTS_PAGE_SIZE}`),
      fetchJson(`${baseURL}/api/groups/?page_size=50`),
      fetchJson(`${baseURL}/api/stories/`)
    ])

    const productsData = productsRes.ok ? productsRes.data : null
    const categoriesData = categoriesRes.ok ? categoriesRes.data : null
    const producersData = producersRes.ok ? producersRes.data : null
    const postsData = postsRes.ok ? postsRes.data : null
    const groupsData = groupsRes.ok ? groupsRes.data : null
    const storiesData = storiesRes.ok ? storiesRes.data : null

    const products = Array.isArray(productsData)
      ? productsData.slice(0, 12)
      : productsData?.results
        ? productsData.results.slice(0, 12)
        : []

    const categories = Array.isArray(categoriesData)
      ? categoriesData
      : categoriesData?.results
        ? categoriesData.results
        : []

    const producers = Array.isArray(producersData)
      ? producersData.slice(0, 8)
      : producersData?.results
        ? producersData.results.slice(0, 8)
        : []

    const posts = Array.isArray(postsData)
      ? postsData.slice(0, 5)
      : postsData?.results
        ? postsData.results.slice(0, 5)
        : []

    const groups = Array.isArray(groupsData)
      ? groupsData.slice(0, 10)
      : groupsData?.results
        ? groupsData.results.slice(0, 10)
        : []

    const stories = Array.isArray(storiesData)
      ? storiesData
      : storiesData?.results
        ? storiesData.results
        : []

    return {
      props: {
        initialProducts: products.length > 0 ? products : FALLBACK_PRODUCTS,
        initialCategories: categories.length > 0 ? categories : FALLBACK_CATEGORIES,
        initialProducers: producers.length > 0 ? producers : FALLBACK_PRODUCERS,
        initialPosts: posts.length > 0 ? posts : FALLBACK_POSTS,
        initialGroups: groups.length > 0 ? groups : FALLBACK_GROUPS,
        initialStories: stories.length > 0 ? stories : FALLBACK_STORIES,
        ...(await serverSideTranslations(locale, ['common']))
      }
    }
  } catch (err) {
    console.error('Erreur getServerSideProps:', err)
    return {
      props: {
        initialProducts: [],
        initialCategories: [],
        initialProducers: [],
        initialPosts: [],
        initialGroups: [],
        initialStories: [],
        ...(await serverSideTranslations(locale, ['common']))
      }
    }
  }
}
