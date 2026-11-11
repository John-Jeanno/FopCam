import { useState, useEffect, useCallback } from 'react';
import recommendationEngine from '../utils/recommendationEngine';

export function useRecommendations(userId) {
  const [isInitialized, setIsInitialized] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    const initializeEngine = async () => {
      if (!isInitialized) {
        await recommendationEngine.initialize();
        setIsInitialized(true);
      }
    };

    initializeEngine();
  }, [isInitialized]);

  const addInteraction = useCallback(async (postId, interactionType, postContent = '') => {
    if (userId && isInitialized) {
      await recommendationEngine.addUserInteraction(userId, postId, interactionType, postContent);
    }
  }, [userId, isInitialized]);

  const getRecommendations = useCallback(async (availablePosts, limit = 10) => {
    if (!isInitialized || !userId) {
      // Retourner les posts populaires si le moteur n'est pas prêt
      return recommendationEngine.getPopularPosts(availablePosts, limit);
    }

    setIsLoading(true);
    try {
      const recommendations = await recommendationEngine.getRecommendations(userId, availablePosts, limit);
      return recommendations;
    } finally {
      setIsLoading(false);
    }
  }, [userId, isInitialized]);

  const getSimilarPosts = useCallback(async (postId, availablePosts, limit = 5) => {
    if (!isInitialized) return [];

    return await recommendationEngine.getSimilarPosts(postId, availablePosts, limit);
  }, [isInitialized]);

  return {
    isInitialized,
    isLoading,
    addInteraction,
    getRecommendations,
    getSimilarPosts
  };
}

export function usePostEmbedding(postId, content) {
  const [embedding, setEmbedding] = useState(null);

  useEffect(() => {
    const generateEmbedding = async () => {
      if (content && !recommendationEngine.postEmbeddings.has(postId)) {
        const emb = await recommendationEngine.generateEmbedding(content);
        if (emb) {
          setEmbedding(emb);
        }
      }
    };

    generateEmbedding();
  }, [postId, content]);

  return embedding;
}