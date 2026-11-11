import { useEffect, useRef, useState } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'
import { ArrowLeftIcon, PaperAirplaneIcon } from '@heroicons/react/24/outline'

export default function ChatRoom(){
  const router = useRouter();
  const { room } = router.query
  const wsRef = useRef(null)
  const reconnectTimerRef = useRef(null)
  const messagesEndRef = useRef(null)
  const [messages, setMessages] = useState([])
  const [text, setText] = useState('')
  const [isConnected, setIsConnected] = useState(false)
  const [user, setUser] = useState(null)
  const [connectionError, setConnectionError] = useState(null)
  const [reconnectAttempts, setReconnectAttempts] = useState(0)
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" })
  }

  const normalizeUrl = (url) => {
    if (!url) return url
    return url.startsWith('www.') ? `https://${url}` : url
  }

  const renderLinkifiedText = (text, isCurrentUser = false) => {
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
  }

  useEffect(() => {
    scrollToBottom()
  }, [messages])

  useEffect(()=>{
    if(!room) return

    const token = localStorage.getItem('access')

    const loadUser = async () => {
      try {
        const headers = token ? { Authorization: `Bearer ${token}` } : {}
        const res = await fetch(`${apiUrl}/api/auth/profile/`, {
          headers,
          credentials: 'include',
        })
        if (res.ok) {
          const userData = await res.json()
          setUser(userData.user || userData)
        } else if (res.status === 401) {
          router.push('/login?next=' + encodeURIComponent('/chat/' + room))
        }
      } catch (err) {
        console.error('Failed to load user:', err)
      }
    }

    const loadMessages = async () => {
      try {
        // Normalize room name: replace hyphens with underscores for backend compatibility
        const normalizedRoom = room.replace(/-/g, '_')
        const headers = token ? { Authorization: `Bearer ${token}` } : {}
        const res = await fetch(`${apiUrl}/api/messages/?room=${encodeURIComponent(normalizedRoom)}`, {
          headers,
          credentials: 'include',
        })
        if (res.ok) {
          const messagesData = await res.json()
          const formattedMessages = (Array.isArray(messagesData) ? messagesData : messagesData.results || [])
            .map(msg => ({
              message: msg.content,
              user: msg.user.username,
              timestamp: new Date(msg.created_at).toLocaleTimeString()
            }))
          setMessages(formattedMessages)
        }
      } catch (err) {
        console.error('Failed to load messages:', err)
      }
    }

    const connectWebSocket = () => {
      // Normalize room name: replace hyphens with underscores for backend compatibility
      const normalizedRoom = room.replace(/-/g, '_')
      const tokenQuery = token ? `?token=${encodeURIComponent(token)}` : ''
      const wsUrl = `${apiUrl.replace(/^http/, 'ws')}/ws/chat/${encodeURIComponent(normalizedRoom)}/${tokenQuery}`
      wsRef.current = new WebSocket(wsUrl)
      setConnectionError(null)

      wsRef.current.onopen = () => {
        setIsConnected(true)
        setConnectionError(null)
      }

      wsRef.current.onmessage = e => {
        try {
          const data = JSON.parse(e.data)
          if (data.error) {
            console.error('WebSocket error:', data.error)
            setConnectionError(data.error)
            return
          }

          const eventType = data.event || data.event_type
          if (eventType === 'typing') {
            return
          }

          setMessages(m => [...m, data])
        } catch (err) {
          console.error('Malformed WebSocket message:', err)
        }
      }

      wsRef.current.onclose = (event) => {
        setIsConnected(false)
        setConnectionError(`Connexion websocket interrompue (${event.code}). Reconnexion...`)
        console.error('WebSocket closed:', event)
        if (reconnectTimerRef.current) {
          clearTimeout(reconnectTimerRef.current)
        }
        reconnectTimerRef.current = setTimeout(() => {
          setReconnectAttempts(prev => prev + 1)
          connectWebSocket()
        }, 2500)
      }

      wsRef.current.onerror = (error) => {
        console.error('WebSocket error:', error)
        setConnectionError('Erreur de connexion au serveur de chat. Reconnexion...')
        setIsConnected(false)
      }
    }

    loadUser()
    loadMessages()
    connectWebSocket()

    return () => {
      if (reconnectTimerRef.current) {
        clearTimeout(reconnectTimerRef.current)
      }
      if (wsRef.current) {
        wsRef.current.close()
      }
    }
  },[room])

  const send = async () => {
    if (!text.trim()) return

    const token = localStorage.getItem('access')
    const normalizedRoom = room.replace(/-/g, '_')
    const wsPayload = { room: normalizedRoom, message: text.trim(), message_type: 'text' }
    const apiPayload = { room: normalizedRoom, content: text.trim(), message_type: 'text' }

    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(wsPayload))
    } else {
      try {
        const headers = token ? {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`
        } : { 'Content-Type': 'application/json' }

        const res = await fetch(`${apiUrl}/api/messages/`, {
          method: 'POST',
          headers,
          body: JSON.stringify(apiPayload),
          credentials: 'include',
        })
        if (res.ok) {
          const msg = await res.json()
          setMessages(prev => [...prev, { message: msg.content, user: msg.user.username, timestamp: new Date(msg.created_at).toLocaleTimeString() }])
        } else {
          console.error('Fallback API send failed', res.status)
          setConnectionError('Impossible d’envoyer le message. Réessayez.')
        }
      } catch (err) {
        console.error('Fallback API send error:', err)
        setConnectionError('Impossible d’envoyer le message. Réessayez.')
      }
    }

    setText('')
  }

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      send()
    }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-4xl mx-auto px-4 py-4">
          <div className="flex items-center gap-4">
            <Link href="/chat" className="p-2 hover:bg-gray-100 rounded-full">
              <ArrowLeftIcon className="w-5 h-5" />
            </Link>
            <div>
              <h1 className="text-lg font-semibold text-gray-900">Salle: {room}</h1>
              <p className="text-sm text-gray-500">
                {isConnected ? '🟢 Connecté' : '🔴 Déconnecté'} • {user ? user.username : 'Chargement...'}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 max-w-4xl mx-auto p-4">
        <div className="bg-white rounded-lg shadow-sm h-[calc(100vh-200px)] flex flex-col">
          <div className="flex-1 overflow-y-auto p-4 space-y-4">
            {messages.length === 0 ? (
              <div className="text-center text-gray-500 py-8">
                <p>Aucun message pour le moment.</p>
                <p className="text-sm">Soyez le premier à envoyer un message !</p>
              </div>
            ) : (
              messages.map((m,i)=>(
                <div key={i} className={`flex ${m.user === user?.username ? 'justify-end' : 'justify-start'}`}>
                  <div className={`max-w-xs lg:max-w-md px-4 py-2 rounded-lg ${
                    m.user === user?.username
                      ? 'bg-fopcam-500 text-white'
                      : 'bg-gray-200 text-gray-900'
                  }`}>
                    <div className="text-xs opacity-75 mb-1">{m.user}</div>
                    <div>{renderLinkifiedText(m.message, m.user === user?.username)}</div>
                    <div className="text-xs opacity-75 mt-1">{m.timestamp || 'Maintenant'}</div>
                  </div>
                </div>
              ))
            )}
            <div ref={messagesEndRef} />
          </div>

          {/* Message Input */}
          <div className="border-t p-4">
            <div className="flex gap-2">
              <input
                type="text"
                value={text}
                onChange={e=>setText(e.target.value)}
                onKeyPress={handleKeyPress}
                placeholder={isConnected ? 'Tapez votre message...' : 'Connexion au chat en cours... (envoi via API possible)'}
                className="flex-1 px-4 py-2 border border-gray-300 rounded-full focus:outline-none focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
              />
              <button
                onClick={send}
                disabled={!text.trim()}
                className="px-4 py-2 bg-fopcam-600 text-white rounded-full hover:bg-fopcam-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
              >
                <PaperAirplaneIcon className="w-5 h-5" />
              </button>
            </div>
            {connectionError && (
              <p className="text-sm text-red-500 mt-2">{connectionError}</p>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
