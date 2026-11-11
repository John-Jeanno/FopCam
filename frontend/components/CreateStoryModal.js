import { useState, useRef, useEffect } from 'react';
import { XMarkIcon, PhotoIcon, VideoCameraIcon, PencilIcon } from '@heroicons/react/24/outline';

const CreateStoryModal = ({ isOpen, onClose, onCreate }) => {
  const [storyType, setStoryType] = useState('text');
  const [content, setContent] = useState('');
  const [backgroundColor, setBackgroundColor] = useState('#ffffff');
  const [textColor, setTextColor] = useState('#000000');
  const [fontSize, setFontSize] = useState(24);
  const [mediaFiles, setMediaFiles] = useState([]);
  const [previewUrls, setPreviewUrls] = useState([]);
  const [cameraStream, setCameraStream] = useState(null);
  const [cameraMode, setCameraMode] = useState('photo');
  const [isRecording, setIsRecording] = useState(false);
  const recordedChunksRef = useRef([]);
  const [cameraError, setCameraError] = useState(null);
  const [capturedMediaType, setCapturedMediaType] = useState(null);
  const fileInputRef = useRef(null);
  const videoRef = useRef(null);
  const mediaRecorderRef = useRef(null);

  const colorPresets = [
    '#ffffff', '#000000', '#ff0000', '#00ff00', '#0000ff',
    '#ffff00', '#ff00ff', '#00ffff', '#ffa500', '#800080',
    '#ffc0cb', '#a52a2a', '#808080', '#000080', '#008000'
  ];

  useEffect(() => {
    if (!isOpen) {
      stopCamera()
      return
    }

    return () => {
      stopCamera()
    }
  }, [isOpen])

  useEffect(() => {
    if (cameraStream && videoRef.current) {
      videoRef.current.srcObject = cameraStream
      const playPromise = videoRef.current.play()
      if (playPromise && typeof playPromise.catch === 'function') {
        playPromise.catch((error) => {
          console.warn('Lecture automatique de la caméra impossible :', error)
        })
      }
    }
  }, [cameraStream])

  const startCamera = async (mode) => {
    setCameraError(null)
    setCameraMode(mode)
    setStoryType(mode === 'photo' ? 'image' : 'video')

    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: mode === 'video',
        video: { facingMode: 'user' }
      })
      setCameraStream(stream)
      if (videoRef.current) {
        videoRef.current.srcObject = stream
      }
    } catch (error) {
      console.error('Erreur accès caméra:', error)
      setCameraError('Impossible d’accéder à la caméra. Vérifiez les permissions de votre navigateur.')
    }
  }

  const stopCamera = () => {
    if (cameraStream) {
      cameraStream.getTracks().forEach((track) => track.stop())
      setCameraStream(null)
    }
    if (videoRef.current) {
      videoRef.current.srcObject = null
    }
    setIsRecording(false)
    recordedChunksRef.current = []
  }

  const capturePhoto = () => {
    if (!videoRef.current) return
    const canvas = document.createElement('canvas')
    canvas.width = videoRef.current.videoWidth
    canvas.height = videoRef.current.videoHeight
    const ctx = canvas.getContext('2d')
    ctx.drawImage(videoRef.current, 0, 0, canvas.width, canvas.height)
    canvas.toBlob((blob) => {
      if (!blob) return
      const file = new File([blob], `camera-photo-${Date.now()}.png`, { type: 'image/png' })
      setMediaFiles([file])
      setPreviewUrls([URL.createObjectURL(file)])
      setCapturedMediaType('image')
    }, 'image/png')
  }

  const startRecording = () => {
    if (!cameraStream) return
    recordedChunksRef.current = []

    const supportedTypes = [
      'video/webm;codecs=vp8,opus',
      'video/webm;codecs=vp9,opus',
      'video/webm;codecs=vp8',
      'video/mp4',
      'video/webm'
    ]

    let mimeType = ''
    for (const type of supportedTypes) {
      if (MediaRecorder.isTypeSupported(type)) {
        mimeType = type
        break
      }
    }

    const recorder = mimeType
      ? new MediaRecorder(cameraStream, { mimeType })
      : new MediaRecorder(cameraStream)

    mediaRecorderRef.current = recorder

    recorder.ondataavailable = (event) => {
      if (event.data && event.data.size > 0) {
        recordedChunksRef.current.push(event.data)
      }
    }

    recorder.onstop = () => {
      const blob = new Blob(recordedChunksRef.current, { type: mimeType || 'video/webm' })
      const file = new File([blob], `camera-video-${Date.now()}.webm`, { type: mimeType || 'video/webm' })
      setMediaFiles([file])
      setPreviewUrls([URL.createObjectURL(file)])
      setCapturedMediaType('video')
      setIsRecording(false)
    }

    recorder.start()
    setIsRecording(true)
  }

  const stopRecording = () => {
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop()
    }
  }

  const handleFileSelect = (event) => {
    const files = Array.from(event.target.files || [])
    if (files.length === 0) return

    const previewUrlsToRevoke = previewUrls.slice()
    if (previewUrlsToRevoke.length > 0) {
      previewUrlsToRevoke.forEach((url) => { if (url) URL.revokeObjectURL(url) })
    }

    const fileTypes = files.map((file) => file.type || '')
    const allImages = fileTypes.every((type) => type.startsWith('image/'))
    const allVideos = fileTypes.every((type) => type.startsWith('video/'))

    if (!allImages && !allVideos) {
      alert('Veuillez sélectionner uniquement des images ou uniquement des vidéos.')
      event.target.value = ''
      return
    }

    const urls = files.map((f) => URL.createObjectURL(f))
    setMediaFiles(files)
    setPreviewUrls(urls)
    setStoryType(allImages ? 'image' : 'video')
    setCapturedMediaType(allImages ? 'image' : 'video')

    // reset input value so selecting the same file again still triggers onChange
    event.target.value = ''
  };

  const handleSubmit = async () => {
    const formData = new FormData();

    formData.append('story_type', storyType);
    formData.append('content', content);
    formData.append('background_color', backgroundColor);
    formData.append('text_color', textColor);
    formData.append('font_size', fontSize.toString());

    // Append selected or captured media files
    if (mediaFiles && mediaFiles.length > 0) {
      if (storyType === 'image') {
        formData.append('image', mediaFiles[0])
        for (let i = 1; i < mediaFiles.length; i++) {
          formData.append(`image_${i}`, mediaFiles[i])
        }
      } else if (storyType === 'video') {
        formData.append('video', mediaFiles[0])
        for (let i = 1; i < mediaFiles.length; i++) {
          formData.append(`video_${i}`, mediaFiles[i])
        }
      }
    }

    // Diagnostics: log file info to help debugging invalid uploads
    try {
      if (mediaFiles && mediaFiles.length > 0) {
        mediaFiles.forEach((file, idx) => {
          console.debug('CreateStoryModal: uploading file', { index: idx, name: file.name, type: file.type, size: file.size })
          if (storyType === 'image' && !file.type.startsWith('image/')) {
            alert(`Le fichier "${file.name}" n'est pas reconnu comme une image. Essayez un JPG ou PNG.`)
            return
          }
          if (storyType === 'video' && !file.type.startsWith('video/')) {
            alert(`Le fichier "${file.name}" n'est pas reconnu comme une vidéo.`)
            return
          }
        })
      }

      // Liste les entrées FormData pour inspection
      for (const entry of formData.entries()) {
        console.debug('CreateStoryModal formData entry:', entry[0], entry[1])
      }
    } catch (e) {
      console.warn('CreateStoryModal: erreur diagnostic fichier', e)
    }

    await onCreate(formData)
    handleClose()
  };

  const handleClose = () => {
    // Nettoyer les URLs d'aperçu
    if (previewUrls && previewUrls.length > 0) {
      previewUrls.forEach(url => { if (url) URL.revokeObjectURL(url) })
    }
    setContent('');
    setMediaFiles([]);
    setPreviewUrls([]);
    setStoryType('text');
    setBackgroundColor('#ffffff');
    setTextColor('#000000');
    setFontSize(24);
    onClose();
  };

  const renderPreview = () => {
    switch (storyType) {
      case 'image':
        return previewUrls && previewUrls.length > 0 ? (
          <div className="grid grid-cols-2 gap-2 p-2">
            {previewUrls.map((u, i) => (
              <img key={i} src={u} alt={`Aperçu ${i+1}`} className="w-full h-40 object-cover rounded-lg" />
            ))}
          </div>
        ) : null;

      case 'video':
        return previewUrls && previewUrls.length > 0 ? (
          <div className="space-y-2 p-2">
            {previewUrls.map((u, i) => (
              <video key={i} src={u} className="w-full max-h-56 object-cover rounded-lg" controls />
            ))}
          </div>
        ) : null;

      case 'text':
        return (
          <div
            className="w-full h-full flex items-center justify-center p-8 rounded-lg"
            style={{
              backgroundColor: backgroundColor,
              color: textColor,
              fontSize: `${fontSize}px`
            }}
          >
            <p className="text-center font-medium">{content || 'Votre texte ici...'}</p>
          </div>
        );

      default:
        return null;
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold">Créer une story</h2>
          <button
            onClick={handleClose}
            className="text-gray-400 hover:text-gray-600"
          >
            <XMarkIcon className="w-6 h-6" />
          </button>
        </div>

        <div className="flex flex-col md:flex-row">
          {/* Preview */}
          <div className="flex-1 p-4">
            <div className="aspect-[9/16] bg-gray-100 rounded-lg overflow-hidden mb-4 relative">
              {cameraStream ? (
                <div className="h-full w-full">
                  <video
                    ref={videoRef}
                    autoPlay
                    muted
                    playsInline
                    className="h-full w-full object-cover"
                  />
                  <div className="absolute inset-x-0 bottom-0 p-3 bg-black/40 flex items-center justify-between gap-2">
                    {cameraMode === 'photo' ? (
                      <button
                        type="button"
                        onClick={capturePhoto}
                        className="w-full rounded-full bg-fopcam-600 py-2 text-sm font-semibold text-white hover:bg-fopcam-700 transition"
                      >
                        Prendre une photo
                      </button>
                    ) : (
                      <>
                        <button
                          type="button"
                          onClick={isRecording ? stopRecording : startRecording}
                          className="w-full rounded-full bg-fopcam-600 py-2 text-sm font-semibold text-white hover:bg-fopcam-700 transition"
                        >
                          {isRecording ? 'Arrêter l’enregistrement' : 'Enregistrer la vidéo'}
                        </button>
                      </>
                    )}
                  </div>
                </div>
              ) : (
                renderPreview()
              )}

              {content && storyType !== 'text' && (
                <div className="absolute inset-x-0 bottom-0 bg-black/50 px-4 py-3">
                  <p className="text-sm text-white break-words">{content}</p>
                </div>
              )}
            </div>

            {/* Story Type Selection */}
            <div className="flex flex-wrap gap-2 mb-4">
              <button
                onClick={() => setStoryType('text')}
                className={`flex items-center space-x-2 px-3 py-2 rounded-lg border ${
                  storyType === 'text'
                    ? 'border-purple-500 bg-purple-50 text-purple-700'
                    : 'border-gray-300 text-gray-700'
                }`}
              >
                <PencilIcon className="w-4 h-4" />
                <span>Texte</span>
              </button>

              <button
                onClick={() => {
                  setStoryType('image')
                  fileInputRef.current?.click()
                }}
                className={`flex items-center space-x-2 px-3 py-2 rounded-lg border ${
                  storyType === 'image' && !cameraStream
                    ? 'border-purple-500 bg-purple-50 text-purple-700'
                    : 'border-gray-300 text-gray-700'
                }`}
              >
                <PhotoIcon className="w-4 h-4" />
                <span>Image</span>
              </button>

              <button
                onClick={() => {
                  setStoryType('video')
                  fileInputRef.current?.click()
                }}
                className={`flex items-center space-x-2 px-3 py-2 rounded-lg border ${
                  storyType === 'video' && !cameraStream
                    ? 'border-purple-500 bg-purple-50 text-purple-700'
                    : 'border-gray-300 text-gray-700'
                }`}
              >
                <VideoCameraIcon className="w-4 h-4" />
                <span>Vidéo</span>
              </button>

              <button
                onClick={() => startCamera('photo')}
                className={`flex items-center space-x-2 px-3 py-2 rounded-lg border ${
                  cameraMode === 'photo' && cameraStream
                    ? 'border-fopcam-700 bg-fopcam-100 text-fopcam-800'
                    : 'border-gray-300 text-gray-700'
                }`}
              >
                <PhotoIcon className="w-4 h-4" />
                <span>Caméra</span>
              </button>

              <button
                onClick={() => startCamera('video')}
                className={`flex items-center space-x-2 px-3 py-2 rounded-lg border ${
                  cameraMode === 'video' && cameraStream
                    ? 'border-fopcam-700 bg-fopcam-100 text-fopcam-800'
                    : 'border-gray-300 text-gray-700'
                }`}
              >
                <VideoCameraIcon className="w-4 h-4" />
                <span>Vidéo live</span>
              </button>
            </div>

            <input
              ref={fileInputRef}
              type="file"
              multiple
              accept="image/*,video/*"
              onChange={handleFileSelect}
              className="hidden"
            />
            {cameraError && (
              <div className="mt-4 rounded-lg bg-red-50 p-3 text-sm text-red-700">
                {cameraError}
              </div>
            )}
          </div>

          {/* Controls */}
          <div className="w-full md:w-80 p-4 border-t md:border-t-0 md:border-l border-gray-200">
            <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              {storyType === 'text' ? 'Texte' : 'Légende / Sous-titre'}
            </label>
            <textarea
              value={content}
              onChange={(e) => setContent(e.target.value)}
              placeholder={storyType === 'text' ? 'Écrivez votre message...' : 'Ajouter une légende ou sous-titre...'}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              rows={storyType === 'text' ? 3 : 2}
            />
          </div>

          {storyType === 'text' && (
            <>
              {/* Font Size */}
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Taille du texte: {fontSize}px
                </label>
                <input
                  type="range"
                  min="12"
                  max="48"
                  value={fontSize}
                  onChange={(e) => setFontSize(parseInt(e.target.value))}
                  className="w-full"
                />
              </div>

              {/* Background Color */}
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Couleur de fond
                </label>
                <div className="flex flex-wrap gap-2 mb-2">
                  {colorPresets.map((color) => (
                    <button
                      key={color}
                      onClick={() => setBackgroundColor(color)}
                      className={`w-8 h-8 rounded-full border-2 ${
                        backgroundColor === color ? 'border-gray-800' : 'border-gray-300'
                      }`}
                      style={{ backgroundColor: color }}
                    />
                  ))}
                </div>
                <input
                  type="color"
                  value={backgroundColor}
                  onChange={(e) => setBackgroundColor(e.target.value)}
                  className="w-full h-10 rounded border border-gray-300"
                />
              </div>

              {/* Text Color */}
              <div className="mb-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Couleur du texte
                </label>
                <div className="flex flex-wrap gap-2 mb-2">
                  {colorPresets.map((color) => (
                    <button
                      key={color}
                      onClick={() => setTextColor(color)}
                      className={`w-8 h-8 rounded-full border-2 ${
                        textColor === color ? 'border-gray-800' : 'border-gray-300'
                      }`}
                      style={{ backgroundColor: color }}
                    />
                  ))}
                </div>
                <input
                  type="color"
                  value={textColor}
                  onChange={(e) => setTextColor(e.target.value)}
                  className="w-full h-10 rounded border border-gray-300"
                />
              </div>
            </>
          )}

            {/* Submit Button */}
            <button
              onClick={handleSubmit}
              disabled={!content.trim() && mediaFiles.length === 0}
              className="w-full bg-gradient-to-r from-purple-500 to-pink-500 text-white py-3 px-4 rounded-lg font-medium hover:from-purple-600 hover:to-pink-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Publier la story
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default CreateStoryModal;