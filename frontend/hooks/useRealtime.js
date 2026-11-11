import { useState, useEffect, useCallback, useRef } from 'react';
import realtimeService from '../utils/realtimeService';

export function useRealtime(userId, token) {
  const [isConnected, setIsConnected] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState('disconnected');
  const listenersRef = useRef(new Map());

  useEffect(() => {
    if (userId && token) {
      // Connexion au service temps réel
      realtimeService.connect(userId, token);

      // Écouteurs d'événements de connexion
      const handleConnected = () => {
        setIsConnected(true);
        setConnectionStatus('connected');
      };

      const handleDisconnected = (reason) => {
        setIsConnected(false);
        setConnectionStatus('disconnected');
      };

      const handleConnectionError = (error) => {
        setIsConnected(false);
        setConnectionStatus('error');
      };

      realtimeService.on('connected', handleConnected);
      realtimeService.on('disconnected', handleDisconnected);
      realtimeService.on('connection_error', handleConnectionError);

      // Cleanup
      return () => {
        realtimeService.off('connected', handleConnected);
        realtimeService.off('disconnected', handleDisconnected);
        realtimeService.off('connection_error', handleConnectionError);
        realtimeService.disconnect();
      };
    }
  }, [userId, token]);

  const on = useCallback((event, callback) => {
    const wrappedCallback = (data) => {
      // Ajouter un timestamp pour les notifications
      const enhancedData = {
        ...data,
        timestamp: new Date().toISOString(),
        isRealtime: true
      };
      callback(enhancedData);
    };

    listenersRef.current.set(event, wrappedCallback);
    realtimeService.on(event, wrappedCallback);

    // Cleanup function
    return () => {
      realtimeService.off(event, wrappedCallback);
      listenersRef.current.delete(event);
    };
  }, []);

  const sendMessage = useCallback((roomId, content, messageType = 'text') => {
    realtimeService.sendMessage(roomId, content, messageType);
  }, []);

  const joinRoom = useCallback((roomId) => {
    realtimeService.joinRoom(roomId);
  }, []);

  const leaveRoom = useCallback((roomId) => {
    realtimeService.leaveRoom(roomId);
  }, []);

  const markNotificationAsRead = useCallback((notificationId) => {
    realtimeService.markNotificationAsRead(notificationId);
  }, []);

  return {
    isConnected,
    connectionStatus,
    on,
    sendMessage,
    joinRoom,
    leaveRoom,
    markNotificationAsRead
  };
}

export function useRealtimeNotifications(userId, token) {
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const { on, isConnected } = useRealtime(userId, token);

  useEffect(() => {
    // Ne s'exécuter que côté client
    if (typeof window === 'undefined') return;
    if (!isConnected) return;

    // Écouter les nouvelles notifications
    const unsubscribeNotification = on('notification', (data) => {
      setNotifications(prev => [data, ...prev]);
      setUnreadCount(prev => prev + 1);
    });

    // Écouter les likes temps réel
    const unsubscribeLike = on('post_liked', (data) => {
      setNotifications(prev => [{
        id: `like_${Date.now()}`,
        type: 'like',
        message: `${data.username} a aimé votre publication`,
        postId: data.post_id,
        timestamp: data.timestamp,
        isRealtime: true
      }, ...prev]);
      setUnreadCount(prev => prev + 1);
    });

    // Écouter les commentaires temps réel
    const unsubscribeComment = on('post_commented', (data) => {
      setNotifications(prev => [{
        id: `comment_${Date.now()}`,
        type: 'comment',
        message: `${data.username} a commenté votre publication`,
        postId: data.post_id,
        timestamp: data.timestamp,
        isRealtime: true
      }, ...prev]);
      setUnreadCount(prev => prev + 1);
    });

    // Écouter les partages temps réel
    const unsubscribeShare = on('post_shared', (data) => {
      setNotifications(prev => [{
        id: `share_${Date.now()}`,
        type: 'share',
        message: `${data.username} a partagé votre publication`,
        postId: data.post_id,
        timestamp: data.timestamp,
        isRealtime: true
      }, ...prev]);
      setUnreadCount(prev => prev + 1);
    });

    // Écouter les nouveaux messages
    const unsubscribeMessage = on('message_received', (data) => {
      setNotifications(prev => [{
        id: `message_${Date.now()}`,
        type: 'message',
        message: `Nouveau message de ${data.sender_username}`,
        roomId: data.room_id,
        timestamp: data.timestamp,
        isRealtime: true
      }, ...prev]);
      setUnreadCount(prev => prev + 1);
    });

    // Écouter les demandes d'ami
    const unsubscribeFriendRequest = on('friend_request', (data) => {
      setNotifications(prev => [{
        id: `friend_request_${Date.now()}`,
        type: 'friend_request',
        message: `${data.sender_username} vous a envoyé une demande d'ami`,
        senderId: data.sender_id,
        timestamp: data.timestamp,
        isRealtime: true
      }, ...prev]);
      setUnreadCount(prev => prev + 1);
    });

    return () => {
      unsubscribeNotification?.();
      unsubscribeLike?.();
      unsubscribeComment?.();
      unsubscribeShare?.();
      unsubscribeMessage?.();
      unsubscribeFriendRequest?.();
    };
  }, [on, isConnected]);

  const markAsRead = useCallback((notificationId) => {
    setNotifications(prev =>
      prev.map(notif =>
        notif.id === notificationId
          ? { ...notif, read: true }
          : notif
      )
    );
    setUnreadCount(prev => Math.max(0, prev - 1));
  }, []);

  const clearAll = useCallback(() => {
    setNotifications([]);
    setUnreadCount(0);
  }, []);

  return {
    notifications,
    unreadCount,
    markAsRead,
    clearAll,
    isConnected
  };
}