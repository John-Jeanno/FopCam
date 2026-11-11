import { useState, useEffect } from 'react';
import { PlusIcon } from '@heroicons/react/24/outline';
import StoryViewer from './StoryViewer';

const StoriesBar = ({ stories, onCreateStory, onViewStory, onLikeStory }) => {
  const [selectedStoryIndex, setSelectedStoryIndex] = useState(null);
  const [viewedStories, setViewedStories] = useState(new Set());

  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'
  
  const buildMediaUrl = (path) => {
    if (!path) return null
    if (path.startsWith('http')) return path
    return `${apiUrl}${path.startsWith('/') ? '' : '/'}${path}`
  }

  // Grouper les stories par auteur
  const storiesByAuthor = stories.reduce((acc, story) => {
    const authorId = story.author.id;
    if (!acc[authorId]) {
      acc[authorId] = {
        author: story.author,
        stories: [],
        hasUnviewed: false
      };
    }
    acc[authorId].stories.push(story);

    // Vérifier si l'utilisateur a vu cette story
    if (!story.is_viewed && !viewedStories.has(story.id)) {
      acc[authorId].hasUnviewed = true;
    }

    return acc;
  }, {});

  const handleStoryClick = (authorId) => {
    const authorStories = storiesByAuthor[authorId].stories;
    const firstUnviewedIndex = authorStories.findIndex(story => !story.is_viewed);

    if (firstUnviewedIndex !== -1) {
      setSelectedStoryIndex(stories.findIndex(s => s.id === authorStories[firstUnviewedIndex].id));
    } else {
      setSelectedStoryIndex(stories.findIndex(s => s.id === authorStories[0].id));
    }
  };

  const handleView = async (storyId) => {
    setViewedStories(prev => new Set([...prev, storyId]));
    await onViewStory(storyId);
  };

  const handleNext = () => {
    setSelectedStoryIndex(prev => prev + 1);
  };

  const handlePrevious = () => {
    setSelectedStoryIndex(prev => prev - 1);
  };

  const handleClose = () => {
    setSelectedStoryIndex(null);
  };

  return (
    <>
      {/* Stories Bar */}
      <div className="bg-white border-b border-gray-200 px-4 py-4 overflow-x-auto">
        <div className="flex space-x-4 min-w-max">
          {/* Create Story Button */}
          <div className="flex flex-col items-center space-y-1">
            <button
              onClick={onCreateStory}
              className="w-16 h-16 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white hover:scale-105 transition-transform"
            >
              <PlusIcon className="w-8 h-8" />
            </button>
            <span className="text-xs text-gray-600 text-center">Votre story</span>
          </div>

          {/* Stories */}
          {Object.entries(storiesByAuthor).map(([authorId, authorData]) => (
            <div
              key={authorId}
              className="flex flex-col items-center space-y-1 cursor-pointer"
              onClick={() => handleStoryClick(authorId)}
            >
              <div className={`w-16 h-16 rounded-full p-0.5 ${
                authorData.hasUnviewed
                  ? 'bg-gradient-to-br from-purple-500 to-pink-500'
                  : 'bg-gray-300'
              }`}>
                <div className="w-full h-full rounded-full bg-white p-0.5">
                  <img
                    src={buildMediaUrl(authorData.author.profile_image) || '/default-avatar.png'}
                    alt={authorData.author.username}
                    className="w-full h-full rounded-full object-cover"
                  />
                </div>
              </div>
              <span className="text-xs text-gray-600 text-center max-w-16 truncate">
                {authorData.author.username}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Story Viewer Modal */}
      {selectedStoryIndex !== null && (
        <StoryViewer
          stories={stories}
          currentIndex={selectedStoryIndex}
          onClose={handleClose}
          onNext={handleNext}
          onPrevious={handlePrevious}
          onView={handleView}
          onLike={onLikeStory}
        />
      )}
    </>
  );
};

export default StoriesBar;