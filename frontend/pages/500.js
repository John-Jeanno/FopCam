import React from 'react';
import Link from 'next/link';

export default function Custom500({ error, reset }) {
  React.useEffect(() => {
    console.error('500 Error:', error);
  }, [error]);

  return (
    <div style={{
      padding: '40px',
      textAlign: 'center',
      minHeight: '100vh',
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'center',
      alignItems: 'center',
      fontFamily: 'system-ui, sans-serif'
    }}>
      <h1 style={{ fontSize: '48px', marginBottom: '20px', color: '#e53e3e' }}>500</h1>
      <p style={{ fontSize: '18px', marginBottom: '30px' }}>Une erreur serveur est survenue.</p>
      <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', justifyContent: 'center' }}>
        {reset && (
          <button
            type="button"
            onClick={() => reset()}
            style={{
              padding: '10px 20px',
              backgroundColor: '#3182ce',
              color: 'white',
              border: 'none',
              borderRadius: '8px',
              cursor: 'pointer'
            }}
          >
            Réessayer
          </button>
        )}
        <button
          type="button"
          onClick={() => window.location.reload()}
          style={{
            padding: '10px 20px',
            backgroundColor: '#4a5568',
            color: 'white',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer'
          }}
        >
          Actualiser
        </button>
        <Link
          href="/"
          style={{
            padding: '10px 20px',
            backgroundColor: '#16a34a',
            color: 'white',
            textDecoration: 'none',
            borderRadius: '8px',
            display: 'inline-block'
          }}
        >
          Retour à l'accueil
        </Link>
      </div>
    </div>
  );
}

export function getStaticProps() {
  return {
    props: {},
  };
}
