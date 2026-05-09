import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Server as HttpServer, IncomingMessage } from 'http';
import Redis from 'ioredis';
import { RawData, WebSocket, WebSocketServer } from 'ws';
import { REDIS_CLIENT } from '../redis/redis.module';
import { ProfilesService } from '../profiles/profiles.service';
import { TasksService } from '../tasks/tasks.service';
import { ProgressService } from '../progress/progress.service';
import { ConversationsService } from '../conversations/conversations.service';
import { RewardsService } from '../rewards/rewards.service';

type ClientEvent =
  | { type: 'session.start'; taskId?: string }
  | { type: 'audio.append'; audio: string }
  | { type: 'audio.stop' }
  | { type: 'response.cancel' }
  | { type: 'session.end' };

type GlmTurnState = {
  responseActive: boolean;
  responseRequested: boolean;
  responseHadOutput: boolean;
  responseAudioChunkCount: number;
  responseAudioByteCount: number;
  responseTextChunkCount: number;
  localSpeechStarted: boolean;
  lastLocalSpeechAt: number;
  audioStartedAt: number;
  receivedAudioChunks: number;
};

@Injectable()
export class VoiceRealtimeServer {
  private readonly logger = new Logger(VoiceRealtimeServer.name);
  private readonly wss = new WebSocketServer({ noServer: true });

  constructor(
    private readonly config: ConfigService,
    private readonly profiles: ProfilesService,
    private readonly tasks: TasksService,
    private readonly progress: ProgressService,
    private readonly conversations: ConversationsService,
    private readonly rewards: RewardsService,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
  ) {
    this.wss.on('connection', (socket) => {
      void this.handleClient(socket);
    });
  }

  attach(server: HttpServer) {
    server.on('upgrade', (request: IncomingMessage, socket, head) => {
      if (request.url?.startsWith('/voice/realtime')) {
        this.wss.handleUpgrade(request, socket, head, (ws) => {
          this.wss.emit('connection', ws, request);
        });
        return;
      }

      socket.destroy();
    });
  }

  private async handleClient(client: WebSocket) {
    const sessionId = crypto.randomUUID();
    let conversationId: string | undefined;
    let profileId: string | undefined;
    let glm: WebSocket | undefined;
    let mockReplyTimer: NodeJS.Timeout | undefined;
    let audioChunkCount = 0;
    const glmState: GlmTurnState = {
      responseActive: false,
      responseRequested: false,
      responseHadOutput: false,
      responseAudioChunkCount: 0,
      responseAudioByteCount: 0,
      responseTextChunkCount: 0,
      localSpeechStarted: false,
      lastLocalSpeechAt: 0,
      audioStartedAt: 0,
      receivedAudioChunks: 0,
    };

    client.on('message', (data) => {
      void (async () => {
        const event = this.parseClientEvent(data);
        if (!event) return;

        switch (event.type) {
        case 'session.start': {
          this.logger.log(`voice ${sessionId}: session.start`);
          const profile = await this.profiles.getCurrentProfile();
          const todayTask = event.taskId ? undefined : await this.tasks.getTodayTask();
          const taskId = event.taskId ?? todayTask?.id;
          const conversation = await this.conversations.start(profile.id, taskId);
          profileId = profile.id;
          conversationId = conversation.id;

          this.send(client, {
            type: 'state.changed',
            state: 'thinking',
            sessionId,
            conversationId,
            taskId,
          });

          if (this.shouldMockGlm()) {
            this.send(client, { type: 'assistant.text.delta', text: 'Hi! Ready for a dragon quest?' });
            this.send(client, { type: 'state.changed', state: 'listening' });
          } else {
            glm = this.connectGlm(client, glmState, sessionId);
          }
          break;
        }

        case 'audio.append':
          if (glm?.readyState === WebSocket.OPEN) {
            audioChunkCount += 1;
            glmState.receivedAudioChunks += 1;
            const level = this.pcmLevel(event.audio);
            this.updateLocalVad(glm, glmState, level);

            if (audioChunkCount === 1 || audioChunkCount % 50 === 0) {
              this.logger.log(`voice ${sessionId}: forwarded ${audioChunkCount} audio chunks, level=${level.toFixed(4)}`);
            }

            glm.send(JSON.stringify({ type: 'input_audio_buffer.append', audio: event.audio }));
          }
          break;

        case 'audio.stop':
          if (glm?.readyState === WebSocket.OPEN) {
            this.requestGlmResponse(glm, glmState, 'client_audio_stop');
          } else if (this.shouldMockGlm()) {
            mockReplyTimer = setTimeout(() => {
              void this.emitMockTurn(client, conversationId, profileId);
            }, 450);
          } else {
            this.send(client, { type: 'error', message: 'GLM realtime connection is not ready' });
          }
          break;

        case 'response.cancel':
          if (glm?.readyState === WebSocket.OPEN) {
            glm.send(JSON.stringify({ type: 'response.cancel' }));
          }
          this.send(client, { type: 'state.changed', state: 'listening' });
          break;

        case 'session.end':
          client.close(1000, 'session ended');
          break;
        }
      })().catch((error: unknown) => this.sendError(client, error));
    });

    void this.safeRedisSet(`voice:${sessionId}`, 'connected', 60);
    this.send(client, { type: 'state.changed', state: 'connected', sessionId });

    client.on('close', () => {
      if (mockReplyTimer) clearTimeout(mockReplyTimer);
      glm?.close();
      if (conversationId) {
        void this.conversations.end(conversationId);
      }
      void this.safeRedisSet(`voice:${sessionId}`, 'closed', 30);
    });
  }

