import { useState, useEffect } from 'react'
import Link from 'next/link'

export default function Cart(){
  const [cart, setCart] = useState([])
  const [paymentMethod, setPaymentMethod] = useState('cash_on_delivery')
  const [paymentPhone, setPaymentPhone] = useState('')
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState(null)
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  useEffect(()=>{
    setCart(JSON.parse(localStorage.getItem('cart')||'[]'))
  },[])

  const remove = i => { cart.splice(i,1); setCart([...cart]); localStorage.setItem('cart', JSON.stringify(cart)) }

  const checkout = async ()=>{
    // Tokens are now in httpOnly cookies, automatically included in requests
    if((paymentMethod === 'wave' || paymentMethod === 'orange_money') && !paymentPhone){
      alert('Veuillez renseigner votre numéro pour le paiement mobile.')
      return
    }
    const items = cart.map(c=>({product:c.product_id, quantity:c.qty, price:c.price}))
    const total = items.reduce((s,i)=>s + i.price * i.quantity, 0)
    setLoading(true)
    try {
      const res = await fetch(apiUrl + '/api/orders/',{
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({items, total, payment_method: paymentMethod, payment_phone: paymentPhone})
      })
      if(!res.ok){
        const err = await res.text()
        throw new Error(err || 'Erreur de commande')
      }
      const order = await res.json()
      if(paymentMethod === 'wave' || paymentMethod === 'orange_money'){
        const provider = paymentMethod === 'wave' ? 'wave' : 'orange'
        const paymentRes = await fetch(apiUrl + '/api/payments/create_payment/', {
          method:'POST',
          headers:{'Content-Type':'application/json'},
          body:JSON.stringify({order: order.id, provider})
        })
        if(!paymentRes.ok){
          const err = await paymentRes.text()
          throw new Error(err || 'Erreur de paiement')
        }
        const paymentData = await paymentRes.json()
        setMessage('Commande créée. Vous allez être redirigé vers le paiement.')
        window.location.href = paymentData.payment_url
      } else {
        localStorage.removeItem('cart')
        setCart([])
        setMessage('Commande créée. Paiement à la livraison choisi.')
      }
    } catch (error) {
      console.error(error)
      alert(error.message || 'Erreur lors de la commande')
    } finally {
      setLoading(false)
    }
  }

  return (
    <main style={{padding:20}}>
      <h1>Panier</h1>
      {cart.length===0 && <p>Panier vide</p>}
      <ul>
        {cart.map((c,i)=> (
          <li key={i}>{c.title} — {c.price} FCFA x {c.qty} <button onClick={()=>remove(i)}>Suppr</button></li>
        ))}
      </ul>
      <div style={{marginTop:12, marginBottom:12}}>
        <label>
          <input type="radio" name="payment" value="cash_on_delivery" checked={paymentMethod === 'cash_on_delivery'} onChange={() => setPaymentMethod('cash_on_delivery')} />
          Paiement à la livraison (espèces)
        </label>
        <br />
        <label>
          <input type="radio" name="payment" value="wave" checked={paymentMethod === 'wave'} onChange={() => setPaymentMethod('wave')} />
          Payer avec Wave
        </label>
        <br />
        <label>
          <input type="radio" name="payment" value="orange_money" checked={paymentMethod === 'orange_money'} onChange={() => setPaymentMethod('orange_money')} />
          Payer avec Orange Money
        </label>
      </div>
      {(paymentMethod === 'wave' || paymentMethod === 'orange_money') && (
        <div style={{marginBottom:12}}>
          <label>
            Numéro pour le paiement mobile :
            <input
              type="text"
              value={paymentPhone}
              onChange={(e) => setPaymentPhone(e.target.value)}
              placeholder="Ex: 77XXXXXXXX"
              style={{marginLeft:8, padding:8, minWidth:220}}
            />
          </label>
        </div>
      )}
      {message && <p style={{marginBottom:12, color:'green'}}>{message}</p>}
      <div style={{marginTop:12}}>
        <Link href="/">Continuer vos achats</Link>
        <button onClick={checkout} disabled={loading} style={{marginLeft:12}}>{loading ? 'Traitement...' : 'Passer commande'}</button>
      </div>
    </main>
  )
}
