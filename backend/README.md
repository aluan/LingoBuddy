# LingoBuddy Backend

NestJS backend for the LingoBuddy MVP.

## Stack

- NestJS
- MongoDB
- Redis
- Raw WebSocket endpoint for realtime voice
- Zhipu GLM-Realtime proxy with local mock fallback

## Local Setup

From the repo root:

```sh
docker compose up -d mongodb redis
```

From `backend/`:

```sh
cp .env.example .env
npm install
npm run start:dev
```

Default API URL:

```text
http://localhost:3000
```

Realtime voice WebSocket:

```text
ws://localhost:3000/voice/realtime
```

## Environment

```text
PORT=3000
MONGODB_URI=mongodb://localhost:27017/lingobuddy
REDIS_URL=redis://localhost:6379
ZHIPU_API_KEY=
GLM_REALTIME_MODEL=glm-realtime-flash
GLM_REALTIME_MOCK=true
```

Set `GLM_REALTIME_MOCK=false` and provide `ZHIPU_API_KEY` to proxy real GLM-Realtime sessions.

## REST API

```text
GET   /profile/current
PATCH /profile/current
GET   /home/today
GET   /tasks/today
POST  /tasks/:id/complete
GET   /parent/summary?date=YYYY-MM-DD
GET   /rewards
```

## WebSocket Protocol

iOS to backend:

```json
{ "type": "session.start" }
{ "type": "audio.append", "audio": "<base64 pcm chunk>" }
{ "type": "audio.stop" }
{ "type": "response.cancel" }
{ "type": "session.end" }
```

Backend to iOS:

```json
{ "type": "state.changed", "state": "listening" }
{ "type": "transcript.delta", "text": "I found a red apple!" }
{ "type": "assistant.text.delta", "text": "Great job! Can you find something blue?" }
{ "type": "assistant.audio.delta", "audio": "<base64 pcm chunk>" }
{ "type": "reward.earned", "stars": 1, "totalStars": 18 }
{ "type": "error", "message": "..." }
```

## Verification

```sh
npm run build
```

Runtime verification requires MongoDB and Redis to be running.