  private connectGlm(client: WebSocket, glmState: GlmTurnState, sessionId: string): WebSocket {
    const apiKey = this.config.get<string>('ZHIPU_API_KEY');
    const model = this.config.get<string>('GLM_REALTIME_MODEL') ?? 'glm-realtime-flash';
    const url = 'wss://open.bigmodel.cn/api/paas/v4/realtime';
    const glm = new WebSocket(url, {
      headers: {
        Authorization: `Bearer ${apiKey}`,
      },
    });

    glm.on('open', () => {
      this.logger.log('GLM realtime socket open');
      this.send(client, { type: 'state.changed', state: 'listening' });
    });

    glm.on('message', (raw) => {
      if (this.forwardGlmEvent(client, glm, raw, glmState, sessionId)) {
        return;
      }

      const event = this.parseGlmEvent(raw);
      if (event?.type === 'session.created') {
        glm.send(JSON.stringify({
          event_id: crypto.randomUUID(),
          client_timestamp: Date.now(),
          type: 'session.update',
          session: {
            model,
            modalities: ['audio', 'text'],
            instructions: dinoPrompt(),
            voice: 'lovely_girl',
            input_audio_format: 'pcm16',
            output_audio_format: 'pcm',
            input_audio_noise_reduction: {
              type: 'far_field',
            },
            beta_fields: {
              chat_mode: 'audio',
              tts_source: 'e2e',
            },
          },
        }));
      }
    });
    glm.on('error', (error) => this.sendError(client, error));
    glm.on('close', (code, reason) => this.send(client, {
      type: 'state.changed',
      state: 'disconnected',
      code,
      reason: reason.toString(),
    }));

    return glm;
  }

  private async emitMockTurn(client: WebSocket, conversationId?: string, profileId?: string) {
    const childText = 'I found a red apple!';
    const astraText = 'Great job! Can you find something blue?';

    if (conversationId) {
      await this.conversations.addMessage(conversationId, 'child', childText);
      await this.conversations.addMessage(conversationId, 'astra', astraText);
    }

    let rewardStars = 0;
    if (profileId) {
      const progress = await this.progress.addSpeakingTurn(profileId);
      await this.rewards.grantStars(profileId, 1);
      rewardStars = progress.stars;
    }

    this.send(client, { type: 'transcript.delta', text: childText });
    this.send(client, { type: 'state.changed', state: 'speaking' });
    this.send(client, { type: 'assistant.text.delta', text: astraText });
    this.send(client, { type: 'reward.earned', stars: 1, totalStars: rewardStars });
    this.send(client, { type: 'state.changed', state: 'listening' });
  }

