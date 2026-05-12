import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import * as fs from 'fs';
import { randomUUID } from 'crypto';

interface TranscriptSegment {
  startTime: number;
  endTime: number;
  text: string;
}

interface TranscriptResult {
  text: string;
  segments: TranscriptSegment[];
}

const ASR_ENDPOINT =
  'https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash';

@Injectable()
export class DoubaoAsrService {
  private readonly logger = new Logger(DoubaoAsrService.name);
  private readonly appId: string;
  private readonly token: string;
  private readonly resourceId: string;

  constructor(private configService: ConfigService) {
    this.appId = this.configService.get<string>('DOUBAO_ASR_APP_ID') || '';
    this.token = this.configService.get<string>('DOUBAO_ASR_TOKEN') || '';
    this.resourceId =
      this.configService.get<string>('DOUBAO_ASR_RESOURCE_ID') ||
      'volc.bigasr.auc_turbo';
  }

  async transcribe(audioFilePath: string): Promise<TranscriptResult> {
    this.logger.log(`Transcribing audio: ${audioFilePath}`);

    const stats = fs.statSync(audioFilePath);
    const fileSizeMB = stats.size / (1024 * 1024);
    this.logger.log(`Audio file size: ${fileSizeMB.toFixed(2)} MB`);

    if (fileSizeMB > 100) {
      throw new Error(`Audio file too large: ${fileSizeMB.toFixed(1)} MB (max 100 MB)`);
    }

    const audioBase64 = fs.readFileSync(audioFilePath).toString('base64');

    const body = {
      user: { uid: this.appId },
      audio: { data: audioBase64 },
      request: { model_name: 'bigmodel' },
    };

    const response = await axios.post(ASR_ENDPOINT, body, {
      headers: {
        'Content-Type': 'application/json',
        'X-Api-App-Key': this.appId,
        'X-Api-Access-Key': this.token,
        'X-Api-Resource-Id': this.resourceId,
        'X-Api-Request-Id': randomUUID(),
        'X-Api-Sequence': '-1',
      },
      timeout: 300000,
    });

    const statusCode = response.headers['x-api-status-code'];
    if (statusCode && statusCode !== '20000000') {
      throw new Error(
        `ASR API error: status=${statusCode} message=${response.headers['x-api-message'] ?? 'unknown'}`,
      );
    }

    const result = response.data?.result;
    if (!result) {
      throw new Error('ASR API returned empty result');
    }

    const segments: TranscriptSegment[] = (result.utterances ?? []).map(
      (u: { start_time: number; end_time: number; text: string }) => ({
        startTime: u.start_time,
        endTime: u.end_time,
        text: u.text,
      }),
    );

    const text: string =
      result.text || segments.map((s) => s.text).join(' ');

    this.logger.log(`Transcription done, ${text.length} chars`);
    return { text, segments };
  }

  isConfigured(): boolean {
    return !!(this.appId && this.token);
  }
}
