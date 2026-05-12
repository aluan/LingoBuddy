import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

@Injectable()
export class VideoChatService {
  private readonly logger = new Logger(VideoChatService.name);
  private readonly apiUrl = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
  private readonly model = 'doubao-seed-2-0-pro-260215';
  private readonly apiKey: string;

  constructor(private configService: ConfigService) {
    this.apiKey = this.configService.get<string>('DOUBAO_ARK_API_KEY') || '';
  }

  async chat(transcript: string, userMessage: string): Promise<string> {
    const systemPrompt = `You are an English learning assistant helping children understand a video.
The video transcript is provided below. Answer the user's question based on the video content.
Use simple, encouraging language suitable for children learning English.
Keep replies concise (2-4 sentences).

Video Transcript:
${transcript.substring(0, 4000)}`;

    try {
      const response = await axios.post(
        this.apiUrl,
        {
          model: this.model,
          messages: [
            { role: 'system', content: systemPrompt },
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
}
