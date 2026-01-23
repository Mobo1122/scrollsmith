"""YouTube captions service using youtube-transcript-api and YouTube Data API."""

import asyncio
import logging
import re
from typing import Optional, Tuple

from app.core.config import settings

logger = logging.getLogger(__name__)


class YouTubeCaptionsError(Exception):
    """Base error for YouTube captions."""
    pass


class RateLimitError(YouTubeCaptionsError):
    """YouTube API rate limit exceeded."""
    pass


class NoCaptionsError(YouTubeCaptionsError):
    """Video has no available captions."""
    pass


class VideoUnavailableError(YouTubeCaptionsError):
    """Video is private, deleted, or unavailable."""
    pass


class YouTubeCaptionsService:
    """Service for fetching captions from YouTube videos.

    Uses youtube-transcript-api for caption fetching (doesn't require API key).
    Falls back to YouTube Data API for video metadata.
    """

    def __init__(self):
        self.enabled = True  # Always enabled since youtube-transcript-api doesn't need API key
        self.has_data_api = bool(settings.YOUTUBE_API_KEY)

    def extract_video_id(self, url: str) -> Optional[str]:
        """Extract YouTube video ID from URL.

        Supports:
        - youtube.com/watch?v=ID
        - youtu.be/ID
        - youtube.com/shorts/ID
        - youtube.com/embed/ID
        """
        patterns = [
            r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/shorts/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})',
            r'youtube\.com/watch\?.*?v=([a-zA-Z0-9_-]{11})',
        ]

        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                return match.group(1)
        return None

    async def get_captions(self, url: str) -> Tuple[str, dict]:
        """Fetch captions for a YouTube video.

        Args:
            url: YouTube video URL

        Returns:
            Tuple of (caption_text, metadata_dict)

        Raises:
            RateLimitError: If API quota exceeded
            NoCaptionsError: If no captions available
            VideoUnavailableError: If video is unavailable
            YouTubeCaptionsError: For other errors
        """
        video_id = self.extract_video_id(url)
        if not video_id:
            raise YouTubeCaptionsError(f"Could not extract video ID from URL: {url}")

        # Run in thread pool to avoid blocking
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            None,
            self._get_captions_sync,
            video_id
        )

    def _get_captions_sync(self, video_id: str) -> Tuple[str, dict]:
        """Synchronous caption fetching."""
        from youtube_transcript_api import YouTubeTranscriptApi
        from youtube_transcript_api._errors import (
            TranscriptsDisabled,
            NoTranscriptFound,
            VideoUnavailable,
            TooManyRequests,
        )

        try:
            # Try to get transcript
            # Prefer manual English, then auto English, then any
            transcript_list = YouTubeTranscriptApi.list_transcripts(video_id)

            transcript = None
            transcript_source = "unknown"

            # Try to find English transcripts first
            try:
                # Manual English
                transcript = transcript_list.find_manually_created_transcript(['en', 'en-US', 'en-GB'])
                transcript_source = "manual"
            except Exception:
                try:
                    # Auto-generated English
                    transcript = transcript_list.find_generated_transcript(['en', 'en-US', 'en-GB'])
                    transcript_source = "auto"
                except Exception:
                    # Any available transcript (translate to English if possible)
                    try:
                        for t in transcript_list:
                            transcript = t
                            transcript_source = "translated" if t.is_translatable else "other"
                            break
                    except Exception:
                        pass

            if transcript is None:
                raise NoCaptionsError(f"No captions available for video {video_id}")

            # Fetch the transcript data
            transcript_data = transcript.fetch()

            # Combine all text
            caption_text = " ".join([entry['text'] for entry in transcript_data])

            # Clean up caption text
            caption_text = self._clean_caption_text(caption_text)

            metadata = {
                'video_id': video_id,
                'transcript_source': transcript_source,
                'language': transcript.language if hasattr(transcript, 'language') else 'unknown',
            }

            # Try to get video title if we have the API key
            if self.has_data_api:
                try:
                    title = self._get_video_title(video_id)
                    if title:
                        metadata['title'] = title
                except Exception as e:
                    logger.warning(f"Could not fetch video title: {e}")

            return caption_text, metadata

        except TranscriptsDisabled:
            raise NoCaptionsError(f"Transcripts are disabled for video {video_id}")
        except NoTranscriptFound:
            raise NoCaptionsError(f"No transcript found for video {video_id}")
        except VideoUnavailable:
            raise VideoUnavailableError(f"Video {video_id} is unavailable (private or deleted)")
        except TooManyRequests:
            raise RateLimitError("YouTube API rate limit exceeded")
        except Exception as e:
            logger.error(f"Error fetching captions for {video_id}: {e}")
            raise YouTubeCaptionsError(f"Failed to fetch captions: {str(e)}")

    def _clean_caption_text(self, text: str) -> str:
        """Clean up caption text by removing artifacts."""
        # Remove [Music], [Applause], etc.
        text = re.sub(r'\[.*?\]', '', text)

        # Remove multiple spaces
        text = re.sub(r'\s+', ' ', text)

        # Remove leading/trailing whitespace
        text = text.strip()

        return text

    def _get_video_title(self, video_id: str) -> Optional[str]:
        """Get video title using YouTube Data API."""
        if not self.has_data_api:
            return None

        try:
            from googleapiclient.discovery import build

            youtube = build(
                'youtube', 'v3',
                developerKey=settings.YOUTUBE_API_KEY,
                cache_discovery=False
            )

            response = youtube.videos().list(
                part='snippet',
                id=video_id
            ).execute()

            if response.get('items'):
                return response['items'][0]['snippet']['title']
            return None

        except Exception as e:
            logger.warning(f"Could not fetch video title: {e}")
            return None


# Singleton instance
youtube_captions_service = YouTubeCaptionsService()
