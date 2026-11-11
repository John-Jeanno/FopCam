import React from 'react';
import Link from 'next/link';

export default function Custom404() {
  return (
    <div style={{ padding: '40px', textAlign: 'center', minHeight: '100vh', display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center' }}>
      <h1 style={{ fontSize: '48px', marginBottom: '20px' }}>404</h1>
      <p style={{ fontSize: '18px', marginBottom: '30px' }}>Page not found</p>
      <Link href="/" style={{ padding: '10px 20px', backgroundColor: '#16a34a', color: 'white', textDecoration: 'none', borderRadius: '8px' }}>
        Go back home
      </Link>
    </div>
  );
}