  private forwardGlmEvent(client: WebSocket, glm: WebSocket, raw: RawData, state: GlmTurnState, sessionId: string): boolean {
    const event = this.parseGlmEvent(raw);
    if (!event) {
      this.send(client, { type: 'debug.raw', payload: raw.toString() });
      return true;
    }

    switch (event.type) {
    case 'session.created':
    case 'session.updated':
      this.logger.log(`GLM event: ${event.type}`);
      return false;
    case 'input_audio_buffer.speech_started':
      this.logger.log('GLM event: speech_started');
      this.send(client, { type: 'state.changed', state: 'listening' });
      return true;
    case 'input_audio_buffer.speech_stopped':
      this.logger.log('GLM event: speech_stopped');
      this.send(client, { type: 'state.changed', state: 'thinking' });
      this.requestGlmResponse(glm, state, 'glm_speech_stopped');
      return true;
    case 'response.created':
      state.responseActive = true;
      state.responseRequested = true;
      state.responseHadOutput = false;
      state.responseAudioChunkCount = 0;
      state.responseAudioByteCount = 0;
      state.responseTextChunkCount = 0;
      state.localSpeechStarted = false;
      state.audioStartedAt = 0;
      state.receivedAudioChunks = 0;
      this.logger.log('GLM event: response.created');
      this.send(client, { type: 'state.changed', state: 'speaking' });
      return true;
    case 'response.audio.delta':
      if (typeof event.delta !== 'string' && typeof event.audio !== 'string') {
        this.logger.warn(`voice ${sessionId}: response.audio.delta without audio payload`);
        return true;
      }
      state.responseHadOutput = true;
      state.responseAudioChunkCount += 1;
      state.responseAudioByteCount += Buffer.from(event.delta ?? event.audio ?? '', 'base64').length;
      if (state.responseAudioChunkCount === 1 || state.responseAudioChunkCount % 25 === 0) {
        this.logger.log(
          `voice ${sessionId}: received ${state.responseAudioChunkCount} audio deltas, ${state.responseAudioByteCount} bytes`,
        );
      }
      this.send(client, { type: 'state.changed', state: 'speaking' });
      this.send(client, { type: 'assistant.audio.delta', audio: event.delta ?? event.audio });
      this.send(client, {
        type: 'assistant.audio.stats',
        chunks: state.responseAudioChunkCount,
        bytes: state.responseAudioByteCount,
      });
      return true;
    case 'response.audio_transcript.delta':
      state.responseHadOutput = true;
      return true;
    case 'response.audio_transcript.done':
      state.responseHadOutput = true;
      if (state.responseTextChunkCount === 0 && typeof event.transcript === 'string') {
        this.send(client, { type: 'assistant.text.delta', text: event.transcript });
      }
      return true;
    case 'response.text.delta':
      state.responseHadOutput = true;
      state.responseTextChunkCount += 1;
      this.send(client, { type: 'assistant.text.delta', text: event.delta, isDelta: true });
      return true;
    case 'conversation.item.input_audio_transcription.completed':
      this.logger.log(`GLM transcript: ${event.transcript ?? ''}`);
      this.send(client, { type: 'transcript.delta', text: event.transcript });
      return true;
    case 'response.done':
      state.responseActive = false;
      state.responseRequested = false;
      state.audioStartedAt = 0;
      state.receivedAudioChunks = 0;
      this.logger.log(
        `GLM event: response.done, audioDeltas=${state.responseAudioChunkCount}, audioBytes=${state.responseAudioByteCount}`,
      );
      if (!state.responseHadOutput) {
        this.send(client, { type: 'assistant.text.delta', text: "I didn't catch that. Try one more time." });
      }
      this.send(client, { type: 'state.changed', state: 'listening' });
      return true;
    case 'response.audio.done':
      this.send(client, { type: 'state.changed', state: 'listening' });
      return true;
    case 'error':
      this.send(client, { type: 'error', message: this.extractGlmErrorMessage(event.error) });
      return true;
    default:
      this.send(client, { type: 'glm.event', event });
      return false;
    }
  }

