import React from 'react'
import { View, Text, Button, StyleSheet } from 'react-native'

export default function CartScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Panier</Text>
      <Text style={styles.message}>Le panier est en cours de construction.</Text>
      <Button title="Continuer" onPress={() => {}} />
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#0f172a'
  },
  title: {
    fontSize: 24,
    color: '#f8fafc',
    marginBottom: 12
  },
  message: {
    color: '#cbd5e1',
    marginBottom: 20,
    textAlign: 'center'
  }
})
