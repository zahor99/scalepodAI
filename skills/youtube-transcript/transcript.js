#!/usr/bin/env node

import { YoutubeTranscript } from 'youtube-transcript-plus';

function extractVideoId(input) {
  if (!input) return null;

  // Already a plain video ID (11 characters, alphanumeric + dash/underscore)
  if (/^[A-Za-z0-9_-]{11}$/.test(input)) {
    return input;
  }

  try {
    const url = new URL(input);

    // youtu.be/VIDEO_ID
    if (url.hostname === 'youtu.be') {
      return url.pathname.slice(1);
    }

    // youtube.com/watch?v=VIDEO_ID
    if (url.hostname === 'www.youtube.com' || url.hostname === 'youtube.com') {
      return url.searchParams.get('v');
    }
  } catch {
    // Not a URL — treat as video ID anyway
    return input;
  }

  return null;
}

function decodeHtmlEntities(str) {
  return str
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#(\d+);/g, (_, num) => String.fromCharCode(Number(num)));
}

function formatTime(seconds) {
  const totalSeconds = Math.floor(seconds);
  const mins = Math.floor(totalSeconds / 60);
  const secs = totalSeconds % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}

async function main() {
  const input = process.argv[2];

  if (!input) {
    console.error('Usage: transcript.js <video-id-or-url>');
    process.exit(1);
  }

  const videoId = extractVideoId(input);

  if (!videoId) {
    console.error(`Error: Could not extract video ID from "${input}"`);
    process.exit(1);
  }

  try {
    const transcript = await YoutubeTranscript.fetchTranscript(videoId);

    if (!transcript || transcript.length === 0) {
      console.error('No transcript available for this video.');
      process.exit(1);
    }

    for (const entry of transcript) {
      const time = formatTime(entry.offset);
      const text = decodeHtmlEntities(entry.text.replace(/\n/g, ' ')).trim();
      console.log(`[${time}] ${text}`);
    }
  } catch (err) {
    console.error(`Error fetching transcript: ${err.message}`);
    process.exit(1);
  }
}

main();
