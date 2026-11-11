import React, { useState, useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/router'
import {
  ArrowLeftIcon,
  UsersIcon,
  MapPinIcon,
  CalendarIcon,
  PlusIcon,
  HeartIcon,
  ChatBubbleLeftIcon,
  ShareIcon,
  EllipsisVerticalIcon,
  PhotoIcon,
  VideoCameraIcon,
  LinkIcon,
  Cog6ToothIcon,
  CheckIcon,
  XMarkIcon,
  ArrowUpIcon,
  ArrowDownIcon,
  TrashIcon,
} from '@heroicons/react/24/outline'
import { HeartIcon as HeartIconSolid } from '@heroicons/react/24/solid'
import { fetchWithAuth } from '../../utils/tokenManager'

const GroupDetailPage = () => {
  const [group, setGroup] = useState(null)
  const [posts, setPosts] = useState([])
  const [members, setMembers] = useState([])
  const [pendingMembers, setPendingMembers] = useState([])
  const [loading, setLoading] = useState(true)
  const [showCreatePost, setShowCreatePost] = useState(false)
  const [showAdminPanel, setShowAdminPanel] = useState(false)
  const [showEditForm, setShowEditForm] = useState(false)
  const [inviteUsername, setInviteUsername] = useState('')
  const [editForm, setEditForm] = useState({
    name: '',
    description: '',
    rules: '',
    group_type: 'public'
  })
  const [userRole, setUserRole] = useState(null)
  const [actionLoading, setActionLoading] = useState({})
  const [newPost, setNewPost] = useState({
    title: '',
    content: '',
    post_type: 'text',
    image: null,
    video: null,
    images: [],
    videos: [],
    link_url: '',
    link_title: '',
    link_description: '',
    event_date: '',
    event_location: ''
  })
  const [selectedAvatarFile, setSelectedAvatarFile] = useState(null)
  const [selectedCoverFile, setSelectedCoverFile] = useState(null)
  const [avatarPreview, setAvatarPreview] = useState(null)
  const [coverPreview, setCoverPreview] = useState(null)
  const router = useRouter()
  const { id } = router.query
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  const buildMediaUrl = (path) => {
    if (!path) return null
    return /^https?:\/\//.test(path) ? path : `${apiUrl}/media/${path}`
  }

  useEffect(() => {
    if (id) {
      loadGroup()
      loadPosts()
    }
  }, [id])

  const loadGroup = async () => {
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/${id}/`)
      if (response.ok) {
        const data = await response.json()
        setGroup(data)
        setEditForm({
          name: data.name || '',
          description: data.description || '',
          rules: data.rules || '',
          group_type: data.group_type || 'public'
        })
        setAvatarPreview(buildMediaUrl(data.avatar))
        setCoverPreview(buildMediaUrl(data.cover_image))
        setSelectedAvatarFile(null)
        setSelectedCoverFile(null)
        
        if (data.member_role) {
          setUserRole(data.member_role)
        }

        if (data.is_member) {
          loadMembers()
        }
        
        if (data.member_role && ['admin', 'moderator'].includes(data.member_role)) {
          loadPendingMembers()
        }
      }
    } catch (error) {
      console.error('Erreur lors du chargement du groupe:', error)
    }
  }

  const loadMembers = async () => {
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/${id}/members/`)
      if (response.ok) {
        const data = await response.json()
        setMembers(data)
      }
    } catch (error) {
      console.error('Erreur lors du chargement des membres:', error)
    }
  }

  const loadPendingMembers = async () => {
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/${id}/pending_members/`)
      if (response.ok) {
        const data = await response.json()
        setPendingMembers(data)
      }
    } catch (error) {
      console.error('Erreur lors du chargement des demandes en attente:', error)
    }
  }

  const loadPosts = async () => {
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/group-posts/?group=${id}`)
      if (response.ok) {
        const data = await response.json()
        setPosts(data)
      }
    } catch (error) {
      console.error('Erreur lors du chargement des posts:', error)
    } finally {
      setLoading(false)
    }
  }

  const joinGroup = async () => {
    const token = localStorage.getItem('access_token') || localStorage.getItem('access')
    if (!token) {
      router.push('/login')
      return
    }

    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/${id}/join/`, {
        method: 'POST'
      })

      if (response.ok) {
        loadGroup()
      }
    } catch (error) {
      console.error('Erreur lors de l\'adhésion au groupe:', error)
      if (error.message.includes('Session expired')) {
        router.push('/login')
      }
    }
  }

  const leaveGroup = async () => {
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/${id}/leave/`, {
        method: 'POST'
      })

      if (response.ok) {
        loadGroup()
      }
    } catch (error) {
      console.error('Erreur lors du départ du groupe:', error)
    }
  }

  const approveMember = async (memberId) => {
    setActionLoading({ ...actionLoading, [memberId]: true })
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/${id}/approve_member/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ member_id: memberId })
      })

      if (response.ok) {
        loadPendingMembers()
        loadMembers()
      }
    } catch (error) {
      console.error('Erreur lors de l\'approbation:', error)
    } finally {
      setActionLoading({ ...actionLoading, [memberId]: false })
    }
  }

  const rejectMember = async (memberId) => {
    setActionLoading({ ...actionLoading, [memberId]: true })
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/${id}/reject_member/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ member_id: memberId })
      })

      if (response.ok) {
        loadPendingMembers()
      }
    } catch (error) {
      console.error('Erreur lors du rejet:', error)
    } finally {
      setActionLoading({ ...actionLoading, [memberId]: false })
    }
  }

  const promoteUser = async (memberId) => {
    setActionLoading({ ...actionLoading, [`promote-${memberId}`]: true })
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/${id}/promote/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ member_id: memberId })
      })

      if (response.ok) {
        loadMembers()
      } else {
        const error = await response.json()
        alert(error.detail || 'Erreur lors de la promotion')
      }
    } catch (error) {
      console.error('Erreur lors de la promotion:', error)
    } finally {
      setActionLoading({ ...actionLoading, [`promote-${memberId}`]: false })
    }
  }

  const demoteUser = async (memberId) => {
    setActionLoading({ ...actionLoading, [`demote-${memberId}`]: true })
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/${id}/demote/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ member_id: memberId })
      })

      if (response.ok) {
        loadMembers()
      } else {
        const error = await response.json()
        alert(error.detail || 'Erreur lors de la rétrogradation')
      }
    } catch (error) {
      console.error('Erreur lors de la rétrogradation:', error)
    } finally {
      setActionLoading({ ...actionLoading, [`demote-${memberId}`]: false })
    }
  }

  const removeUser = async (memberId, username) => {
    if (!confirm(`Êtes-vous sûr de vouloir retirer ${username} du groupe ?`)) {
      return
    }

    setActionLoading({ ...actionLoading, [`remove-${memberId}`]: true })
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/${id}/remove_member/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ member_id: memberId })
      })

      if (response.ok) {
        loadMembers()
      } else {
        const error = await response.json()
        alert(error.detail || 'Erreur lors du retrait')
      }
    } catch (error) {
      console.error('Erreur lors du retrait:', error)
    } finally {
      setActionLoading({ ...actionLoading, [`remove-${memberId}`]: false })
    }
  }

  const saveGroupChanges = async () => {
    try {
      const formData = new FormData()
      formData.append('name', editForm.name)
      formData.append('description', editForm.description)
      formData.append('rules', editForm.rules)
      formData.append('group_type', editForm.group_type)
      if (selectedCoverFile) {
        formData.append('cover_image', selectedCoverFile)
      }
      if (selectedAvatarFile) {
        formData.append('avatar', selectedAvatarFile)
      }

      const response = await fetchWithAuth(`${apiUrl}/api/groups/${id}/`, {
        method: 'PATCH',
        body: formData
      })

      if (response.ok) {
        loadGroup()
        setShowEditForm(false)
      } else {
        const error = await response.json()
        alert(error.detail || 'Impossible de sauvegarder les modifications')
      }
    } catch (error) {
      console.error('Erreur lors de la sauvegarde du groupe:', error)
    }
  }

  const archiveGroup = async () => {
    if (!confirm('Voulez-vous vraiment archiver ce groupe ?')) {
      return
    }

    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/${id}/archive/`, {
        method: 'POST'
      })

      if (response.ok) {
        router.push('/groups')
      } else {
        const error = await response.json()
        alert(error.detail || 'Impossible d\'archiver le groupe')
      }
    } catch (error) {
      console.error('Erreur lors de l\'archivage du groupe:', error)
    }
  }

  const inviteMember = async () => {
    if (!inviteUsername.trim()) {
      alert('Veuillez saisir un nom d\'utilisateur pour inviter.')
      return
    }

    setActionLoading({ ...actionLoading, invite: true })
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/groups/${id}/invite_member/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ username: inviteUsername.trim() })
      })

      if (response.ok) {
        setInviteUsername('')
        loadMembers()
        loadGroup()
      } else {
        const error = await response.json()
        alert(error.detail || 'Impossible d\'inviter cet utilisateur')
      }
    } catch (error) {
      console.error('Erreur lors de l\'invitation:', error)
    } finally {
      setActionLoading({ ...actionLoading, invite: false })
    }
  }

  const createPost = async (e) => {
    e.preventDefault()
    const token = localStorage.getItem('access_token') || localStorage.getItem('access')
    if (!token) {
      alert('Vous devez être connecté pour publier.')
      return
    }

    if (newPost.post_type === 'text' && !newPost.content.trim()) {
      alert('Le contenu ne peut pas être vide.')
      return
    }

    if (newPost.post_type === 'image' && (!newPost.images || newPost.images.length === 0)) {
      alert('Veuillez sélectionner au moins une image.')
      return
    }

    if (newPost.post_type === 'video' && (!newPost.videos || newPost.videos.length === 0)) {
      alert('Veuillez sélectionner au moins une vidéo.')
      return
    }

    try {
      const formData = new FormData()
      formData.append('group', id)
      formData.append('content', newPost.content)
      formData.append('post_type', newPost.post_type)
      formData.append('privacy', 'public')

      // Handle multiple images
      if (newPost.images && newPost.images.length > 0) {
        formData.append('image', newPost.images[0])
        if (newPost.images.length > 1) {
          for (let i = 1; i < newPost.images.length; i++) {
            formData.append(`image_${i}`, newPost.images[i])
          }
        }
      }

      // Handle videos (append the first video as `video`)
      if (newPost.videos && newPost.videos.length > 0) {
        formData.append('video', newPost.videos[0])
        // If in future backend supports multiple videos, we can append video_1, video_2 similarly
      }

      const response = await fetchWithAuth(`${apiUrl}/api/group-posts/`, {
        method: 'POST',
        body: formData
      })

      if (response.ok) {
        setShowCreatePost(false)
        setNewPost({
          title: '',
          content: '',
          post_type: 'text',
          image: null,
          video: null,
          images: [],
          videos: [],
          link_url: '',
          link_title: '',
          link_description: '',
          event_date: '',
          event_location: ''
        })
        loadPosts() // Recharger les posts
        return
      }

      const errorData = await response.json().catch(() => null)
      console.error('Erreur lors de la création du post:', response.status, errorData)
      alert(`Impossible de publier : ${errorData?.detail || response.status}`)
    } catch (error) {
      console.error('Erreur lors de la création du post:', error)
    }
  }

  const likePost = async (postId) => {
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/group-posts/${postId}/like/`, {
        method: 'POST'
      })

      if (response.ok) {
        loadPosts() // Recharger les posts pour mettre à jour les likes
      }
    } catch (error) {
      console.error('Erreur lors du like:', error)
    }
  }

  const getPostTypeIcon = (type) => {
    switch (type) {
      case 'image': return <PhotoIcon className="w-5 h-5" />
      case 'video': return <VideoCameraIcon className="w-5 h-5" />
      case 'link': return <LinkIcon className="w-5 h-5" />
      case 'event': return <CalendarIcon className="w-5 h-5" />
      default: return null
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-fopcam-600"></div>
      </div>
    )
  }

  if (!group) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50 flex items-center justify-center">
        <div className="text-center">
          <h2 className="text-2xl font-bold text-gray-900 mb-4">Groupe non trouvé</h2>
          <Link href="/groups" className="btn-primary">
            Retour aux groupes
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50">
      {/* Header avec image de couverture */}
      <div className="relative">
        <div className="h-64 bg-gradient-to-r from-fopcam-400 to-future-500 relative">
          {(coverPreview || group.cover_image) && (
            <img
              src={coverPreview || buildMediaUrl(group.cover_image)}
              className="w-full h-full object-cover"
            />
          )}
          <div className="absolute inset-0 bg-black bg-opacity-30"></div>
        </div>

        {/* Navigation */}
        <div className="absolute top-4 left-4 flex items-center gap-2">
          <button
            onClick={() => router.back()}
            className="bg-white/20 backdrop-blur-sm text-white p-2 rounded-full hover:bg-white/30 transition-colors"
          >
            <ArrowLeftIcon className="w-6 h-6" />
          </button>
          <Link
            href="/groups"
            className="bg-white/20 backdrop-blur-sm text-white px-3 py-2 rounded-full hover:bg-white/30 transition-colors text-sm font-medium"
          >
            Groupes
          </Link>
        </div>

        {/* Infos du groupe */}
        <div className="absolute bottom-0 left-0 right-0 p-6">
          <div className="flex items-end space-x-4">
            {(avatarPreview || group.avatar) ? (
              <img
                src={avatarPreview || buildMediaUrl(group.avatar)}
                alt={group.name}
                className="w-20 h-20 rounded-full border-4 border-white shadow-lg object-cover"
              />
            ) : (
              <div className="w-20 h-20 rounded-full bg-white/20 backdrop-blur-sm border-4 border-white shadow-lg flex items-center justify-center">
                <UsersIcon className="w-10 h-10 text-white" />
              </div>
            )}
            <div className="flex-1 text-white">
              <h1 className="text-3xl font-bold mb-2">{group.name}</h1>
              <div className="flex items-center space-x-4 text-sm">
                <span>{group.member_count} membres</span>
                {group.location && (
                  <div className="flex items-center space-x-1">
                    <MapPinIcon className="w-4 h-4" />
                    <span>{group.location}</span>
                  </div>
                )}
                <span className="px-2 py-1 bg-white/20 rounded-full text-xs">
                  {group.group_type === 'public' ? 'Public' :
                   group.group_type === 'private' ? 'Privé' : 'Secret'}
                </span>
              </div>
              {userRole && ['admin', 'moderator'].includes(userRole) && (
                <div className="mt-4 flex flex-wrap gap-2">
                  <label className="inline-flex items-center gap-2 bg-white/90 text-slate-900 px-3 py-2 rounded-full text-sm font-medium cursor-pointer shadow-sm hover:bg-white transition-colors">
                    <PhotoIcon className="w-4 h-4" />
                    Couverture
                    <input
                      type="file"
                      accept="image/*"
                      className="hidden"
                      onChange={(e) => {
                        const file = e.target.files?.[0]
                        if (file) {
                          setSelectedCoverFile(file)
                          setCoverPreview(URL.createObjectURL(file))
                        }
                      }}
                    />
                  </label>
                  <label className="inline-flex items-center gap-2 bg-white/90 text-slate-900 px-3 py-2 rounded-full text-sm font-medium cursor-pointer shadow-sm hover:bg-white transition-colors">
                    <PhotoIcon className="w-4 h-4" />
                    Avatar
                    <input
                      type="file"
                      accept="image/*"
                      className="hidden"
                      onChange={(e) => {
                        const file = e.target.files?.[0]
                        if (file) {
                          setSelectedAvatarFile(file)
                          setAvatarPreview(URL.createObjectURL(file))
                        }
                      }}
                    />
                  </label>
                </div>
              )}
            </div>
            <div className="flex space-x-2">
              {group.is_member ? (
                <>
                  <button
                    onClick={() => setShowCreatePost(true)}
                    className="bg-white text-gray-900 px-4 py-2 rounded-lg font-medium hover:bg-gray-100 transition-colors flex items-center space-x-2"
                  >
                    <PlusIcon className="w-5 h-5" />
                    <span>Publier</span>
                  </button>
                  {userRole && ['admin', 'moderator'].includes(userRole) && (
                    <button
                      onClick={() => setShowAdminPanel(!showAdminPanel)}
                      className="bg-white/20 backdrop-blur-sm text-white px-4 py-2 rounded-lg font-medium hover:bg-white/30 transition-colors flex items-center space-x-2"
                    >
                      <Cog6ToothIcon className="w-5 h-5" />
                      <span>Admin</span>
                    </button>
                  )}
                  <button
                    onClick={leaveGroup}
                    className="bg-white/20 backdrop-blur-sm text-white px-4 py-2 rounded-lg font-medium hover:bg-white/30 transition-colors"
                  >
                    Quitter
                  </button>
                </>
              ) : (
                <button
                  onClick={joinGroup}
                  className="bg-white text-gray-900 px-4 py-2 rounded-lg font-medium hover:bg-gray-100 transition-colors"
                >
                  {group.group_type === 'public' ? 'Rejoindre' : 'Demander à rejoindre'}
                </button>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Contenu principal */}
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Contenu principal - Posts */}
          <div className="lg:col-span-2 space-y-6">
            {/* Panneau d'administration */}
            {showAdminPanel && userRole && ['admin', 'moderator'].includes(userRole) && (
              <div className="bg-gradient-to-r from-amber-50 to-orange-50 rounded-2xl shadow-lg border border-amber-200 p-6">
                <div className="flex items-center justify-between mb-6">
                  <div className="flex items-center space-x-3">
                    <Cog6ToothIcon className="w-6 h-6 text-amber-600" />
                    <h2 className="text-xl font-bold text-gray-900">Panneau d'Administration</h2>
                  </div>
                  <button
                    onClick={() => setShowAdminPanel(false)}
                    className="text-gray-500 hover:text-gray-700"
                  >
                    <XMarkIcon className="w-5 h-5" />
                  </button>
                </div>

                {/* Demandes d'adhésion en attente */}
                <div className="mb-8">
                  <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center space-x-2">
                    <UsersIcon className="w-5 h-5" />
                    <span>Demandes d'adhésion ({pendingMembers.length})</span>
                  </h3>
                  
                  {pendingMembers.length === 0 ? (
                    <p className="text-gray-600 text-sm">Aucune demande d'adhésion en attente.</p>
                  ) : (
                    <div className="space-y-3">
                      {pendingMembers.map((member) => (
                        <div
                          key={member.id}
                          className="flex items-center justify-between bg-white rounded-lg p-4 border border-gray-200"
                        >
                          <div className="flex items-center space-x-3 flex-1">
                            <img
                              src={buildMediaUrl(member.user?.profile?.profile_image || member.user?.profile_image) || '/default-avatar.png'}
                              alt={member.user?.username || 'Utilisateur'}
                              className="w-10 h-10 rounded-full object-cover"
                            />
                            <div>
                              <p className="font-medium text-gray-900">{member.user.username}</p>
                              <p className="text-xs text-gray-500">
                                Demande depuis {new Date(member.joined_at).toLocaleDateString('fr-FR')}
                              </p>
                            </div>
                          </div>
                          <div className="flex items-center space-x-2">
                            <Link
                              href={`/profile/${member.user.username}`}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="flex items-center space-x-1 bg-slate-100 text-slate-800 px-3 py-2 rounded-lg hover:bg-slate-200 transition-colors"
                            >
                              <span className="text-sm">Voir profil</span>
                            </Link>
                            <button
                              onClick={() => approveMember(member.id)}
                              disabled={actionLoading[member.id]}
                              className="flex items-center space-x-1 bg-green-100 text-green-700 px-3 py-2 rounded-lg hover:bg-green-200 transition-colors disabled:opacity-50"
                            >
                              <CheckIcon className="w-4 h-4" />
                              <span className="text-sm">Approuver</span>
                            </button>
                            <button
                              onClick={() => rejectMember(member.id)}
                              disabled={actionLoading[member.id]}
                              className="flex items-center space-x-1 bg-red-100 text-red-700 px-3 py-2 rounded-lg hover:bg-red-200 transition-colors disabled:opacity-50"
                            >
                              <XMarkIcon className="w-4 h-4" />
                              <span className="text-sm">Rejeter</span>
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* Gestion du groupe */}
                <div className="mb-8 bg-white rounded-2xl border border-gray-200 p-4">
                  <div className="flex items-center justify-between mb-4">
                    <div>
                      <h3 className="text-lg font-semibold text-gray-900">Paramètres du groupe</h3>
                      <p className="text-sm text-gray-500">Modifier le nom, la description ou inviter un membre.</p>
                    </div>
                    <button
                      onClick={() => setShowEditForm(!showEditForm)}
                      className="text-fopcam-600 hover:text-fopcam-800 text-sm font-medium"
                    >
                      {showEditForm ? 'Annuler' : 'Modifier'}
                    </button>
                  </div>

                  {showEditForm ? (
                    <div className="space-y-4">
                      <div>
                        <label className="block text-sm font-medium text-gray-700">Nom du groupe</label>
                        <input
                          type="text"
                          value={editForm.name}
                          onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                          className="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-fopcam-500 focus:ring-fopcam-500"
                        />
                      </div>
                      <div>
                        <label className="block text-sm font-medium text-gray-700">Description</label>
                        <textarea
                          rows={3}
                          value={editForm.description}
                          onChange={(e) => setEditForm({ ...editForm, description: e.target.value })}
                          className="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-fopcam-500 focus:ring-fopcam-500"
                        />
                      </div>
                      <div>
                        <label className="block text-sm font-medium text-gray-700">Règles</label>
                        <textarea
                          rows={2}
                          value={editForm.rules}
                          onChange={(e) => setEditForm({ ...editForm, rules: e.target.value })}
                          className="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-fopcam-500 focus:ring-fopcam-500"
                        />
                      </div>
                      <div>
                        <label className="block text-sm font-medium text-gray-700">Type de groupe</label>
                        <select
                          value={editForm.group_type}
                          onChange={(e) => setEditForm({ ...editForm, group_type: e.target.value })}
                          className="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-fopcam-500 focus:ring-fopcam-500"
                        >
                          <option value="public">Public</option>
                          <option value="private">Privé</option>
                          <option value="secret">Secret</option>
                        </select>
                      </div>
                      <div className="grid gap-4 sm:grid-cols-2">
                        <div>
                          <label className="block text-sm font-medium text-gray-700">Photo de couverture</label>
                          <div className="mt-2 flex items-center gap-3">
                            <div className="h-24 w-full overflow-hidden rounded-xl border border-gray-200 bg-gray-50">
                              <img
                                src={coverPreview || buildMediaUrl(group.cover_image) || '/default-avatar.png'}
                                alt="Aperçu couverture"
                                className="h-24 w-full object-cover"
                              />
                            </div>
                          </div>
                          <input
                            type="file"
                            accept="image/*"
                            onChange={(e) => {
                              const file = e.target.files?.[0]
                              if (file) {
                                setSelectedCoverFile(file)
                                setCoverPreview(URL.createObjectURL(file))
                              }
                            }}
                            className="mt-2 block w-full text-sm text-gray-500"
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-700">Avatar du groupe</label>
                          <div className="mt-2 flex items-center gap-3">
                            <div className="h-24 w-24 overflow-hidden rounded-full border border-gray-200 bg-gray-50">
                              <img
                                src={avatarPreview || buildMediaUrl(group.avatar) || '/default-avatar.png'}
                                alt="Aperçu avatar"
                                className="h-24 w-24 object-cover"
                              />
                            </div>
                          </div>
                          <input
                            type="file"
                            accept="image/*"
                            onChange={(e) => {
                              const file = e.target.files?.[0]
                              if (file) {
                                setSelectedAvatarFile(file)
                                setAvatarPreview(URL.createObjectURL(file))
                              }
                            }}
                            className="mt-2 block w-full text-sm text-gray-500"
                          />
                        </div>
                      </div>
                      <div className="flex items-center justify-between gap-3">
                        <button
                          type="button"
                          onClick={saveGroupChanges}
                          className="btn-primary"
                        >
                          Enregistrer
                        </button>
                        <button
                          type="button"
                          onClick={archiveGroup}
                          className="btn-secondary text-red-600 border-red-200 hover:bg-red-50"
                        >
                          Archiver le groupe
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      <div>
                        <p className="text-sm font-medium text-gray-900">Type</p>
                        <p className="text-sm text-gray-600">{group.group_type}</p>
                      </div>
                      <div>
                        <p className="text-sm font-medium text-gray-900">Description</p>
                        <p className="text-sm text-gray-600">{group.description || 'Aucune description'}</p>
                      </div>
                      <div>
                        <p className="text-sm font-medium text-gray-900">Règles</p>
                        <p className="text-sm text-gray-600">{group.rules || 'Pas de règles définies.'}</p>
                      </div>
                    </div>
                  )}

                  <div className="mt-6">
                    <label className="block text-sm font-medium text-gray-700">Ajouter un membre</label>
                    <p className="text-sm text-gray-500">Saisissez le nom d'utilisateur d'un utilisateur existant pour l'ajouter directement au groupe.</p>
                    <div className="mt-2 flex gap-2 flex-col sm:flex-row">
                      <input
                        type="text"
                        value={inviteUsername}
                        onChange={(e) => setInviteUsername(e.target.value)}
                        placeholder="Nom d'utilisateur"
                        className="flex-1 rounded-lg border-gray-300 shadow-sm focus:border-fopcam-500 focus:ring-fopcam-500"
                      />
                      <button
                        type="button"
                        onClick={inviteMember}
                        disabled={actionLoading.invite}
                        className="btn-primary w-full sm:w-auto"
                      >
                        Ajouter
                      </button>
                    </div>
                  </div>
                </div>

                {/* Gestion des membres */}
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center space-x-2">
                    <UsersIcon className="w-5 h-5" />
                    <span>Gestion des membres ({members.length})</span>
                  </h3>
                  
                  {members.length === 0 ? (
                    <p className="text-gray-600 text-sm">Aucun membre.</p>
                  ) : (
                    <div className="space-y-3 max-h-64 overflow-y-auto">
                      {members.map((member) => (
                        <div
                          key={member.id}
                          className="flex items-center justify-between bg-white rounded-lg p-4 border border-gray-200"
                        >
                          <div className="flex items-center space-x-3 flex-1 min-w-0">
                            <img
                              src={buildMediaUrl(member.user?.profile?.profile_image || member.user?.profile_image) || '/default-avatar.png'}
                              alt={member.user?.username || 'Utilisateur'}
                              className="w-10 h-10 rounded-full object-cover flex-shrink-0"
                            />
                            <div className="min-w-0">
                              <p className="font-medium text-gray-900 truncate">{member.user.username}</p>
                              <div className="flex items-center space-x-2">
                                <span className={`text-xs px-2 py-1 rounded font-medium ${
                                  member.role === 'admin' ? 'bg-purple-100 text-purple-700' :
                                  member.role === 'moderator' ? 'bg-blue-100 text-blue-700' :
                                  'bg-gray-100 text-gray-700'
                                }`}>
                                  {member.role === 'admin' ? 'Admin' :
                                   member.role === 'moderator' ? 'Modérateur' : 'Membre'}
                                </span>
                                {member.user.id === group.creator.id && (
                                  <span className="text-xs text-gray-500">Créateur</span>
                                )}
                              </div>
                            </div>
                          </div>
                          <div className="flex items-center space-x-1 flex-shrink-0">
                            {member.user.id !== group.creator.id && userRole === 'admin' && (
                              <>
                                {member.role !== 'admin' && (
                                  <button
                                    onClick={() => promoteUser(member.id)}
                                    disabled={actionLoading[`promote-${member.id}`]}
                                    className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors disabled:opacity-50"
                                    title="Promouvoir"
                                  >
                                    <ArrowUpIcon className="w-4 h-4" />
                                  </button>
                                )}
                                {member.role !== 'member' && (
                                  <button
                                    onClick={() => demoteUser(member.id)}
                                    disabled={actionLoading[`demote-${member.id}`]}
                                    className="p-2 text-orange-600 hover:bg-orange-50 rounded-lg transition-colors disabled:opacity-50"
                                    title="Rétrograder"
                                  >
                                    <ArrowDownIcon className="w-4 h-4" />
                                  </button>
                                )}
                                <button
                                  onClick={() => removeUser(member.id, member.user.username)}
                                  disabled={actionLoading[`remove-${member.id}`]}
                                  className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-50"
                                  title="Retirer du groupe"
                                >
                                  <TrashIcon className="w-4 h-4" />
                                </button>
                              </>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            )}
            
            {/* Formulaire de création de post */}
            {showCreatePost && group.is_member && (
              <div className="bg-white rounded-2xl shadow-lg p-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Créer une publication</h3>
                <form onSubmit={createPost} className="space-y-4">
                  <select
                    value={newPost.post_type}
                    onChange={(e) => setNewPost({...newPost, post_type: e.target.value})}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                  >
                    <option value="text">Texte</option>
                    <option value="image">Image</option>
                    <option value="video">Vidéo</option>
                    <option value="link">Lien</option>
                    <option value="event">Événement</option>
                  </select>

                  <textarea
                    placeholder="Contenu de votre publication..."
                    value={newPost.content}
                    onChange={(e) => setNewPost({...newPost, content: e.target.value})}
                    rows={4}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                  />

                  {/* Champs spécifiques selon le type */}
                  {newPost.post_type === 'image' && (
                    <input
                      type="file"
                      multiple
                      accept="image/*"
                      onChange={(e) => setNewPost({...newPost, images: Array.from(e.target.files)})}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                    />
                  )}

                  {newPost.post_type === 'video' && (
                    <input
                      type="file"
                      multiple
                      accept="video/*"
                      onChange={(e) => setNewPost({...newPost, videos: Array.from(e.target.files)})}
                      className="w-full px-4 py-2 border border-gray-300 rounded-lg"
                    />
                  )}

                  {newPost.post_type === 'link' && (
                    <div className="space-y-2">
                      <input
                        type="url"
                        placeholder="URL du lien"
                        value={newPost.link_url}
                        onChange={(e) => setNewPost({...newPost, link_url: e.target.value})}
                        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                      />
                      <input
                        type="text"
                        placeholder="Titre du lien"
                        value={newPost.link_title}
                        onChange={(e) => setNewPost({...newPost, link_title: e.target.value})}
                        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                      />
                      <textarea
                        placeholder="Description du lien"
                        value={newPost.link_description}
                        onChange={(e) => setNewPost({...newPost, link_description: e.target.value})}
                        rows={2}
                        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                      />
                    </div>
                  )}

                  {newPost.post_type === 'event' && (
                    <div className="space-y-2">
                      <input
                        type="datetime-local"
                        value={newPost.event_date}
                        onChange={(e) => setNewPost({...newPost, event_date: e.target.value})}
                        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                      />
                      <input
                        type="text"
                        placeholder="Lieu de l'événement"
                        value={newPost.event_location}
                        onChange={(e) => setNewPost({...newPost, event_location: e.target.value})}
                        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                      />
                    </div>
                  )}

                  <div className="flex space-x-2">
                    <button
                      type="button"
                      onClick={() => setShowCreatePost(false)}
                      className="flex-1 btn-secondary"
                    >
                      Annuler
                    </button>
                    <button
                      type="submit"
                      className="flex-1 btn-primary"
                    >
                      Publier
                    </button>
                  </div>
                </form>
              </div>
            )}

            {/* Liste des posts */}
            {posts.map((post) => (
              <div key={post.id} className="bg-white rounded-2xl shadow-lg p-6">
                <div className="flex items-start space-x-3 mb-4">
                  <img
                    src={buildMediaUrl(post.author.profile_image) || '/default-avatar.png'}
                    alt={post.author.username}
                    className="w-10 h-10 rounded-full object-cover"
                  />
                  <div className="flex-1">
                    <div className="flex items-center space-x-2">
                      <span className="font-semibold text-gray-900">{post.author.username}</span>
                      {getPostTypeIcon(post.post_type)}
                    </div>
                    <span className="text-sm text-gray-500">
                      {new Date(post.created_at).toLocaleDateString('fr-FR')}
                    </span>
                  </div>
                </div>

                {post.title && (
                  <h3 className="font-semibold text-lg text-gray-900 mb-2">{post.title}</h3>
                )}

                <p className="text-gray-700 mb-4 whitespace-pre-wrap">{post.content}</p>

                {/* Contenu spécifique selon le type */}
                {post.post_type === 'image' && post.image && (
                  <img
                    src={buildMediaUrl(post.image)}
                    alt={post.title}
                    className="w-full rounded-lg mb-4"
                  />
                )}

                {post.post_type === 'video' && post.video && (
                  <video
                    controls
                    className="w-full rounded-lg mb-4"
                  >
                    <source src={buildMediaUrl(post.video)} type="video/mp4" />
                    Votre navigateur ne supporte pas la lecture vidéo.
                  </video>
                )}

                {post.post_type === 'link' && post.link_url && (
                  <div className="border border-gray-200 rounded-lg p-4 mb-4">
                    <a
                      href={post.link_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-fopcam-600 hover:text-fopcam-700 font-medium"
                    >
                      {post.link_title || post.link_url}
                    </a>
                    {post.link_description && (
                      <p className="text-gray-600 text-sm mt-1">{post.link_description}</p>
                    )}
                  </div>
                )}

                {post.post_type === 'event' && (
                  <div className="bg-fopcam-50 border border-fopcam-200 rounded-lg p-4 mb-4">
                    <div className="flex items-center space-x-2 text-fopcam-700 mb-2">
                      <CalendarIcon className="w-5 h-5" />
                      <span className="font-medium">Événement</span>
                    </div>
                    <p className="text-sm text-gray-600">
                      📅 {new Date(post.event_date).toLocaleString('fr-FR')}
                    </p>
                    {post.event_location && (
                      <p className="text-sm text-gray-600">
                        📍 {post.event_location}
                      </p>
                    )}
                  </div>
                )}

                {/* Actions */}
                <div className="flex items-center justify-between pt-4 border-t border-gray-100">
                  <div className="flex items-center space-x-6">
                    <button
                      onClick={() => likePost(post.id)}
                      className={`flex items-center space-x-2 px-3 py-2 rounded-lg transition-colors ${
                        post.is_liked ? 'text-red-600 bg-red-50' : 'text-gray-600 hover:bg-gray-50'
                      }`}
                    >
                      {post.is_liked ? (
                        <HeartIconSolid className="w-5 h-5" />
                      ) : (
                        <HeartIcon className="w-5 h-5" />
                      )}
                      <span className="text-sm">{post.likes_count}</span>
                    </button>

                    <button className="flex items-center space-x-2 px-3 py-2 text-gray-600 hover:bg-gray-50 rounded-lg transition-colors">
                      <ChatBubbleLeftIcon className="w-5 h-5" />
                      <span className="text-sm">{post.comments_count}</span>
                    </button>

                    <button className="flex items-center space-x-2 px-3 py-2 text-gray-600 hover:bg-gray-50 rounded-lg transition-colors">
                      <ShareIcon className="w-5 h-5" />
                      <span className="text-sm">Partager</span>
                    </button>
                  </div>

                  <button className="p-2 text-gray-400 hover:text-gray-600">
                    <EllipsisVerticalIcon className="w-5 h-5" />
                  </button>
                </div>
              </div>
            ))}

            {posts.length === 0 && (
              <div className="text-center py-12">
                <div className="text-gray-400 mb-4">
                  <ChatBubbleLeftIcon className="w-16 h-16 mx-auto" />
                </div>
                <h3 className="text-lg font-medium text-gray-900 mb-2">Aucune publication</h3>
                <p className="text-gray-500">
                  {group.is_member
                    ? "Soyez le premier à publier dans ce groupe !"
                    : "Rejoignez ce groupe pour voir les publications."
                  }
                </p>
              </div>
            )}
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Infos du groupe */}
            <div className="bg-white rounded-2xl shadow-lg p-6">
              <h3 className="font-semibold text-gray-900 mb-4">À propos</h3>
              <p className="text-gray-600 text-sm mb-4">{group.description}</p>

              {group.rules && (
                <div className="mb-4">
                  <h4 className="font-medium text-gray-900 mb-2">Règles du groupe</h4>
                  <p className="text-gray-600 text-sm whitespace-pre-wrap">{group.rules}</p>
                </div>
              )}

              <div className="space-y-2 text-sm text-gray-600">
                <div className="flex items-center space-x-2">
                  <UsersIcon className="w-4 h-4" />
                  <span>{group.member_count} membres</span>
                </div>
                {group.location && (
                  <div className="flex items-center space-x-2">
                    <MapPinIcon className="w-4 h-4" />
                    <span>{group.location}</span>
                  </div>
                )}
                <div>
                  <span>Créé par {group.creator.username}</span>
                </div>
              </div>
            </div>

            {/* Membres du groupe */}
            <div className="bg-white rounded-2xl shadow-lg p-6">
              <h3 className="font-semibold text-gray-900 mb-4">Membres du groupe</h3>
              {group.is_member ? (
                members.length > 0 ? (
                  <div className="space-y-3">
                    {members.slice(0, 8).map((member) => (
                      <Link
                        key={member.id}
                        href={`/profile/${member.user.username}`}
                        className="flex items-center space-x-3 p-3 rounded-xl border border-gray-200 hover:bg-fopcam-50 transition-colors"
                      >
                        <img
                          src={buildMediaUrl(member.user?.profile?.profile_image || member.user?.profile_image) || '/default-avatar.png'}
                          alt={member.user.username}
                          className="w-12 h-12 rounded-full object-cover"
                        />
                        <div className="min-w-0">
                          <p className="text-sm font-medium text-gray-900 truncate">{member.user.username}</p>
                          <p className="text-xs text-gray-500 truncate">
                            {member.role === 'admin' ? 'Admin' : member.role === 'moderator' ? 'Modérateur' : 'Membre'}
                          </p>
                        </div>
                      </Link>
                    ))}
                    {members.length > 8 && (
                      <div className="text-sm text-gray-500">Et {members.length - 8} autres membres...</div>
                    )}
                  </div>
                ) : (
                  <p className="text-gray-600 text-sm">Aucun membre à afficher pour le moment.</p>
                )
              ) : (
                <p className="text-gray-600 text-sm">Rejoignez le groupe pour voir les membres.</p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default GroupDetailPage