  private updateLocalVad(glm: WebSocket, state: GlmTurnState, level: number) {
    const now = Date.now();
    const speechThreshold = 0.004;
    const silenceMs = 900;
    const lowLevelFallbackChunks = 24;

    if (state.audioStartedAt === 0) {
      state.audioStartedAt = now;
    }

    if (level >= speechThreshold) {
      state.localSpeechStarted = true;
      state.lastLocalSpeechAt = now;
      if (!state.responseActive) {
        state.responseRequested = false;
      }
      return;
    }

    if (
      state.localSpeechStarted &&
      !state.responseActive &&
      !state.responseRequested &&
      now - state.lastLocalSpeechAt >= silenceMs
    ) {
      state.localSpeechStarted = false;
      this.requestGlmResponse(glm, state, 'local_silence');
    }

    if (
      !state.responseActive &&
      !state.responseRequested &&
      !state.localSpeechStarted &&
      state.receivedAudioChunks >= lowLevelFallbackChunks
    ) {
      this.requestGlmResponse(glm, state, 'low_level_audio_fallback');
    }
  }

  private requestGlmResponse(glm: WebSocket, state: GlmTurnState, reason: string) {
    if (state.responseActive || state.responseRequested || glm.readyState !== WebSocket.OPEN) {
      return;
    }

    state.responseRequested = true;
    this.logger.log(`GLM response.create requested by ${reason}`);
    glm.send(JSON.stringify({
      event_id: crypto.randomUUID(),
      client_timestamp: Date.now(),
      type: 'input_audio_buffer.commit',
    }));
    glm.send(JSON.stringify({
      event_id: crypto.randomUUID(),
      client_timestamp: Date.now(),
      type: 'response.create',
    }));
  }

  private pcmLevel(base64Audio: string): number {
    const buffer = Buffer.from(base64Audio, 'base64');
    let sumSquares = 0;
    let sampleCount = 0;

    for (let index = 0; index + 1 < buffer.length; index += 2) {
      const sample = buffer.readInt16LE(index) / 32768;
      sumSquares += sample * sample;
      sampleCount += 1;
    }

    return sampleCount > 0 ? Math.sqrt(sumSquares / sampleCount) : 0;
  }

  private extractGlmErrorMessage(error: unknown): string {
    if (typeof error === 'string') {
      return error;
    }

    if (error && typeof error === 'object' && 'message' in error) {
      const message = (error as { message?: unknown }).message;
      if (typeof message === 'string') {
        return message;
      }
    }

    return 'GLM realtime error';
  }

  private parseGlmEvent(raw: RawData): { type?: string; delta?: string; transcript?: string; audio?: string; error?: unknown } | undefined {
    try {
      return JSON.parse(raw.toString()) as { type?: string; delta?: string; transcript?: string; audio?: string; error?: unknown };
    } catch {
      return undefined;
    }
  }

  private shouldMockGlm(): boolean {
    const explicit = this.config.get<string>('GLM_REALTIME_MOCK');
    const apiKey = this.config.get<string>('ZHIPU_API_KEY');
    return explicit === 'true' || !apiKey;
  }

  private parseClientEvent(data: RawData): ClientEvent | undefined {
    try {
      const parsed = JSON.parse(data.toString()) as ClientEvent;
      if (!parsed.type) return undefined;
      return parsed;
    } catch {
      return undefined;
    }
  }

  private send(client: WebSocket, payload: unknown) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(payload));
    }
  }

  private sendError(client: WebSocket, error: unknown) {
    const message = error instanceof Error ? error.message : 'Unknown realtime error';
    this.logger.error(message);
    this.send(client, { type: 'error', message });
  }

  private async safeRedisSet(key: string, value: string, seconds: number) {
    try {
      await this.redis.set(key, value, 'EX', seconds);
    } catch {
      // Redis is useful for realtime state, but local mock mode should still run without it.
    }
  }
}

function dinoPrompt(): string {
  return [
    'You are Astra, a brave and friendly dragon rider.',
    'You talk to a 6-year-old child learning English.',
    'Use short English sentences.',
    'Use simple vocabulary.',
    'Always encourage.',
    'Never criticize.',
    'Keep conversation playful.',
    'Ask only one question at a time.',
    'Keep replies under 12 words.',
  ].join('\n');
}
