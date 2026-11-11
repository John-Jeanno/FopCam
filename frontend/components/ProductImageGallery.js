import { useState } from 'react'

export default function ProductImageGallery({ product, resolveMediaUrl }) {
  const imagePaths = [product.image, ...(Array.isArray(product.images) ? product.images : [])]
    .filter((image, index, images) => image && images.indexOf(image) === index)
  const images = imagePaths.map(resolveMediaUrl).filter(Boolean)
  const [currentIndex, setCurrentIndex] = useState(0)
  const [isOpen, setIsOpen] = useState(false)
  const [touchStartX, setTouchStartX] = useState(null)
  const [touchStartY, setTouchStartY] = useState(null)

  const showPrevious = () => {
    setCurrentIndex((index) => (index - 1 + images.length) % images.length)
  }
  const showNext = () => {
    setCurrentIndex((index) => (index + 1) % images.length)
  }

  const handleTouchEnd = (event) => {
    if (touchStartX === null || touchStartY === null) return
    const deltaX = event.changedTouches[0].clientX - touchStartX
    const deltaY = event.changedTouches[0].clientY - touchStartY
    if (Math.abs(deltaX) > 48 && Math.abs(deltaX) > Math.abs(deltaY)) {
      deltaX < 0 ? showNext() : showPrevious()
    }
    setTouchStartX(null)
    setTouchStartY(null)
  }

  if (images.length === 0) {
    return (
      <div className="flex aspect-[4/3] items-center justify-center bg-future-100 text-sm text-future-500">
        Pas d'image
      </div>
    )
  }

  return (
    <>
      <div className="group relative aspect-[4/3] overflow-hidden bg-future-100">
        <button
          type="button"
          onClick={() => setIsOpen(true)}
          onTouchStart={(event) => {
            setTouchStartX(event.touches[0].clientX)
            setTouchStartY(event.touches[0].clientY)
          }}
          onTouchEnd={handleTouchEnd}
          className="block h-full w-full touch-pan-y"
          aria-label={`Agrandir les images de ${product.title || 'ce produit'}`}
        >
          <img
            src={images[currentIndex]}
            alt={`${product.title || 'Produit'} — image ${currentIndex + 1}`}
            className="h-full w-full object-cover transition-transform duration-200 group-hover:scale-105"
          />
        </button>
        {images.length > 1 && (
          <>
            <button
              type="button"
              onClick={showPrevious}
              aria-label="Image précédente"
              className="absolute left-2 top-1/2 -translate-y-1/2 rounded-full bg-black/60 p-2 text-white opacity-100 transition hover:bg-black/80 sm:opacity-0 sm:group-hover:opacity-100"
            >
              ‹
            </button>
            <button
              type="button"
              onClick={showNext}
              aria-label="Image suivante"
              className="absolute right-2 top-1/2 -translate-y-1/2 rounded-full bg-black/60 p-2 text-white opacity-100 transition hover:bg-black/80 sm:opacity-0 sm:group-hover:opacity-100"
            >
              ›
            </button>
            <span className="pointer-events-none absolute bottom-2 right-2 rounded-full bg-black/65 px-2.5 py-1 text-xs font-semibold text-white">
              {currentIndex + 1}/{images.length}
            </span>
          </>
        )}
      </div>

      {isOpen && (
        <div
          className="fixed inset-0 z-[100] flex items-center justify-center bg-black/95 p-3 sm:p-8"
          role="dialog"
          aria-modal="true"
          aria-label={`Galerie d'images de ${product.title || 'ce produit'}`}
          onClick={() => setIsOpen(false)}
          onTouchStart={(event) => {
            setTouchStartX(event.touches[0].clientX)
            setTouchStartY(event.touches[0].clientY)
          }}
          onTouchEnd={handleTouchEnd}
        >
          <button
            type="button"
            onClick={() => setIsOpen(false)}
            aria-label="Fermer la galerie"
            className="absolute right-3 top-3 z-10 rounded-full bg-white/15 px-4 py-2 text-2xl text-white hover:bg-white/25 sm:right-6 sm:top-6"
          >
            ×
          </button>
          {images.length > 1 && (
            <button
              type="button"
              onClick={(event) => {
                event.stopPropagation()
                showPrevious()
              }}
              aria-label="Image précédente"
              className="absolute left-2 z-10 rounded-full bg-white/15 px-4 py-3 text-2xl text-white hover:bg-white/25 sm:left-8"
            >
              ‹
            </button>
          )}
          <img
            src={images[currentIndex]}
            alt={`${product.title || 'Produit'} — image ${currentIndex + 1}`}
            className="max-h-[88dvh] max-w-full select-none object-contain"
            onClick={(event) => event.stopPropagation()}
            draggable="false"
          />
          {images.length > 1 && (
            <>
              <button
                type="button"
                onClick={(event) => {
                  event.stopPropagation()
                  showNext()
                }}
                aria-label="Image suivante"
                className="absolute right-2 z-10 rounded-full bg-white/15 px-4 py-3 text-2xl text-white hover:bg-white/25 sm:right-8"
              >
                ›
              </button>
              <span className="absolute bottom-4 rounded-full bg-black/65 px-3 py-1 text-sm font-semibold text-white">
                {currentIndex + 1}/{images.length}
              </span>
            </>
          )}
        </div>
      )}
    </>
  )
}
