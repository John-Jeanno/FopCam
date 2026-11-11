import React, { useEffect, useState } from 'react'
import { View, Text, Button, StyleSheet, ActivityIndicator, ScrollView } from 'react-native'
import { fetchProduct } from '../services/api'

export default function ProductScreen({ route, navigation }) {
  const { id } = route.params
  const [product, setProduct] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const load = async () => {
      try {
        const response = await fetchProduct(id)
        setProduct(response.data)
      } catch (error) {
        console.warn('Load product error', error)
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [id])

  if (loading) {
    return (
      <View style={styles.loader}>
        <ActivityIndicator size="large" color="#7c3aed" />
      </View>
    )
  }

  if (!product) {
    return (
      <View style={styles.container}>
        <Text style={styles.errorText}>Produit introuvable.</Text>
      </View>
    )
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>{product.title}</Text>
      <Text style={styles.price}>{product.price} FCFA</Text>
      <Text style={styles.category}>{product.category?.name || 'Sans catégorie'}</Text>
      <Text style={styles.description}>{product.description}</Text>
      <Button title="Ajouter au panier" onPress={() => navigation.navigate('Cart')} />
    </ScrollView>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f172a'
  },
  content: {
    padding: 16
  },
  loader: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#0f172a'
  },
  title: {
    fontSize: 24,
    color: '#f8fafc',
    fontWeight: 'bold',
    marginBottom: 12
  },
  price: {
    fontSize: 20,
    color: '#a5b4fc',
    marginBottom: 8
  },
  category: {
    color: '#c7d2fe',
    marginBottom: 16
  },
  description: {
    color: '#e2e8f0',
    lineHeight: 22,
    marginBottom: 24
  },
  errorText: {
    color: '#f87171',
    fontSize: 18,
    textAlign: 'center',
    marginTop: 24
  }
})
