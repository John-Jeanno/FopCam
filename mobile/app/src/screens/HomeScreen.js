import React, { useEffect, useState } from 'react'
import { View, Text, Button, FlatList, TouchableOpacity, StyleSheet, ActivityIndicator, Linking } from 'react-native'
import { fetchProducts } from '../services/api'

export default function HomeScreen({ navigation }) {
  const [products, setProducts] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const load = async () => {
      try {
        const response = await fetchProducts({ page_size: 20 })
        setProducts(response.data.results || response.data)
      } catch (error) {
        console.warn('Load products error', error)
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  const renderItem = ({ item }) => (
    <TouchableOpacity style={styles.card} onPress={() => navigation.navigate('Product', { id: item.id })}>
      <Text style={styles.productTitle}>{item.title}</Text>
      <Text style={styles.productPrice}>{item.price} FCFA</Text>
    </TouchableOpacity>
  )

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View style={{flexDirection: 'row', alignItems: 'center'}}>
          <Text style={styles.title}>FopCam</Text>
        </View>
        <View style={{flexDirection: 'row', alignItems: 'center'}}>
          <TouchableOpacity onPress={() => Linking.openURL('http://localhost:3000/game')} style={{marginRight:12}}>
            <Text style={{fontSize:20}}>🎮</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={() => navigation.navigate('Cart')} style={{marginRight:12}}>
            <Text style={{fontSize:20}}>🛒</Text>
          </TouchableOpacity>
          <Button title="Profil" onPress={() => navigation.navigate('Profile')} />
        </View>
      </View>
      {loading ? (
        <ActivityIndicator size="large" color="#7c3aed" />
      ) : (
        <FlatList
          data={products}
          keyExtractor={(item) => item.id.toString()}
          renderItem={renderItem}
          contentContainerStyle={styles.list}
        />
      )}
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f172a',
    padding: 16
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16
  },
  title: {
    color: '#f8fafc',
    fontSize: 28,
    fontWeight: 'bold'
  },
  list: {
    paddingBottom: 32
  },
  card: {
    backgroundColor: '#111827',
    padding: 18,
    borderRadius: 18,
    marginBottom: 12
  },
  productTitle: {
    color: '#f8fafc',
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 6
  },
  productPrice: {
    color: '#a5b4fc',
    fontSize: 14
  }
})
