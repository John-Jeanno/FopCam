import { io } from 'socket.io-client';

class RealtimeService {
  constructor() {
    this.socket = null;
    this.isConnected = false;
    this.listeners = new Map();
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 1;
    this.reconnectDelay = 1000;
    this.disabled = false;
  }

  connect(userId, token) {
    if (this.socket?.connected || this.disabled) {
      return;
    }

    const wsUrl = process.env.NEXT_PUBLIC_WS_URL || 'http://127.0.0.1:8000';

    this.socket = io(wsUrl, {
      auth: {
        token: token,
        userId: userId
      },
      transports: ['websocket', 'polling'],
      timeout: 3000,
      forceNew: true,
      reconnection: false,
    });

    this.socket.on('connect', () => {
      console.log('🔗 Connecté aux WebSockets');
      this.isConnected = true;
      this.reconnectAttempts = 0;
      this.emit('connected');
    });

    this.socket.on('disconnect', (reason) => {
      console.log('🔌 Déconnecté des WebSockets:', reason);
      this.isConnected = false;
      this.emit('disconnected', reason);

      // Tentative de reconnexion automatique
      if (reason === 'io server disconnect' || reason === 'io client disconnect') {
        this.attemptReconnect(userId, token);
      }
    });

    this.socket.on('connect_error', (error) => {
      console.error('❌ Erreur de connexion WebSocket (service désactivé):', error.message);
      this.isConnected = false;
      this.disabled = true;
      this.emit('connection_error', error);
    });

    // Événements de notifications temps réel
    this.socket.on('notification', (data) => {
      console.log('🔔 Nouvelle notification:', data);
      this.emit('notification', data);
    });

    this.socket.on('post_liked', (data) => {
      console.log('❤️ Post liké:', data);
      this.emit('post_liked', data);
    });

    this.socket.on('post_commented', (data) => {
      console.log('💬 Post commenté:', data);
      this.emit('post_commented', data);
    });

    this.socket.on('post_shared', (data) => {
      console.log('🔄 Post partagé:', data);
      this.emit('post_shared', data);
    });

    this.socket.on('new_post', (data) => {
      console.log('📝 Nouveau post:', data);
      this.emit('new_post', data);
    });

    this.socket.on('message_received', (data) => {
      console.log('💌 Nouveau message:', data);
      this.emit('message_received', data);
    });

    this.socket.on('friend_request', (data) => {
      console.log('👥 Nouvelle demande d\'ami:', data);
      this.emit('friend_request', data);
    });

    this.socket.on('friend_accepted', (data) => {
      console.log('🤝 Demande d\'ami acceptée:', data);
      this.emit('friend_accepted', data);
    });
  }

  attemptReconnect(userId, token) {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('❌ Nombre maximum de tentatives de reconnexion atteint');
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);

    console.log(`🔄 Tentative de reconnexion ${this.reconnectAttempts}/${this.maxReconnectAttempts} dans ${delay}ms`);

    setTimeout(() => {
      this.connect(userId, token);
    }, delay);
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
      this.isConnected = false;
    }
  }

  // Méthodes d'émission d'événements
  emit(event, data) {
    const listeners = this.listeners.get(event) || [];
    listeners.forEach(callback => {
      try {
        callback(data);
      } catch (error) {
        console.error(`Erreur dans le listener ${event}:`, error);
      }
    });
  }

  on(event, callback) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    this.listeners.get(event).push(callback);
  }

  off(event, callback) {
    const listeners = this.listeners.get(event) || [];
    const index = listeners.indexOf(callback);
    if (index > -1) {
      listeners.splice(index, 1);
    }
  }

  // Méthodes spécifiques pour les actions utilisateur
  sendMessage(roomId, content, messageType = 'text') {
    if (this.socket?.connected) {
      this.socket.emit('send_message', {
        room: roomId,
        content: content,
        message_type: messageType
      });
    }
  }

  joinRoom(roomId) {
    if (this.socket?.connected) {
      this.socket.emit('join_room', { room: roomId });
    }
  }

  leaveRoom(roomId) {
    if (this.socket?.connected) {
      this.socket.emit('leave_room', { room: roomId });
    }
  }

  markNotificationAsRead(notificationId) {
    if (this.socket?.connected) {
      this.socket.emit('mark_notification_read', { notification_id: notificationId });
    }
  }

  // Méthodes utilitaires
  getConnectionStatus() {
    return {
      isConnected: this.isConnected,
      reconnectAttempts: this.reconnectAttempts,
      socketId: this.socket?.id
    };
  }
}

// Instance globale
const realtimeService = new RealtimeService();

export default realtimeService;