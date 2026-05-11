import { Injectable, Logger } from '@nestjs/common';
import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs';
import * as path from 'path';

const execAsync = promisify(exec);

interface VideoMetadata {
  title: string;
  duration: number;
  thumbnailUrl?: string;
  videoId: string;
}

interface SubtitleResult {
  text: string;
  segments: { startTime: number; endTime: number; text: string }[];
  metadata: VideoMetadata;
}

@Injectable()
export class BilibiliSubtitleService {
  private readonly logger = new Logger(BilibiliSubtitleService.name);
  private readonly tempDir = '/tmp/lingobuddy/subtitles';

  constructor() {
    // Ensure temp directory exists
    if (!fs.existsSync(this.tempDir)) {
      fs.mkdirSync(this.tempDir, { recursive: true });
    }
  }

  /**
   * Download subtitle using bili command
   */
  async downloadSubtitle(url: string, videoId: string): Promise<SubtitleResult> {
    this.logger.log(`Downloading subtitle for: ${videoId}`);

    const outputPath = path.join(this.tempDir, videoId);

    try {
      // Try to download subtitle using bili command
      // bili command format: bili get <url> --subtitle
      const command = `bili get "${url}" --subtitle --output "${outputPath}"`;

      this.logger.log(`Executing: ${command}`);
      const { stdout, stderr } = await execAsync(command, {
        timeout: 60000, // 60 seconds timeout
      });

      if (stderr) {
        this.logger.warn(`bili stderr: ${stderr}`);
      }

      this.logger.log(`bili stdout: ${stdout}`);

      // Find subtitle file (usually .srt or .json)
      const files = fs.readdirSync(this.tempDir);
      const subtitleFile = files.find(
        (f) =>
          f.startsWith(videoId) &&
          (f.endsWith('.srt') || f.endsWith('.json') || f.endsWith('.ass')),
      );

      if (!subtitleFile) {
        throw new Error('Subtitle file not found after download');
      }

      const subtitlePath = path.join(this.tempDir, subtitleFile);
      const subtitleContent = fs.readFileSync(subtitlePath, 'utf-8');

      // Parse subtitle based on format
      let result: SubtitleResult;
      if (subtitleFile.endsWith('.srt')) {
        result = this.parseSRT(subtitleContent, videoId);
      } else if (subtitleFile.endsWith('.json')) {
        result = this.parseJSON(subtitleContent, videoId);
      } else {
        throw new Error(`Unsupported subtitle format: ${subtitleFile}`);
      }

      // Get video metadata
      result.metadata = await this.getVideoMetadata(url, videoId);

      // Clean up subtitle file
      fs.unlinkSync(subtitlePath);

      this.logger.log(`Successfully downloaded subtitle for: ${videoId}`);
      return result;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`Failed to download subtitle: ${errorMessage}`);
      throw error;
    }
  }

  /**
   * Parse SRT subtitle format
   */
  private parseSRT(content: string, videoId: string): SubtitleResult {
    const segments: { startTime: number; endTime: number; text: string }[] = [];
    const blocks = content.trim().split('\n\n');

    for (const block of blocks) {
      const lines = block.split('\n');
      if (lines.length < 3) continue;

      // Parse timestamp line (e.g., "00:00:01,000 --> 00:00:03,000")
      const timestampLine = lines[1];
      const timestampMatch = timestampLine.match(
        /(\d{2}):(\d{2}):(\d{2}),(\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2}),(\d{3})/,
      );

      if (!timestampMatch) continue;

      const startTime =
        parseInt(timestampMatch[1]) * 3600 +
        parseInt(timestampMatch[2]) * 60 +
        parseInt(timestampMatch[3]) +
        parseInt(timestampMatch[4]) / 1000;

      const endTime =
        parseInt(timestampMatch[5]) * 3600 +
        parseInt(timestampMatch[6]) * 60 +
        parseInt(timestampMatch[7]) +
        parseInt(timestampMatch[8]) / 1000;

      const text = lines.slice(2).join(' ').trim();

      segments.push({ startTime, endTime, text });
    }

    const fullText = segments.map((s) => s.text).join(' ');

    return {
      text: fullText,
      segments,
      metadata: {
        title: 'Unknown',
        duration: segments.length > 0 ? segments[segments.length - 1].endTime : 0,
        videoId,
      },
    };
  }

  /**
   * Parse JSON subtitle format (Bilibili format)
   */
  private parseJSON(content: string, videoId: string): SubtitleResult {
    try {
      const data = JSON.parse(content);
      const segments: { startTime: number; endTime: number; text: string }[] = [];

      // Bilibili JSON format: { body: [{ from, to, content }] }
      if (data.body && Array.isArray(data.body)) {
        for (const item of data.body) {
          segments.push({
            startTime: item.from || 0,
            endTime: item.to || 0,
            text: item.content || '',
          });
        }
      }

      const fullText = segments.map((s) => s.text).join(' ');

      return {
        text: fullText,
        segments,
        metadata: {
          title: 'Unknown',
          duration: segments.length > 0 ? segments[segments.length - 1].endTime : 0,
          videoId,
        },
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      throw new Error(`Failed to parse JSON subtitle: ${errorMessage}`);
    }
  }

  /**
   * Get video metadata using bili command
   */
  private async getVideoMetadata(url: string, videoId: string): Promise<VideoMetadata> {
    try {
      // Use bili info command to get metadata
      const command = `bili info "${url}"`;
      const { stdout } = await execAsync(command, { timeout: 30000 });

      // Parse output (format may vary, adjust as needed)
      const titleMatch = stdout.match(/Title:\s*(.+)/i);
      const durationMatch = stdout.match(/Duration:\s*(\d+)/i);

      return {
        title: titleMatch ? titleMatch[1].trim() : 'Unknown',
        duration: durationMatch ? parseInt(durationMatch[1]) : 0,
        videoId,
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      this.logger.warn(`Failed to get video metadata: ${errorMessage}`);
      return {
        title: 'Unknown',
        duration: 0,
        videoId,
      };
    }
  }

  /**
   * Check if bili command is available
   */
  async checkBiliAvailable(): Promise<boolean> {
    try {
      await execAsync('bili --version', { timeout: 5000 });
      return true;
    } catch (error) {
      this.logger.warn('bili command not available');
      return false;
    }
  }
}
