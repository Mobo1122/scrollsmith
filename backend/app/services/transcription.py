"""Server-side audio transcription service.

v1: Uses OpenAI Whisper API or AssemblyAI for transcription.
Camera roll uploads are sent to this service for transcription.

TODO v2: This service will only be used for camera roll uploads once
WhisperKit is enabled for TikTok/IG URLs on iOS.
"""

import asyncio
import logging
import os
import tempfile
from typing import Optional, Tuple

from app.core.config import settings

logger = logging.getLogger(__name__)


class TranscriptionError(Exception):
    """Base error for transcription service."""
    pass


class NoAPIKeyError(TranscriptionError):
    """No transcription API key configured."""
    pass


class TranscriptionFailedError(TranscriptionError):
    """Transcription API call failed."""
    pass


class TranscriptionService:
    """Server-side audio transcription service.

    Supports:
    - OpenAI Whisper API (preferred)
    - AssemblyAI (fallback)
    """

    def __init__(self):
        self.has_openai = bool(settings.OPENAI_API_KEY)
        self.has_assemblyai = bool(settings.ASSEMBLYAI_API_KEY)

    @property
    def is_available(self) -> bool:
        """Check if any transcription service is available."""
        return self.has_openai or self.has_assemblyai

    async def transcribe(self, audio_data: bytes, filename: str = "audio.m4a") -> Tuple[str, dict]:
        """Transcribe audio data.

        Args:
            audio_data: Raw audio file bytes
            filename: Original filename (used for format detection)

        Returns:
            Tuple of (transcript_text, metadata_dict)

        Raises:
            NoAPIKeyError: If no transcription API is configured
            TranscriptionFailedError: If transcription fails
        """
        if not self.is_available:
            raise NoAPIKeyError(
                "No transcription API configured. Set OPENAI_API_KEY or ASSEMBLYAI_API_KEY."
            )

        # Try OpenAI first (better quality, faster)
        if self.has_openai:
            try:
                return await self._transcribe_openai(audio_data, filename)
            except Exception as e:
                logger.warning(f"OpenAI transcription failed, trying AssemblyAI: {e}")
                if self.has_assemblyai:
                    return await self._transcribe_assemblyai(audio_data, filename)
                raise TranscriptionFailedError(f"OpenAI transcription failed: {e}")

        # Fall back to AssemblyAI
        if self.has_assemblyai:
            return await self._transcribe_assemblyai(audio_data, filename)

        raise NoAPIKeyError("No transcription API available")

    async def _transcribe_openai(self, audio_data: bytes, filename: str) -> Tuple[str, dict]:
        """Transcribe using OpenAI Whisper API."""
        import openai

        client = openai.AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

        # Write audio data to a temporary file (OpenAI API requires file path)
        with tempfile.NamedTemporaryFile(suffix=".m4a", delete=False) as tmp:
            tmp.write(audio_data)
            tmp_path = tmp.name

        try:
            # Run transcription in thread pool
            loop = asyncio.get_event_loop()

            with open(tmp_path, "rb") as audio_file:
                response = await client.audio.transcriptions.create(
                    model="whisper-1",
                    file=audio_file,
                    response_format="text"
                )

            transcript = response.strip() if isinstance(response, str) else response.text.strip()

            if not transcript:
                raise TranscriptionFailedError("Empty transcript returned")

            metadata = {
                "service": "openai",
                "model": "whisper-1"
            }

            return transcript, metadata

        finally:
            # Clean up temp file
            try:
                os.unlink(tmp_path)
            except Exception:
                pass

    async def _transcribe_assemblyai(self, audio_data: bytes, filename: str) -> Tuple[str, dict]:
        """Transcribe using AssemblyAI API."""
        import aiohttp

        api_key = settings.ASSEMBLYAI_API_KEY
        headers = {"authorization": api_key}

        async with aiohttp.ClientSession() as session:
            # 1. Upload the audio file
            upload_url = "https://api.assemblyai.com/v2/upload"
            async with session.post(upload_url, headers=headers, data=audio_data) as resp:
                if resp.status != 200:
                    raise TranscriptionFailedError(f"AssemblyAI upload failed: {resp.status}")
                upload_response = await resp.json()
                audio_url = upload_response["upload_url"]

            # 2. Start transcription
            transcript_url = "https://api.assemblyai.com/v2/transcript"
            transcript_request = {
                "audio_url": audio_url,
                "language_detection": True  # Auto-detect language
            }
            async with session.post(
                transcript_url,
                headers={**headers, "content-type": "application/json"},
                json=transcript_request
            ) as resp:
                if resp.status != 200:
                    raise TranscriptionFailedError(f"AssemblyAI transcription request failed: {resp.status}")
                transcript_response = await resp.json()
                transcript_id = transcript_response["id"]

            # 3. Poll for completion
            polling_url = f"https://api.assemblyai.com/v2/transcript/{transcript_id}"
            while True:
                async with session.get(polling_url, headers=headers) as resp:
                    if resp.status != 200:
                        raise TranscriptionFailedError(f"AssemblyAI polling failed: {resp.status}")
                    result = await resp.json()

                    if result["status"] == "completed":
                        transcript = result["text"]
                        if not transcript:
                            raise TranscriptionFailedError("Empty transcript returned")

                        metadata = {
                            "service": "assemblyai",
                            "language": result.get("language_code", "unknown"),
                            "confidence": result.get("confidence", 0)
                        }
                        return transcript, metadata

                    elif result["status"] == "error":
                        raise TranscriptionFailedError(f"AssemblyAI error: {result.get('error', 'Unknown error')}")

                    # Wait before polling again
                    await asyncio.sleep(3)


# Singleton instance
transcription_service = TranscriptionService()
