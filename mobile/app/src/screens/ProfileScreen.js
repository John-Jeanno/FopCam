import React, { useEffect, useState } from 'react'
import { View, Text, Button, StyleSheet, ActivityIndicator } from 'react-native'
import { getProfile, logout } from '../services/api'

export default function ProfileScreen({ navigation }) {
  const [profile, setProfile] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const load = async () => {
      try {
        const response = await getProfile()
        setProfile(response.data)
      } catch (error) {
        console.warn('Load profile error', error)
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  const handleLogout = async () => {
    await logout()
    navigation.replace('Login')
  }

  if (loading) {
    return (
      <View style={styles.loader}>
        <ActivityIndicator size="large" color="#7c3aed" />
      </View>
    )
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Mon Profil</Text>
      <Text style={styles.label}>Utilisateur :</Text>
      <Text style={styles.value}>{profile?.user?.username || 'Anonymous'}</Text>
      <Text style={styles.label}>Email :</Text>
      <Text style={styles.value}>{profile?.user?.email || '-'}</Text>
      <Button title="Déconnexion" onPress={handleLogout} />
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
    backgroundColor: '#0f172a'
  },
  loader: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#0f172a'
  },
  title: {
    fontSize: 28,
    color: '#f8fafc',
    fontWeight: 'bold',
    marginBottom: 24
  },
  label: {
    color: '#cbd5e1',
    marginTop: 12,
    fontSize: 14
  },
  value: {
    color: '#f8fafc',
    fontSize: 18,
    marginBottom: 8
  }
})
