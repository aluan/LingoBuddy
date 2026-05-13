import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosResponse } from 'axios';

interface ChatHistoryMessage {
  role: 'assistant' | 'user';
  content: string;
}

interface DoubaoStreamChunk {
  choices?: Array<{
    delta?: { content?: string };
    finish_reason?: string | null;
  }>;
}

@Injectable()
export class VideoChatService {
  private readonly logger = new Logger(VideoChatService.name);
  private readonly apiUrl = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
  private readonly model = 'doubao-seed-2-0-pro-260215';
  private readonly apiKey: string;

  constructor(private configService: ConfigService) {
    this.apiKey = this.configService.get<string>('DOUBAO_ARK_API_KEY') || '';
  }

  async chat(
    transcript: string,
    userMessage: string,
    history: ChatHistoryMessage[] = [],
  ): Promise<string> {
    const systemPrompt = this.buildSystemPrompt(transcript);

    try {
      const response = await axios.post(
        this.apiUrl,
        {
          model: this.model,
          messages: [
            { role: 'system', content: systemPrompt },
            ...history,
            { role: 'user', content: userMessage },
          ],
          temperature: 0.7,
          max_tokens: 300,
          thinking: { type: 'disabled' },
        },
        {
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${this.apiKey}`,
          },
          timeout: 30000,
        },
      );

      return response.data.choices[0].message.content;
    } catch (error) {
      const msg = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`Chat failed: ${msg}`);
      throw error;
    }
  }

  async *chatStream(
    transcript: string,
    userMessage: string,
    history: ChatHistoryMessage[] = [],
  ): AsyncGenerator<string> {
    const systemPrompt = this.buildSystemPrompt(transcript);

    try {
      const response: AxiosResponse<NodeJS.ReadableStream> = await axios.post(
        this.apiUrl,
        {
          model: this.model,
          messages: [
            { role: 'system', content: systemPrompt },
            ...history,
            { role: 'user', content: userMessage },
          ],
          temperature: 0.7,
          max_tokens: 300,
          thinking: { type: 'disabled' },
          stream: true,
        },
        {
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${this.apiKey}`,
          },
          responseType: 'stream',
          timeout: 30000,
        },
      );

      let buffer = '';
      for await (const chunk of response.data) {
        buffer += Buffer.isBuffer(chunk)
          ? chunk.toString('utf8')
          : String(chunk);

        const lines = buffer.split(/\r?\n/);
        buffer = lines.pop() ?? '';

        for (const line of lines) {
          const delta = this.parseStreamLine(line);
          if (delta) {
            yield delta;
          }
        }
      }

      const delta = this.parseStreamLine(buffer);
      if (delta) {
        yield delta;
      }
    } catch (error) {
      const msg = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`Streaming chat failed: ${msg}`);
      throw error;
    }
  }

  private buildSystemPrompt(transcript: string): string {
    return `You are an English learning assistant helping children understand a video.
The video transcript is provided below. Answer the user's question based on the video content.
Use simple, encouraging language suitable for children learning English.
Keep replies concise (2-4 sentences).

Video Transcript:
${transcript.substring(0, 4000)}`;
  }

  private parseStreamLine(line: string): string | undefined {
    const trimmed = line.trim();
    if (!trimmed.startsWith('data:')) {
      return undefined;
    }

    const payload = trimmed.slice(5).trim();
    if (!payload || payload === '[DONE]') {
      return undefined;
    }

    try {
      const parsed = JSON.parse(payload) as DoubaoStreamChunk;
      return parsed.choices?.[0]?.delta?.content;
    } catch {
      this.logger.warn(`Failed to parse stream chunk: ${payload}`);
      return undefined;
    }
  }
}
