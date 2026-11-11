import React from 'react'

export default function PostViewer({ isOpen, onClose, mediaList = [], currentIndex = 0, onIndexChange = () => {} }) {
  if (!isOpen || !mediaList || mediaList.length === 0) return null

  const media = mediaList[currentIndex] || mediaList[0]
  const hasMultiple = mediaList.length > 1

  const goPrev = () => onIndexChange((currentIndex - 1 + mediaList.length) % mediaList.length)
  const goNext = () => onIndexChange((currentIndex + 1) % mediaList.length)

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 px-4 py-8">
      <div className="relative max-w-4xl w-full mx-auto">
        <button
          onClick={onClose}
          className="absolute top-2 right-2 z-50 bg-white/90 rounded-full p-2 hover:bg-white"
          aria-label="Fermer"
        >
          ✕
        </button>

        <div className="bg-black rounded-xl overflow-hidden">
          {media.type === 'video' ? (
            <video src={media.src} controls autoPlay className="w-full max-h-[80vh]" />
          ) : (
            <img src={media.src} alt={media.alt || 'Media'} className="w-full object-contain max-h-[80vh]" />
          )}

          {hasMultiple && (
            <>
              <button
                type="button"
                onClick={goPrev}
                className="absolute left-3 top-1/2 z-50 -translate-y-1/2 rounded-full bg-white/80 p-3 text-2xl font-bold text-gray-800 hover:bg-white"
                aria-label="Image précédente"
              >
                ‹
              </button>
              <button
                type="button"
                onClick={goNext}
                className="absolute right-3 top-1/2 z-50 -translate-y-1/2 rounded-full bg-white/80 p-3 text-2xl font-bold text-gray-800 hover:bg-white"
                aria-label="Image suivante"
              >
                ›
              </button>
              <div className="absolute bottom-4 left-1/2 z-50 flex -translate-x-1/2 gap-2">
                {mediaList.map((_, idx) => (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => onIndexChange(idx)}
                    className={`h-2.5 w-2.5 rounded-full ${idx === currentIndex ? 'bg-white' : 'bg-white/50'}`}
                    aria-label={`Aller à l’élément ${idx + 1}`}
                  />
                ))}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
