import * as tf from '@tensorflow/tfjs';
import * as use from '@tensorflow-models/universal-sentence-encoder';

class RecommendationEngine {
  constructor() {
    this.model = null;
    this.userEmbeddings = new Map();
    this.postEmbeddings = new Map();
    this.interactionHistory = new Map();
  }

  async initialize() {
    try {
      // Charger le modèle Universal Sentence Encoder
      this.model = await use.load();
      console.log('Modèle TensorFlow.js chargé avec succès');
    } catch (error) {
      console.error('Erreur lors du chargement du modèle:', error);
    }
  }

  async generateEmbedding(text) {
    if (!this.model) await this.initialize();

    try {
      const embeddings = await this.model.embed([text]);
      return embeddings.arraySync()[0];
    } catch (error) {
      console.error('Erreur lors de la génération d\'embedding:', error);
      return null;
    }
  }

  async addUserInteraction(userId, postId, interactionType, postContent = '') {
    // Enregistrer l'interaction
    if (!this.interactionHistory.has(userId)) {
      this.interactionHistory.set(userId, []);
    }

    this.interactionHistory.get(userId).push({
      postId,
      interactionType, // 'like', 'comment', 'share', 'view'
      timestamp: Date.now(),
      weight: this.getInteractionWeight(interactionType)
    });

    // Générer l'embedding du post si pas déjà fait
    if (postContent && !this.postEmbeddings.has(postId)) {
      const embedding = await this.generateEmbedding(postContent);
      if (embedding) {
        this.postEmbeddings.set(postId, embedding);
      }
    }

    // Mettre à jour l'embedding utilisateur
    await this.updateUserEmbedding(userId);
  }

  getInteractionWeight(interactionType) {
    const weights = {
      'view': 0.1,
      'like': 0.5,
      'comment': 0.8,
      'share': 1.0
    };
    return weights[interactionType] || 0.1;
  }

  async updateUserEmbedding(userId) {
    const interactions = this.interactionHistory.get(userId) || [];
    if (interactions.length === 0) return;

    // Calculer l'embedding moyen pondéré des posts avec lesquels l'utilisateur a interagi
    let totalWeight = 0;
    let weightedSum = new Array(512).fill(0); // Dimension de USE

    for (const interaction of interactions) {
      const postEmbedding = this.postEmbeddings.get(interaction.postId);
      if (postEmbedding) {
        const weight = interaction.weight;
        totalWeight += weight;

        for (let i = 0; i < postEmbedding.length; i++) {
          weightedSum[i] += postEmbedding[i] * weight;
        }
      }
    }

    if (totalWeight > 0) {
      const userEmbedding = weightedSum.map(val => val / totalWeight);
      this.userEmbeddings.set(userId, userEmbedding);
    }
  }

  async getRecommendations(userId, availablePosts, limit = 10) {
    const userEmbedding = this.userEmbeddings.get(userId);
    if (!userEmbedding) {
      // Si pas d'embedding utilisateur, retourner les posts les plus populaires
      return this.getPopularPosts(availablePosts, limit);
    }

    const recommendations = [];

    for (const post of availablePosts) {
      const postEmbedding = this.postEmbeddings.get(post.id);
      if (postEmbedding) {
        // Calculer la similarité cosinus
        const similarity = this.cosineSimilarity(userEmbedding, postEmbedding);

        // Calculer le score final (similarité + popularité + récence)
        const popularityScore = Math.log(post.likes_count + post.comments_count + post.shares_count + 1);
        const recencyScore = Math.max(0, 1 - (Date.now() - new Date(post.created_at).getTime()) / (7 * 24 * 60 * 60 * 1000)); // 7 jours

        const finalScore = similarity * 0.6 + popularityScore * 0.3 + recencyScore * 0.1;

        recommendations.push({
          ...post,
          recommendationScore: finalScore,
          similarityScore: similarity
        });
      }
    }

    // Trier par score de recommandation décroissant
    recommendations.sort((a, b) => b.recommendationScore - a.recommendationScore);

    return recommendations.slice(0, limit);
  }

  cosineSimilarity(vecA, vecB) {
    let dotProduct = 0;
    let normA = 0;
    let normB = 0;

    for (let i = 0; i < vecA.length; i++) {
      dotProduct += vecA[i] * vecB[i];
      normA += vecA[i] * vecA[i];
      normB += vecB[i] * vecB[i];
    }

    normA = Math.sqrt(normA);
    normB = Math.sqrt(normB);

    if (normA === 0 || normB === 0) return 0;

    return dotProduct / (normA * normB);
  }

  getPopularPosts(posts, limit) {
    return posts
      .sort((a, b) => {
        const scoreA = a.likes_count + a.comments_count + a.shares_count;
        const scoreB = b.likes_count + b.comments_count + b.shares_count;
        return scoreB - scoreA;
      })
      .slice(0, limit);
  }

  async getSimilarPosts(postId, availablePosts, limit = 5) {
    const targetEmbedding = this.postEmbeddings.get(postId);
    if (!targetEmbedding) return [];

    const similarities = [];

    for (const post of availablePosts) {
      if (post.id === postId) continue;

      const postEmbedding = this.postEmbeddings.get(post.id);
      if (postEmbedding) {
        const similarity = this.cosineSimilarity(targetEmbedding, postEmbedding);
        similarities.push({
          ...post,
          similarity: similarity
        });
      }
    }

    return similarities
      .sort((a, b) => b.similarity - a.similarity)
      .slice(0, limit);
  }

  // Méthode pour sauvegarder/charger l'état des embeddings
  exportState() {
    return {
      userEmbeddings: Array.from(this.userEmbeddings.entries()),
      postEmbeddings: Array.from(this.postEmbeddings.entries()),
      interactionHistory: Array.from(this.interactionHistory.entries())
    };
  }

  importState(state) {
    this.userEmbeddings = new Map(state.userEmbeddings || []);
    this.postEmbeddings = new Map(state.postEmbeddings || []);
    this.interactionHistory = new Map(state.interactionHistory || []);
  }
}

// Instance globale
const recommendationEngine = new RecommendationEngine();

export default recommendationEngine;