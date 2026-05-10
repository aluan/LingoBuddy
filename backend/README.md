# LingoBuddy Backend

NestJS backend for the LingoBuddy MVP.

## Stack

- NestJS
- MongoDB
- Redis
- REST API for voice session management
- Doubao AI real-time voice (handled by iOS SDK)

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

## Environment

```text
PORT=3000
MONGODB_URI=mongodb://localhost:27017/lingobuddy
REDIS_URL=redis://localhost:6379
```

## REST API

```text
GET   /profile/current
PATCH /profile/current
GET   /home/today
GET   /tasks/today
POST  /tasks/:id/complete
GET   /parent/summary?date=YYYY-MM-DD
GET   /rewards

POST  /voice/sessions/start
POST  /voice/sessions/:sessionId/transcript
POST  /voice/sessions/:sessionId/reward
POST  /voice/sessions/:sessionId/end
```

## Voice Session API

### Start Session
```json
POST /voice/sessions/start
Body: { "taskId": "optional-task-id" }
Response: { "sessionId": "uuid", "conversationId": "uuid", "taskId": "uuid" }
```

### Save Transcript
```json
POST /voice/sessions/:sessionId/transcript
Body: { "text": "I found a red apple!", "role": "child" }
Response: { "messageId": "uuid" }
```

### Grant Reward
```json
POST /voice/sessions/:sessionId/reward
Body: { "stars": 1 }
Response: { "totalStars": 18, "progress": { "speakingTurns": 5, "stars": 18 } }
```

### End Session
```json
POST /voice/sessions/:sessionId/end
Response: { "conversationId": "uuid", "summary": "Session completed in 45 seconds" }
```

## Verification

```sh
npm run build
```

Runtime verification requires MongoDB and Redis to be running.
