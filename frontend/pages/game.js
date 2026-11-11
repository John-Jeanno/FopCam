import Head from 'next/head'
import Link from 'next/link'

export default function GamePage() {
  return (
    <>
      <Head>
        <title>FopCam - Arcade</title>
        <meta name="description" content="FopCam Arcade - Le jeu Flutter identique sur mobile et web" />
      </Head>

      <div className="min-h-screen bg-gradient-to-br from-future-900 via-future-800 to-focal-900 text-white">
        <div className="max-w-6xl mx-auto px-4 py-8">
          <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between mb-6">
            <div>
              <h1 className="text-4xl font-semibold">FopCam Arcade</h1>
              <p className="mt-2 text-slate-300">Le jeu Flutter - Identique sur mobile et web</p>
            </div>
            <Link href="/" className="rounded-full bg-fopcam-500 px-4 py-2 text-sm font-medium text-white hover:bg-fopcam-400">
              Retour à l'accueil
            </Link>
          </div>

          <div className="rounded-3xl border border-slate-700 bg-slate-950/70 p-4 shadow-2xl overflow-hidden">
            <iframe
              src={`${process.env.NEXT_PUBLIC_BASE_PATH || ''}/game/index.html`}
              title="FopCam Game"
              className="w-full"
              style={{ height: '600px', border: 'none' }}
              allow="fullscreen"
            />
          </div>

          <div className="mt-6 rounded-3xl border border-slate-700 bg-slate-900/80 p-4 text-slate-300">
            <h2 className="text-2xl font-semibold text-white">Commandes</h2>
            <ul className="mt-3 list-disc pl-5 space-y-2">
              <li>Touchez pour déplacer le joueur (gauche/droite/milieu)</li>
              <li>Évitez les obstacles qui tombent</li>
              <li>Collectez les power-ups (shield, double multiplier)</li>
              <li>Augmentez votre score et votre meilleure marque</li>
              <li>Appuyez sur <strong>R</strong> pour recommencer après un Game Over</li>
            </ul>
          </div>
        </div>
      </div>
    </>
  )
}
