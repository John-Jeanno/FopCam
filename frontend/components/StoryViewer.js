import { useState, useEffect, useRef } from 'react';
import { XMarkIcon, HeartIcon, EyeIcon, PlayIcon, PauseIcon } from '@heroicons/react/24/outline';
import { HeartIcon as HeartIconSolid } from '@heroicons/react/24/solid';

const StoryViewer = ({ stories, currentIndex, onClose, onNext, onPrevious, onView, onLike }) => {
  const [currentStoryIndex, setCurrentStoryIndex] = useState(currentIndex);
  const [progress, setProgress] = useState(0);
  const [isPlaying, setIsPlaying] = useState(true);
  const [isVideoLoaded, setIsVideoLoaded] = useState(false);
  const videoRef = useRef(null);
  const progressIntervalRef = useRef(null);
  const storyDuration = 5000; // 5 secondes par story

  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'
  
  const buildMediaUrl = (path) => {
    if (!path) return null
    if (path.startsWith('http')) return path
    return `${apiUrl}${path.startsWith('/') ? '' : '/'}${path}`
  }

  const currentStory = stories[currentStoryIndex];

  useEffect(() => {
    if (currentStory && !currentStory.is_viewed) {
      onView(currentStory.id);
    }
  }, [currentStory, onView]);

  useEffect(() => {
    if (isPlaying) {
      const startTime = Date.now();
      progressIntervalRef.current = setInterval(() => {
        const elapsed = Date.now() - startTime;
        const newProgress = (elapsed / storyDuration) * 100;

        if (newProgress >= 100) {
          handleNext();
        } else {
          setProgress(newProgress);
        }
      }, 50);
    } else {
      if (progressIntervalRef.current) {
        clearInterval(progressIntervalRef.current);
      }
    }

    return () => {
      if (progressIntervalRef.current) {
        clearInterval(progressIntervalRef.current);
      }
    };
  }, [isPlaying, currentStoryIndex]);

  const handleNext = () => {
    if (currentStoryIndex < stories.length - 1) {
      setCurrentStoryIndex(currentStoryIndex + 1);
      setProgress(0);
      onNext?.();
    } else {
      onClose();
    }
  };

  const handlePrevious = () => {
    if (currentStoryIndex > 0) {
      setCurrentStoryIndex(currentStoryIndex - 1);
      setProgress(0);
      onPrevious?.();
    }
  };

  const handleLike = async () => {
    if (currentStory) {
      await onLike(currentStory.id);
    }
  };

  const togglePlayPause = () => {
    setIsPlaying(!isPlaying);
  };

  const handleVideoLoad = () => {
    setIsVideoLoaded(true);
  };

  const renderStoryContent = () => {
    if (!currentStory) return null;

    switch (currentStory.story_type) {
      case 'image':
        return (
          <div className="relative h-full w-full">
            <img
              src={buildMediaUrl(currentStory.image)}
              alt="Story"
              className="w-full h-full object-cover"
            />
            {currentStory.content && (
              <div className="absolute inset-x-0 bottom-0 bg-black/50 p-4">
                <p className="text-sm text-white break-words">{currentStory.content}</p>
              </div>
            )}
          </div>
        );

      case 'video':
        return (
          <div className="relative h-full w-full">
            <video
              ref={videoRef}
              src={buildMediaUrl(currentStory.video)}
              className="w-full h-full object-cover"
              autoPlay
              muted
              onLoadedData={handleVideoLoad}
              onEnded={handleNext}
            />
            {currentStory.content && (
              <div className="absolute inset-x-0 bottom-0 bg-black/50 p-4">
                <p className="text-sm text-white break-words">{currentStory.content}</p>
              </div>
            )}
          </div>
        );

      case 'text':
        return (
          <div
            className="w-full h-full flex items-center justify-center p-8"
            style={{
              backgroundColor: currentStory.background_color || '#ffffff',
              color: currentStory.text_color || '#000000',
              fontSize: `${currentStory.font_size || 24}px`
            }}
          >
            <p className="text-center font-medium">{currentStory.content}</p>
          </div>
        );

      default:
        return null;
    }
  };

  if (!currentStory) return null;

  return (
    <div className="fixed inset-0 bg-black z-50 flex items-center justify-center">
      {/* Progress bars */}
      <div className="absolute top-4 left-4 right-4 z-10">
        <div className="flex space-x-1">
          {stories.map((story, index) => (
            <div
              key={story.id}
              className="flex-1 h-1 bg-gray-600 rounded-full overflow-hidden"
            >
              <div
                className="h-full bg-white transition-all duration-100"
                style={{
                  width: index < currentStoryIndex ? '100%' :
                         index === currentStoryIndex ? `${progress}%` : '0%'
                }}
              />
            </div>
          ))}
        </div>
      </div>

      {/* Close button */}
      <button
        onClick={onClose}
        className="absolute top-4 right-4 z-10 text-white hover:text-gray-300 transition-colors"
      >
        <XMarkIcon className="w-8 h-8" />
      </button>

      {/* Story author info */}
      <div className="absolute top-16 left-4 right-4 z-10 flex items-center space-x-3">
        <img
          src={buildMediaUrl(currentStory.author?.profile_image) || '/default-avatar.png'}
          alt={currentStory.author?.username}
          className="w-10 h-10 rounded-full border-2 border-white"
        />
        <div className="text-white">
          <p className="font-semibold">{currentStory.author?.username}</p>
          <p className="text-sm opacity-75">
            {new Date(currentStory.created_at).toLocaleDateString('fr-FR')}
          </p>
        </div>
      </div>

      {/* Main content */}
      <div className="w-full h-full relative">
        {renderStoryContent()}

        {/* Navigation areas */}
        <div
          className="absolute left-0 top-0 w-1/3 h-full cursor-pointer"
          onClick={handlePrevious}
        />
        <div
          className="absolute right-0 top-0 w-1/3 h-full cursor-pointer"
          onClick={handleNext}
        />

        {/* Controls */}
        <div className="absolute bottom-20 left-4 right-4 z-10">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              {/* Like button */}
              <button
                onClick={handleLike}
                className="text-white hover:text-red-500 transition-colors"
              >
                {currentStory.is_liked ? (
                  <HeartIconSolid className="w-8 h-8 text-red-500" />
                ) : (
                  <HeartIcon className="w-8 h-8" />
                )}
              </button>

              {/* Play/Pause button */}
              <button
                onClick={togglePlayPause}
                className="text-white hover:text-gray-300 transition-colors"
              >
                {isPlaying ? (
                  <PauseIcon className="w-8 h-8" />
                ) : (
                  <PlayIcon className="w-8 h-8" />
                )}
              </button>

              {/* Exit button */}
              <button
                onClick={onClose}
                className="text-white hover:text-gray-300 transition-colors flex items-center space-x-2 px-4 py-2 rounded-lg bg-red-600 hover:bg-red-700"
              >
                <XMarkIcon className="w-5 h-5" />
                <span>Quitter</span>
              </button>
            </div>

            {/* Stats */}
            <div className="flex items-center space-x-4 text-white text-sm">
              <div className="flex items-center space-x-1">
                <EyeIcon className="w-4 h-4" />
                <span>{currentStory.views_count}</span>
              </div>
              <div className="flex items-center space-x-1">
                <HeartIcon className="w-4 h-4" />
                <span>{currentStory.likes_count}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default StoryViewer;