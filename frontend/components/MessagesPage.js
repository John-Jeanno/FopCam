import { useEffect, useState, useRef, useMemo, useCallback } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/router'
import {
  ArrowLeftIcon,
  ChatBubbleBottomCenterIcon,
  PaperAirplaneIcon,
  UserIcon,
  WifiIcon,
  EllipsisHorizontalIcon,
  MicrophoneIcon,
  StopIcon,
  PlayIcon,
  PauseIcon,
  FaceSmileIcon,
  PaperClipIcon,
} from '@heroicons/react/24/outline'
import EmojiPicker from 'emoji-picker-react'

const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

function MessagesPage() {
  const router = useRouter()
  const { room } = router.query
  const [messages, setMessages] = useState([])
  const [newMessage, setNewMessage] = useState('')
  const [conversations, setConversations] = useState([])
  const [availableUsers, setAvailableUsers] = useState([])
  const [isConnected, setIsConnected] = useState(false)
  const [sending, setSending] = useState(false)
  const [currentUser, setCurrentUser] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [typing, setTyping] = useState(false)
  const [messageMode, setMessageMode] = useState('text') // 'text' or 'audio'
  const [isRecording, setIsRecording] = useState(false)
  const [audioBlob, setAudioBlob] = useState(null)
  const [mediaRecorder, setMediaRecorder] = useState(null)
  const [recordingTime, setRecordingTime] = useState(0)
  const [showEmojiPicker, setShowEmojiPicker] = useState(false)
  const [attachmentFile, setAttachmentFile] = useState(null)
  const [attachmentPreview, setAttachmentPreview] = useState(null)
  const [attachmentType, setAttachmentType] = useState(null)
  const wsRef = useRef(null)
  const fileInputRef = useRef(null)
  const messagesEndRef = useRef(null)
  const inputRef = useRef(null)
  const recordingIntervalRef = useRef(null)
  const typingTimeoutRef = useRef(null)
  const lastTypingSentRef = useRef(0)
  const reconnectTimeoutRef = useRef(null)
  const reconnectAttemptsRef = useRef(0)
  const maxReconnectAttempts = 5

  const getAuthToken = useCallback(() => {
    if (typeof window === 'undefined') return null
    return localStorage.getItem('access_token') || localStorage.getItem('access') || null
  }, [])

  const getAuthHeaders = useCallback((extraHeaders = {}) => {
    const token = getAuthToken()
    return token
      ? { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', ...extraHeaders }
      : { 'Content-Type': 'application/json', ...extraHeaders }
  }, [getAuthToken])

  const scrollToBottom = useCallback(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [])

  useEffect(() => {
    scrollToBottom()
  }, [messages, scrollToBottom])

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (showEmojiPicker && !event.target.closest('.emoji-picker-container')) {
        setShowEmojiPicker(false)
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [showEmojiPicker])

  // Audio recording functions
  const startRecording = useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      const recorder = new MediaRecorder(stream)
      const chunks = []

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunks.push(event.data)
        }
      }

      recorder.onstop = () => {
        const blob = new Blob(chunks, { type: 'audio/wav' })
        setAudioBlob(blob)
        stream.getTracks().forEach(track => track.stop())
      }

      setMediaRecorder(recorder)
      recorder.start()
      setIsRecording(true)
      setRecordingTime(0)

      recordingIntervalRef.current = setInterval(() => {
        setRecordingTime(prev => prev + 1)
      }, 1000)
    } catch (error) {
      console.error('Error starting recording:', error)
      alert('Erreur lors de l\'accès au microphone. Vérifiez les permissions.')
    }
  }, [])

  const stopRecording = useCallback(() => {
    if (mediaRecorder && isRecording) {
      mediaRecorder.stop()
      setIsRecording(false)
      if (recordingIntervalRef.current) {
        clearInterval(recordingIntervalRef.current)
      }
    }
  }, [mediaRecorder, isRecording])

  const cancelRecording = useCallback(() => {
    if (mediaRecorder && isRecording) {
      mediaRecorder.stop()
      setIsRecording(false)
      setAudioBlob(null)
      setRecordingTime(0)
      if (recordingIntervalRef.current) {
        clearInterval(recordingIntervalRef.current)
      }
    }
  }, [mediaRecorder, isRecording])

  const getAttachmentTypeFromFile = useCallback((file) => {
    if (!file || !file.type) return 'document'
    if (file.type.startsWith('image/')) return 'image'
    if (file.type.startsWith('video/')) return 'video'
    if (file.type.startsWith('audio/')) return 'audio'
    return 'document'
  }, [])

  const handleFileChange = useCallback((event) => {
    const file = event.target.files?.[0]
    if (!file) return

    const type = getAttachmentTypeFromFile(file)
    setAttachmentFile(file)
    setAttachmentType(type)
    setAttachmentPreview(type === 'image' || type === 'video' ? URL.createObjectURL(file) : null)
  }, [getAttachmentTypeFromFile])

  const removeAttachment = useCallback(() => {
    if (attachmentPreview) {
      URL.revokeObjectURL(attachmentPreview)
    }
    setAttachmentFile(null)
    setAttachmentPreview(null)
    setAttachmentType(null)
  }, [attachmentPreview])

  const fileToBase64 = useCallback((file) => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload = () => {
        const result = reader.result
        const base64 = result.includes(',') ? result.split(',')[1] : result
        resolve(base64)
      }
      reader.onerror = reject
      reader.readAsDataURL(file)
    })
  }, [])

  useEffect(() => {
    return () => {
      if (attachmentPreview) {
        URL.revokeObjectURL(attachmentPreview)
      }
    }
  }, [attachmentPreview])

  const sendTypingEvent = useCallback(() => {
    if (!room || !wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) return
    const now = Date.now()
    if (now - lastTypingSentRef.current < 1200) return
    lastTypingSentRef.current = now

    wsRef.current.send(JSON.stringify({
      event_type: 'typing',
      room,
    }))
  }, [room])

  const handleIncomingTyping = useCallback((typingUser) => {
    if (!typingUser || typingUser.username === currentUser?.username) return

    setTyping(true)
    if (typingTimeoutRef.current) {
      clearTimeout(typingTimeoutRef.current)
    }

    typingTimeoutRef.current = setTimeout(() => {
      setTyping(false)
    }, 1500)
  }, [currentUser?.username])

  const formatRecordingTime = useCallback((seconds) => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }, [])

  useEffect(() => {
    // Tokens are now in httpOnly cookies, no need to check localStorage
    const fetchArrayData = async (res) => {
      const data = await res.json().catch(() => [])
      return Array.isArray(data) ? data : data.results || []
    }

    const loadData = async () => {
      try {
        const fetchOptions = {
          headers: getAuthHeaders(),
          credentials: 'include',
        }

        const [userRes, profilesRes, messagesRes] = await Promise.all([
          fetch(`${apiUrl}/api/auth/me/`, fetchOptions),
          fetch(`${apiUrl}/api/profiles/`, fetchOptions),
          fetch(`${apiUrl}/api/messages/`, fetchOptions),
        ])

        // Check for 401 Unauthorized - token may be invalid or expired
        if (userRes.status === 401 || profilesRes.status === 401 || messagesRes.status === 401) {
          // Tokens are in httpOnly cookies, redirect to login to get new ones
          router.push('/login')
          return
        }

        if (!userRes.ok) {
          console.error('User response:', userRes.status, await userRes.text())
          throw new Error(`Impossible de charger le profil utilisateur (${userRes.status})`)
        }

        const userData = await userRes.json()
        setCurrentUser(userData)

        if (!profilesRes.ok) {
          console.error('Profiles response:', profilesRes.status)
          throw new Error(`Impossible de charger les profils (${profilesRes.status})`)
        }
        if (!messagesRes.ok) {
          console.error('Messages response:', messagesRes.status)
          throw new Error(`Impossible de charger les messages (${messagesRes.status})`)
        }

        const profilesData = await fetchArrayData(profilesRes)
        setAvailableUsers(profilesData.filter((profile) => profile.user?.id !== userData.id))

        const messagesData = await fetchArrayData(messagesRes)
        const conversationMap = {}
        messagesData.forEach((message) => {
          if (!message.room || !message.user || !message.recipient) return
          const isCurrentUserSender = message.user.id === userData.id
          const otherUser = isCurrentUserSender ? message.recipient : message.user
          if (!otherUser) return

          const existing = conversationMap[message.room]
          if (!existing || new Date(message.created_at) > new Date(existing.updated_at)) {
            conversationMap[message.room] = {
              room_id: message.room,
              other_user: otherUser,
              last_message: message.content,
              updated_at: message.created_at,
            }
          }
        })

        const conversationList = Object.values(conversationMap).sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at))
        setConversations(conversationList)
      } catch (err) {
        console.error('Error loading messaging data:', err)
        setError('Erreur lors du chargement des conversations')
      } finally {
        setLoading(false)
      }
    }

    loadData()
  }, []) // Remove router dependency to prevent infinite re-renders

  const connectWebSocket = useCallback(() => {
    if (!room || !currentUser) return

    const token = getAuthToken()
    const tokenQuery = token ? `?token=${encodeURIComponent(token)}` : ''
    const wsProtocol = apiUrl.startsWith('https') ? 'wss' : 'ws'
    const wsBaseUrl = apiUrl.replace(/^http/, wsProtocol)
    const ws = new WebSocket(`${wsBaseUrl}/ws/chat/${encodeURIComponent(room)}/${tokenQuery}`)
    wsRef.current = ws

    ws.onopen = () => {
      console.log('WebSocket connecté')
      setIsConnected(true)
      reconnectAttemptsRef.current = 0
    }

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data)

      if (data.event === 'typing' && data.room === room) {
        handleIncomingTyping(data.user)
        return
      }

      if (data.message && data.user && data.timestamp) {
        const userPayload = typeof data.user === 'object'
          ? data.user
          : {
              username: data.user,
              id: data.user === currentUser?.username ? currentUser?.id : undefined,
              profile_image: data.user === currentUser?.username ? currentUser?.profile_image : null,
            }

        const newMessage = {
          id: data.id,
          content: data.message,
          user: userPayload,
          created_at: data.timestamp,
          message_type: data.message_type || 'text',
          audio_file: data.audio_file,
          audio_duration: data.audio_duration,
          attachment_file: data.attachment_file,
          attachment_type: data.attachment_type,
          attachment_name: data.attachment_name,
        }

        setMessages(prev => {
          const exists = prev.some(msg =>
            msg.id && newMessage.id ? msg.id === newMessage.id : (
              msg.content === newMessage.content &&
              msg.user?.username === newMessage.user?.username &&
              Math.abs(new Date(msg.created_at) - new Date(newMessage.created_at)) < 1000
            )
          )
          return exists ? prev : [...prev, newMessage]
        })

        setConversations(prev => {
          const next = prev.map((conversation) => {
            if (conversation.room_id !== room) return conversation
            return {
              ...conversation,
              last_message: data.message || data.attachment_name || (data.message_type === 'audio' ? 'Message vocal' : (data.message_type === 'image' ? 'Image' : data.message_type === 'video' ? 'Vidéo' : 'Pièce jointe')),
              updated_at: data.timestamp,
            }
          })

          if (!next.some((conversation) => conversation.room_id === room)) {
            const otherUser = userPayload.username === currentUser?.username
              ? currentConversation?.other_user
              : userPayload
            if (!otherUser) return next

            return [
              {
                room_id: room,
                other_user: otherUser,
                last_message: data.message || (data.message_type === 'audio' ? 'Message vocal' : ''),
                updated_at: data.timestamp,
              },
              ...next,
            ]
          }

          return next
        })
      }
    }

    ws.onclose = () => {
      console.log('WebSocket déconnecté')
      setIsConnected(false)
      setTyping(false)
      
      // Reconnexion automatique avec backoff exponentiel
      if (reconnectAttemptsRef.current < maxReconnectAttempts) {
        const delay = Math.min(1000 * Math.pow(2, reconnectAttemptsRef.current), 30000)
        reconnectTimeoutRef.current = setTimeout(() => {
          reconnectAttemptsRef.current += 1
          console.log(`Reconnexion tentée ${reconnectAttemptsRef.current}/${maxReconnectAttempts}`)
          connectWebSocket()
        }, delay)
      }
    }

    ws.onerror = (error) => {
      console.error('Erreur WebSocket:', error)
      setIsConnected(false)
    }
  }, [room, currentUser, getAuthToken, apiUrl, handleIncomingTyping])

  useEffect(() => {
    if (!room || !currentUser) return

    connectWebSocket()

    const loadMessages = async () => {
      try {
        const res = await fetch(`${apiUrl}/api/messages/?room=${encodeURIComponent(room)}`, {
          headers: getAuthHeaders(),
          credentials: 'include',
        })
        if (res.ok) {
          const data = await res.json()
          const messagesData = Array.isArray(data) ? data : data.results || []
          setMessages(messagesData)
        }
      } catch (err) {
        console.error('Erreur chargement messages:', err)
      }
    }

    loadMessages()

    return () => {
      if (wsRef.current) {
        wsRef.current.close()
      }
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current)
      }
    }
  }, [room, currentUser, connectWebSocket, getAuthHeaders, apiUrl])

  const sendMessage = async () => {
    if (messageMode === 'text' && !newMessage.trim() && !attachmentFile) return
    if (messageMode === 'audio' && !audioBlob) return

    setSending(true)
    // Tokens are now in httpOnly cookies, automatically included in requests

    try {
      let messageData = {
        room: room,
        message_type: messageMode
      }

      if (attachmentFile) {
        const type = attachmentType || getAttachmentTypeFromFile(attachmentFile)
        const textContent = newMessage.trim() || attachmentFile.name
        messageData.attachment_name = attachmentFile.name
        messageData.attachment_type = type
        messageData.message_type = type
        messageData.content = textContent
        messageData.message = textContent
      } else if (messageMode === 'text') {
        const textContent = newMessage.trim()
        messageData.content = textContent
        messageData.message = textContent
      } else if (messageMode === 'audio') {
        // Convert blob to base64 for sending
        const base64String = await new Promise((resolve) => {
          const reader = new FileReader()
          reader.onload = () => {
            const result = reader.result
            const base64 = result.includes(',') ? result.split(',')[1] : result
            resolve(base64)
          }
          reader.readAsDataURL(audioBlob)
        })
        messageData.audio_data = base64String
        messageData.audio_duration = recordingTime
      }

      if (attachmentFile) {
        const base64Attachment = await fileToBase64(attachmentFile)
        messageData.attachment_data = base64Attachment
        messageData.attachment_name = attachmentFile.name
        messageData.attachment_type = attachmentType || getAttachmentTypeFromFile(attachmentFile)
        messageData.message_type = attachmentType || getAttachmentTypeFromFile(attachmentFile)
      }

      // Send text messages over WebSocket when possible.
      // Audio and attachments use the API multipart endpoint to avoid corruption.
      const shouldUseWebSocket = isConnected && wsRef.current && wsRef.current.readyState === WebSocket.OPEN && !attachmentFile && messageMode === 'text'

      if (shouldUseWebSocket) {
        wsRef.current.send(JSON.stringify(messageData))
        setNewMessage('')
        setAudioBlob(null)
        setRecordingTime(0)
        removeAttachment()
      } else {
        // Send via API for attachments or audio
        const formData = new FormData()
        formData.append('room', room)
        formData.append('message_type', attachmentFile ? (attachmentType || getAttachmentTypeFromFile(attachmentFile)) : messageMode)

        if (attachmentFile) {
          formData.append('attachment_file', attachmentFile, attachmentFile.name)
          formData.append('attachment_type', attachmentType || getAttachmentTypeFromFile(attachmentFile))
          formData.append('content', newMessage.trim() || attachmentFile.name)
        } else if (messageMode === 'text') {
          formData.append('content', newMessage.trim())
        } else if (messageMode === 'audio') {
          formData.append('audio_file', audioBlob, 'voice_message.wav')
          formData.append('audio_duration', recordingTime.toString())
        }

        const token = getAuthToken()
        const response = await fetch(`${apiUrl}/api/messages/`, {
          method: 'POST',
          body: formData,
          headers: token ? { Authorization: `Bearer ${token}` } : undefined,
          credentials: 'include',
        })

        if (response.ok) {
          const message = await response.json()
          setMessages(prev => [...prev, message])
          setNewMessage('')
          setAudioBlob(null)
          setRecordingTime(0)
          removeAttachment()
        } else {
          console.error('Failed to send message via API')
        }
      }
    } catch (error) {
      console.error('Error sending message:', error)
    } finally {
      setSending(false)
    }
  }

  const startConversation = useCallback((profile) => {
    if (!currentUser?.username || !profile?.user?.username) return
    const participants = [currentUser.username, profile.user.username].sort()
    const roomId = `private_${participants.join('_')}`
    router.push(`/messages?room=${encodeURIComponent(roomId)}`)
  }, [currentUser?.username, router])

  const buildMediaUrl = useCallback((path) => {
    if (!path) return null
    if (path.startsWith('http')) return path
    return `${apiUrl}${path.startsWith('/') ? path : `/${path}`}`
  }, [apiUrl])

  const currentConversation = useMemo(() => {
    return conversations.find(c => c.room_id === room)
  }, [conversations, room])

  const filteredAvailableUsers = useMemo(() => {
    return availableUsers || []
  }, [availableUsers])

  const formatConversationDate = useCallback((dateString) => {
    return new Date(dateString).toLocaleDateString('fr-FR', {
      hour: '2-digit',
      minute: '2-digit'
    })
  }, [])

  const formatMessageTime = useCallback((dateString) => {
    return new Date(dateString).toLocaleTimeString('fr-FR', {
      hour: '2-digit',
      minute: '2-digit'
    })
  }, [])

  const normalizeUrl = useCallback((url) => {
    if (!url) return url
    return url.startsWith('www.') ? `https://${url}` : url
  }, [])

  const renderLinkifiedText = useCallback((text, isCurrentUser = false) => {
    if (!text) return text

    const urlRegex = /(https?:\/\/[^\s]+|www\.[^\s]+)/gi
    const parts = []
    let lastIndex = 0
    let partIndex = 0

    text.replace(urlRegex, (match, _p1, offset) => {
      if (offset > lastIndex) {
        parts.push(
          <span key={`text-${partIndex}`}>
            {text.slice(lastIndex, offset)}
          </span>
        )
        partIndex++
      }
      const url = normalizeUrl(match)
      parts.push(
        <a
          key={`link-${partIndex}`}
          href={url}
          target="_blank"
          rel="noreferrer noopener"
          className={`${isCurrentUser ? 'text-white' : 'text-fopcam-600 hover:underline'} break-all`}
        >
          {match}
        </a>
      )
      partIndex++
      lastIndex = offset + match.length
      return match
    })

    if (lastIndex < text.length) {
      parts.push(
        <span key={`text-${partIndex}`}>
          {text.slice(lastIndex)}
        </span>
      )
    }

    return parts.length > 0 ? parts : text
  }, [normalizeUrl])

  const onEmojiClick = useCallback((emojiObject) => {
    setNewMessage(prev => prev + emojiObject.emoji)
    setShowEmojiPicker(false)
    inputRef.current?.focus()
  }, [])

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-fopcam-50 to-blue-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-4 border-fopcam-500 border-t-transparent mx-auto mb-4"></div>
          <p className="text-gray-600 font-medium">Chargement des messages...</p>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-fopcam-50 to-blue-50 flex items-center justify-center">
        <div className="text-center">
          <div className="bg-white rounded-xl shadow-lg p-8 max-w-md">
            <div className="text-red-500 mb-4">
              <svg className="w-16 h-16 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
            </div>
            <h3 className="text-xl font-semibold text-gray-900 mb-2">Erreur de chargement</h3>
            <p className="text-gray-600 mb-6">{error}</p>
            <Link href="/" className="inline-flex items-center px-4 py-2 bg-fopcam-500 text-white rounded-lg hover:bg-fopcam-600 transition-colors">
              <ArrowLeftIcon className="w-4 h-4 mr-2" />
              Retour à l'accueil
            </Link>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-fopcam-50 via-blue-50 to-green-50">
      <div className="max-w-7xl mx-auto px-4 py-6">
        <div className="bg-white rounded-2xl shadow-xl min-h-[700px] flex overflow-hidden">
          {/* Sidebar */}
          <div className="w-80 bg-gray-50 border-r border-gray-200 flex flex-col">
            {/* Header */}
            <div className="p-6 border-b border-gray-200 bg-white">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <Link href="/" className="text-gray-500 hover:text-fopcam-600 transition-colors">
                    <ArrowLeftIcon className="w-6 h-6" />
                  </Link>
                  <h1 className="text-2xl font-bold text-gray-900">Messages</h1>
                </div>
                <div className="flex items-center gap-2">
                  <WifiIcon className={`w-5 h-5 ${isConnected ? 'text-green-500' : 'text-red-500'}`} />
                </div>
              </div>
              <p className="text-sm text-gray-600 mt-2">
                Connecté avec {currentUser?.username}
              </p>
            </div>

            {/* Conversations List */}
            <div className="flex-1 overflow-y-auto">
              <div className="p-4">
                <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
                  <ChatBubbleBottomCenterIcon className="w-5 h-5" />
                  Conversations
                </h2>
                {conversations.map((conversation) => (
                  <div
                    key={conversation.room_id}
                    role="button"
                    tabIndex={0}
                    onClick={() => router.push(`/messages?room=${conversation.room_id}`)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        router.push(`/messages?room=${conversation.room_id}`)
                      }
                    }}
                    className={`block p-4 rounded-xl mb-3 hover:bg-white hover:shadow-sm transition-all duration-200 ${
                      room === conversation.room_id
                        ? 'bg-fopcam-50 border-2 border-fopcam-200 shadow-md'
                        : 'bg-white border border-gray-100'
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      {conversation.other_user.profile_image ? (
                        <Link href={`/profile/${conversation.other_user.username}`} onClick={(e) => e.stopPropagation()}>
                          <img
                            src={buildMediaUrl(conversation.other_user.profile_image)}
                            alt={conversation.other_user.username}
                            className="w-12 h-12 rounded-full object-cover ring-2 ring-gray-100 cursor-pointer hover:ring-fopcam-300 transition-colors"
                          />
                        </Link>
                      ) : (
                        <Link href={`/profile/${conversation.other_user.username}`} onClick={(e) => e.stopPropagation()}>
                          <div className="w-12 h-12 rounded-full bg-gradient-to-br from-fopcam-400 to-fopcam-600 flex items-center justify-center ring-2 ring-gray-100 cursor-pointer hover:ring-fopcam-300 transition-colors">
                            <UserIcon className="w-6 h-6 text-white" />
                          </div>
                        </Link>
                      )}
                      <div className="flex-1 min-w-0">
                        <Link href={`/profile/${conversation.other_user.username}`} onClick={(e) => e.stopPropagation()}>
                          <div className="font-semibold text-gray-900 truncate cursor-pointer hover:text-fopcam-600 transition-colors">
                            {conversation.other_user.username}
                          </div>
                        </Link>
                        <div className="text-sm text-gray-600 truncate mt-1">
                          {conversation.last_message || 'Aucun message'}
                        </div>
                        <div className="text-xs text-gray-500 mt-1">
                          {formatConversationDate(conversation.updated_at)}
                        </div>
                      </div>
                    </div>
                  </div>
                ))}

                <h2 className="text-lg font-semibold text-gray-900 mb-4 mt-8 flex items-center gap-2">
                  <UserIcon className="w-5 h-5" />
                  Utilisateurs disponibles
                </h2>
                {filteredAvailableUsers.map((profile) => (
                    <div
                      key={profile.id}
                      className="w-full p-4 rounded-xl mb-3 hover:bg-white hover:shadow-sm transition-all duration-200 bg-white border border-gray-100"
                    >
                      <div className="flex items-center gap-3">
                        <Link href={`/profile/${profile.user?.username}`}>
                          {profile.profile_image ? (
                            <img
                              src={buildMediaUrl(profile.profile_image)}
                              alt={profile.user?.username}
                              className="w-12 h-12 rounded-full object-cover ring-2 ring-gray-100 cursor-pointer hover:ring-fopcam-300 transition-colors"
                            />
                          ) : (
                            <div className="w-12 h-12 rounded-full bg-gradient-to-br from-blue-400 to-blue-600 flex items-center justify-center ring-2 ring-gray-100 cursor-pointer hover:ring-fopcam-300 transition-colors">
                              <UserIcon className="w-6 h-6 text-white" />
                            </div>
                          )}
                        </Link>
                        <div className="flex-1 min-w-0">
                          <Link href={`/profile/${profile.user?.username}`}>
                            <div className="font-semibold text-gray-900 truncate cursor-pointer hover:text-fopcam-600 transition-colors">
                              {profile.user?.username || 'Utilisateur'}
                            </div>
                          </Link>
                          <div className="text-sm text-gray-600 mt-1">
                            <button
                              onClick={() => startConversation(profile)}
                              className="text-fopcam-600 hover:text-fopcam-700 font-medium"
                            >
                              Démarrer une conversation
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
              </div>
            </div>
          </div>

          {/* Main Chat Area */}
          <div className="flex-1 flex flex-col bg-gray-50">
            {room ? (
              <>
                {/* Chat Header */}
                <div className="bg-white border-b border-gray-200 p-6">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4">
                      {currentConversation?.other_user?.profile_image ? (
                        <img
                          src={buildMediaUrl(currentConversation.other_user.profile_image)}
                          alt={currentConversation.other_user.username}
                          className="w-12 h-12 rounded-full object-cover ring-2 ring-fopcam-200"
                        />
                      ) : (
                        <div className="w-12 h-12 rounded-full bg-gradient-to-br from-fopcam-400 to-fopcam-600 flex items-center justify-center ring-2 ring-fopcam-200">
                          <UserIcon className="w-6 h-6 text-white" />
                        </div>
                      )}
                      <div>
                        <h2 className="text-xl font-bold text-gray-900">
                          {currentConversation?.other_user?.username || 'Conversation'}
                        </h2>
                        <div className="flex items-center gap-2 mt-1">
                          <div className={`w-2 h-2 rounded-full ${isConnected ? 'bg-green-500' : 'bg-red-500'}`}></div>
                          <span className="text-sm text-gray-600">
                            {isConnected ? 'En ligne' : 'Hors ligne'}
                          </span>
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <button className="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100 transition-colors">
                        <EllipsisHorizontalIcon className="w-5 h-5" />
                      </button>
                    </div>
                  </div>
                </div>
                <div className="flex-1 overflow-y-auto p-6 space-y-6">
                  {messages.length === 0 ? (
                    <div className="text-center py-12">
                      <ChatBubbleBottomCenterIcon className="w-16 h-16 mx-auto mb-4 text-gray-300" />
                      <h3 className="text-lg font-medium text-gray-900 mb-2">Aucun message</h3>
                      <p className="text-gray-600">Envoyez le premier message pour démarrer la conversation.</p>
                    </div>
                  ) : (
                    messages.map((message, index) => {
                      const isCurrentUser = message.user.id === currentUser?.id
                      const showAvatar = index === 0 || messages[index - 1].user.id !== message.user.id

                      return (
                        <div
                          key={message.id || index}
                          className={`flex ${isCurrentUser ? 'justify-end' : 'justify-start'} group`}
                        >
                          <div className={`flex gap-3 max-w-[70%] ${isCurrentUser ? 'flex-row-reverse' : ''}`}>
                            {showAvatar && (
                              message.user.profile_image ? (
                                <Link href={`/profile/${message.user.username}`}>
                                  <img
                                    src={buildMediaUrl(message.user.profile_image)}
                                    alt={message.user.username}
                                    className="w-10 h-10 rounded-full object-cover flex-shrink-0 ring-2 ring-gray-100 cursor-pointer hover:ring-fopcam-300 transition-colors"
                                  />
                                </Link>
                              ) : (
                                <Link href={`/profile/${message.user.username}`}>
                                  <div className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ring-2 ring-gray-100 cursor-pointer hover:ring-fopcam-300 transition-colors ${
                                    isCurrentUser
                                      ? 'bg-gradient-to-br from-fopcam-400 to-fopcam-600'
                                      : 'bg-gradient-to-br from-gray-400 to-gray-600'
                                  }`}>
                                    <UserIcon className="w-5 h-5 text-white" />
                                  </div>
                                </Link>
                              )
                            )}
                            {!showAvatar && <div className="w-10"></div>}
                            <div className={`rounded-2xl px-4 py-3 shadow-sm ${
                              isCurrentUser
                                ? 'bg-fopcam-500 text-white'
                                : 'bg-white text-gray-900 border border-gray-200'
                            }`}>
                              {!isCurrentUser && showAvatar && (
                                <div className="text-xs font-medium text-gray-600 mb-1">{message.user.username}</div>
                              )}
                              {message.message_type === 'audio' ? (
                                <div className="flex items-center gap-3">
                                  <button
                                    className={`p-2 rounded-full ${
                                      isCurrentUser ? 'bg-white/20 hover:bg-white/30' : 'bg-gray-100 hover:bg-gray-200'
                                    } transition-colors`}
                                    onClick={() => {
                                      const audio = new Audio(message.audio_file || `data:audio/wav;base64,${message.audio_data}`)
                                      audio.play()
                                    }}
                                  >
                                    <PlayIcon className={`w-4 h-4 ${isCurrentUser ? 'text-white' : 'text-gray-700'}`} />
                                  </button>
                                  <div className={`text-sm ${isCurrentUser ? 'text-white' : 'text-gray-900'}`}>
                                    Message vocal ({message.audio_duration || 0}s)
                                  </div>
                                </div>
                              ) : message.message_type === 'image' && message.attachment_file ? (
                                <div className="space-y-3">
                                  <img
                                    src={buildMediaUrl(message.attachment_file)}
                                    alt={message.attachment_name || 'Image'}
                                    className="rounded-2xl max-w-full object-cover"
                                  />
                                  {message.content && <div className="text-sm leading-relaxed">{renderLinkifiedText(message.content, isCurrentUser)}</div>}
                                </div>
                              ) : message.attachment_file ? (
                                <div className="space-y-3">
                                  <a
                                    href={buildMediaUrl(message.attachment_file)}
                                    target="_blank"
                                    rel="noreferrer"
                                    download={message.attachment_name || undefined}
                                    className={`inline-flex items-center gap-2 px-4 py-3 rounded-2xl border ${isCurrentUser ? 'border-white/30 bg-white/10 text-white' : 'border-gray-200 bg-gray-50 text-gray-900'} transition-colors`}
                                  >
                                    <span className="font-semibold">{message.attachment_name || 'Fichier'}</span>
                                  </a>
                                  {message.content && <div className="text-sm leading-relaxed">{renderLinkifiedText(message.content, isCurrentUser)}</div>}
                                </div>
                              ) : (
                                <div className="text-sm leading-relaxed">{renderLinkifiedText(message.content, isCurrentUser)}</div>
                              )}
                              <div className={`text-xs mt-2 ${
                                isCurrentUser ? 'text-fopcam-100' : 'text-gray-500'
                              }`}>
                                {formatMessageTime(message.created_at)}
                              </div>
                            </div>
                          </div>
                        </div>
                      )
                    })
                  )}
                  <div ref={messagesEndRef} />
                </div>

                {/* Message Input */}
                <div className="bg-white border-t border-gray-200 p-6">
                  {/* Mode Toggle */}
                  <div className="flex justify-center mb-4">
                    <div className="bg-gray-100 rounded-full p-1 flex">
                      <button
                        onClick={() => {
                          setMessageMode('text')
                          setAudioBlob(null)
                          setRecordingTime(0)
                          if (isRecording) {
                            cancelRecording()
                          }
                        }}
                        className={`px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 ${
                          messageMode === 'text'
                            ? 'bg-white text-fopcam-600 shadow-sm'
                            : 'text-gray-600 hover:text-gray-900'
                        }`}
                      >
                        📝 Texte
                      </button>
                      <button
                        onClick={() => {
                          setMessageMode('audio')
                          setNewMessage('')
                        }}
                        className={`px-4 py-2 rounded-full text-sm font-medium transition-all duration-200 ${
                          messageMode === 'audio'
                            ? 'bg-white text-fopcam-600 shadow-sm'
                            : 'text-gray-600 hover:text-gray-900'
                        }`}
                      >
                        🎤 Audio
                      </button>
                    </div>
                  </div>

                  <div className="flex gap-3">
                    {messageMode === 'text' ? (
                      <div className="flex-1 relative">
                        <input
                          ref={inputRef}
                          type="text"
                          value={newMessage}
                          onChange={(e) => {
                            setNewMessage(e.target.value)
                            sendTypingEvent()
                          }}
                          onKeyPress={(e) => e.key === 'Enter' && !e.shiftKey && sendMessage()}
                          placeholder={isConnected ? 'Tapez votre message...' : 'Connexion en cours...'}
                          className="w-full px-6 py-4 pr-28 border border-gray-300 rounded-full focus:outline-none focus:ring-2 focus:ring-fopcam-500 focus:border-transparent transition-all duration-200"
                          disabled={sending}
                        />
                        <input
                          type="file"
                          ref={fileInputRef}
                          className="hidden"
                          accept="image/*,video/*,audio/*,.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.zip"
                          onChange={handleFileChange}
                        />
                        <div className="absolute right-4 top-1/2 transform -translate-y-1/2 flex items-center gap-2">
                          <button
                            type="button"
                            onClick={() => fileInputRef.current?.click()}
                            className="p-2 text-gray-400 hover:text-fopcam-500 transition-colors rounded-full hover:bg-gray-100"
                          >
                            <PaperClipIcon className="w-5 h-5" />
                          </button>
                          <button
                            onClick={() => setShowEmojiPicker(!showEmojiPicker)}
                            className="p-2 text-gray-400 hover:text-fopcam-500 transition-colors rounded-full hover:bg-gray-100"
                            type="button"
                          >
                            <FaceSmileIcon className="w-5 h-5" />
                          </button>
                          {typing && (
                            <div className="flex space-x-1">
                              <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
                              <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{animationDelay: '0.1s'}}></div>
                              <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{animationDelay: '0.2s'}}></div>
                            </div>
                          )}
                        </div>
                        {showEmojiPicker && (
                          <div className="absolute bottom-full right-0 mb-2 z-50 emoji-picker-container">
                            <div className="bg-white border border-gray-200 rounded-xl shadow-xl p-2">
                              <EmojiPicker
                                onEmojiClick={onEmojiClick}
                                width={300}
                                height={400}
                                theme="light"
                                previewConfig={{ showPreview: false }}
                                skinTonesDisabled
                              />
                            </div>
                          </div>
                        )}
                        {attachmentFile && (
                          <div className="mt-3 rounded-2xl border border-gray-200 bg-gray-50 p-4 flex items-start gap-3">
                            {attachmentPreview ? (
                              attachmentType === 'image' ? (
                                <img src={attachmentPreview} alt={attachmentFile.name} className="w-16 h-16 rounded-xl object-cover" />
                              ) : (
                                <div className="w-16 h-16 rounded-xl bg-gray-200 flex items-center justify-center text-sm text-gray-600">
                                  {attachmentType === 'video' ? 'Vidéo' : attachmentType === 'audio' ? 'Audio' : 'Fichier'}
                                </div>
                              )
                            ) : (
                              <div className="w-16 h-16 rounded-xl bg-gray-200 flex items-center justify-center text-sm text-gray-600">
                                Fichier
                              </div>
                            )}
                            <div className="flex-1">
                              <div className="font-medium text-gray-900">{attachmentFile.name}</div>
                              <div className="text-xs text-gray-500">{attachmentType || 'document'}</div>
                            </div>
                            <button
                              type="button"
                              onClick={removeAttachment}
                              className="text-gray-400 hover:text-red-500 transition-colors"
                            >
                              ✕
                            </button>
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="flex-1 relative">
                        {audioBlob ? (
                          <div className="w-full px-6 py-4 border border-gray-300 rounded-full bg-gray-50 flex items-center justify-between">
                            <div className="flex items-center gap-3">
                              <button
                                onClick={() => {
                                  const audio = new Audio(URL.createObjectURL(audioBlob))
                                  audio.play()
                                }}
                                className="p-2 bg-fopcam-500 text-white rounded-full hover:bg-fopcam-600 transition-colors"
                              >
                                <PlayIcon className="w-4 h-4" />
                              </button>
                              <span className="text-sm text-gray-700">
                                Message vocal ({formatRecordingTime(recordingTime)})
                              </span>
                            </div>
                            <button
                              onClick={() => {
                                setAudioBlob(null)
                                setRecordingTime(0)
                              }}
                              className="p-2 text-gray-400 hover:text-red-500 transition-colors"
                            >
                              ✕
                            </button>
                          </div>
                        ) : isRecording ? (
                          <div className="w-full px-6 py-4 border border-red-300 rounded-full bg-red-50 flex items-center justify-between">
                            <div className="flex items-center gap-3">
                              <div className="w-3 h-3 bg-red-500 rounded-full animate-pulse"></div>
                              <span className="text-sm text-red-700 font-medium">
                                Enregistrement... {formatRecordingTime(recordingTime)}
                              </span>
                            </div>
                            <button
                              onClick={cancelRecording}
                              className="p-2 text-gray-400 hover:text-red-500 transition-colors"
                            >
                              ✕
                            </button>
                          </div>
                        ) : (
                          <div className="w-full px-6 py-4 border border-gray-300 rounded-full bg-gray-50 flex items-center justify-center">
                            <button
                              onClick={startRecording}
                              className="flex items-center gap-3 px-4 py-2 bg-fopcam-500 text-white rounded-full hover:bg-fopcam-600 transition-colors"
                            >
                              <MicrophoneIcon className="w-5 h-5" />
                              <span className="font-medium">Appuyez pour enregistrer</span>
                            </button>
                          </div>
                        )}
                      </div>
                    )}

                    {messageMode === 'audio' && isRecording ? (
                      <button
                        onClick={stopRecording}
                        className="px-6 py-4 bg-fopcam-500 text-white rounded-full hover:bg-fopcam-600 transition-all duration-200 shadow-lg hover:shadow-xl transform hover:scale-105"
                      >
                        <StopIcon className="w-5 h-5" />
                      </button>
                    ) : (
                      <button
                        onClick={sendMessage}
                        disabled={
                          (messageMode === 'text' && !newMessage.trim() && !attachmentFile) ||
                          (messageMode === 'audio' && !audioBlob) ||
                          sending
                        }
                        className="px-6 py-4 bg-fopcam-500 text-white rounded-full hover:bg-fopcam-600 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 shadow-lg hover:shadow-xl transform hover:scale-105"
                      >
                        {sending ? (
                          <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
                        ) : (
                          <PaperAirplaneIcon className="w-5 h-5" />
                        )}
                      </button>
                    )}
                  </div>
                  <div className="flex items-center justify-between mt-3">
                    <div className="text-xs text-gray-500">
                      {messageMode === 'text'
                        ? 'Appuyez sur Entrée pour envoyer'
                        : isRecording
                          ? 'Cliquez sur stop pour terminer'
                          : audioBlob
                            ? 'Cliquez sur envoyer pour partager'
                            : 'Cliquez sur le micro pour enregistrer'
                      }
                    </div>
                    {!isConnected && (
                      <div className="text-xs text-orange-600 flex items-center gap-1">
                        <WifiIcon className="w-3 h-3" />
                        Mode hors ligne
                      </div>
                    )}
                  </div>
                </div>
              </>
            ) : (
              <div className="flex-1 flex items-center justify-center bg-gradient-to-br from-gray-50 to-gray-100">
                <div className="text-center max-w-md">
                  <div className="bg-white rounded-full w-24 h-24 flex items-center justify-center mx-auto mb-6 shadow-lg">
                    <ChatBubbleBottomCenterIcon className="w-12 h-12 text-fopcam-500" />
                  </div>
                  <h3 className="text-2xl font-bold text-gray-900 mb-3">Bienvenue dans vos messages</h3>
                  <p className="text-gray-600 leading-relaxed">
                    Sélectionnez une conversation dans la liste pour voir les messages ou démarrez une nouvelle conversation avec un utilisateur.
                  </p>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

export default MessagesPage