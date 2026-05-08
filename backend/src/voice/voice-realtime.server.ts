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

    await this.safeRedisSet(`voice:${sessionId}`, 'connected', 60);
    this.send(client, { type: 'state.changed', state: 'connected', sessionId });

    client.on('message', (data) => {
      void (async () => {
        const event = this.parseClientEvent(data);
        if (!event) return;

        switch (event.type) {
        case 'session.start': {
          const profile = await this.profiles.getCurrentProfile();
          const todayTask = event.taskId ? undefined : await this.tasks.getTodayTask();
          const taskId = event.taskId ?? todayTask?.id;
          const conversation = await this.conversations.start(profile.id, taskId);
          profileId = profile.id;
          conversationId = conversation.id;

          this.send(client, {
            type: 'state.changed',
            state: 'listening',
            sessionId,
            conversationId,
            taskId,
          });

          if (this.shouldMockGlm()) {
            this.send(client, { type: 'assistant.text.delta', text: 'Hi! Ready for a dragon quest?' });
          } else {
            glm = this.connectGlm(client);
          }
          break;
        }

        case 'audio.append':
          if (glm?.readyState === WebSocket.OPEN) {
            glm.send(JSON.stringify({ type: 'input_audio_buffer.append', audio: event.audio }));
          }
          break;

        case 'audio.stop':
          if (glm?.readyState === WebSocket.OPEN) {
            glm.send(JSON.stringify({ type: 'input_audio_buffer.commit' }));
            glm.send(JSON.stringify({ type: 'response.create' }));
          } else {
            mockReplyTimer = setTimeout(() => {
              void this.emitMockTurn(client, conversationId, profileId);
            }, 450);
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

    client.on('close', () => {
      if (mockReplyTimer) clearTimeout(mockReplyTimer);
      glm?.close();
      if (conversationId) {
        void this.conversations.end(conversationId);
      }
      void this.safeRedisSet(`voice:${sessionId}`, 'closed', 30);
    });
  }

  private connectGlm(client: WebSocket): WebSocket {
    const apiKey = this.config.get<string>('ZHIPU_API_KEY');
    const model = this.config.get<string>('GLM_REALTIME_MODEL') ?? 'glm-realtime-flash';
    const url = `wss://open.bigmodel.cn/api/paas/v4/realtime?model=${encodeURIComponent(model)}`;
    const glm = new WebSocket(url, {
      headers: {
        Authorization: `Bearer ${apiKey}`,
      },
    });

    glm.on('open', () => {
      glm.send(JSON.stringify({
        type: 'session.update',
        session: {
          modalities: ['text', 'audio'],
          input_audio_format: 'pcm',
          output_audio_format: 'pcm',
          turn_detection: {
            type: 'server_vad',
            create_response: true,
            interrupt_response: true,
            prefix_padding_ms: 300,
            silence_duration_ms: 500,
            threshold: 0.5,
          },
          instructions: dinoPrompt(),
        },
      }));
      this.send(client, { type: 'state.changed', state: 'listening' });
    });

    glm.on('message', (raw) => this.forwardGlmEvent(client, raw));
    glm.on('error', (error) => this.sendError(client, error));
    glm.on('close', () => this.send(client, { type: 'state.changed', state: 'disconnected' }));

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

  private forwardGlmEvent(client: WebSocket, raw: RawData) {
    const text = raw.toString();
    let event: { type?: string; delta?: string; transcript?: string; audio?: string };
    try {
      event = JSON.parse(text) as { type?: string; delta?: string; transcript?: string; audio?: string };
    } catch {
      this.send(client, { type: 'debug.raw', payload: text });
      return;
    }

    switch (event.type) {
    case 'response.audio.delta':
      this.send(client, { type: 'assistant.audio.delta', audio: event.delta ?? event.audio });
      break;
    case 'response.audio_transcript.delta':
    case 'response.text.delta':
      this.send(client, { type: 'assistant.text.delta', text: event.delta });
      break;
    case 'conversation.item.input_audio_transcription.completed':
      this.send(client, { type: 'transcript.delta', text: event.transcript });
      break;
    default:
      this.send(client, { type: 'glm.event', event });
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
