import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import * as fs from 'fs';
import * as FormData from 'form-data';

interface TranscriptSegment {
  startTime: number;
  endTime: number;
  text: string;
}

interface TranscriptResult {
  text: string;
  segments: TranscriptSegment[];
}

@Injectable()
export class DoubaoAsrService {
  private readonly logger = new Logger(DoubaoAsrService.name);
  private readonly asrApiUrl: string;
  private readonly appId: string;
  private readonly token: string;

  constructor(private configService: ConfigService) {
    this.asrApiUrl =
      this.configService.get<string>('DOUBAO_ASR_API_URL') ||
      'https://openspeech.bytedance.com/api/v1/asr';
    this.appId = this.configService.get<string>('DOUBAO_APP_ID') || '';
    this.token = this.configService.get<string>('DOUBAO_TOKEN') || '';
  }

  /**
   * Transcribe audio file using Doubao ASR API
   */
  async transcribe(audioFilePath: string): Promise<TranscriptResult> {
    this.logger.log(`Transcribing audio: ${audioFilePath}`);

    try {
      // Check file size
      const stats = fs.statSync(audioFilePath);
      const fileSizeInMB = stats.size / (1024 * 1024);
      this.logger.log(`Audio file size: ${fileSizeInMB.toFixed(2)} MB`);

      // If file is too large, split it
      if (fileSizeInMB > 50) {
        return await this.transcribeLargeFile(audioFilePath);
      }

      // Create form data
      const formData = new FormData();
      formData.append('audio', fs.createReadStream(audioFilePath));
      formData.append('format', 'wav');
      formData.append('language', 'en');
      formData.append('enable_timestamp', 'true');

      // Call ASR API
      const response = await axios.post(this.asrApiUrl, formData, {
        headers: {
          Authorization: `Bearer ${this.token}`,
          'X-App-Id': this.appId,
          ...formData.getHeaders(),
        },
        timeout: 300000, // 5 minutes
      });

      if (response.data.code !== 0) {
        throw new Error(`ASR API error: ${response.data.message}`);
      }

      // Parse result
      const result = response.data.result;
      const segments: TranscriptSegment[] = [];

      if (result.segments && Array.isArray(result.segments)) {
        for (const seg of result.segments) {
          segments.push({
            startTime: seg.start_time || 0,
            endTime: seg.end_time || 0,
            text: seg.text || '',
          });
        }
      }

      const fullText = result.text || segments.map((s) => s.text).join(' ');

      this.logger.log(`Successfully transcribed audio, length: ${fullText.length} chars`);

      return {
        text: fullText,
        segments,
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`Failed to transcribe audio: ${errorMessage}`);
      throw error;
    }
  }

  /**
   * Transcribe large audio file by splitting it into chunks
   */
  private async transcribeLargeFile(audioFilePath: string): Promise<TranscriptResult> {
    this.logger.log(`Transcribing large audio file: ${audioFilePath}`);

    // TODO: Implement audio splitting and parallel transcription
    // For now, just try to transcribe the whole file
    throw new Error('Large file transcription not yet implemented');
  }

  /**
   * Check if Doubao ASR is configured
   */
  isConfigured(): boolean {
    return !!(this.appId && this.token);
  }
}
