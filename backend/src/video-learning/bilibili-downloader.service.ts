import { Injectable, Logger } from '@nestjs/common';
import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs';
import * as path from 'path';

const execAsync = promisify(exec);

interface VideoInfo {
  title: string;
  duration: number;
  thumbnailUrl?: string;
  videoId: string;
}

@Injectable()
export class BilibiliDownloaderService {
  private readonly logger = new Logger(BilibiliDownloaderService.name);
  private readonly tempDir = '/tmp/lingobuddy/videos';

  constructor() {
    // Ensure temp directory exists
    if (!fs.existsSync(this.tempDir)) {
      fs.mkdirSync(this.tempDir, { recursive: true });
    }
  }

  /**
   * Download audio from Bilibili video using yt-dlp
   */
  async downloadAudio(url: string, videoId: string): Promise<string> {
    this.logger.log(`Downloading audio for: ${videoId}`);

    const outputPath = path.join(this.tempDir, `${videoId}.m4a`);

    try {
      // Download best audio using yt-dlp
      const command = `yt-dlp -f "bestaudio" -o "${outputPath}" "${url}"`;

      this.logger.log(`Executing: ${command}`);
      const { stdout, stderr } = await execAsync(command, {
        timeout: 300000, // 5 minutes timeout
      });

      if (stderr) {
        this.logger.warn(`yt-dlp stderr: ${stderr}`);
      }

      this.logger.log(`yt-dlp stdout: ${stdout}`);

      if (!fs.existsSync(outputPath)) {
        throw new Error('Audio file not found after download');
      }

      this.logger.log(`Successfully downloaded audio: ${outputPath}`);
      return outputPath;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`Failed to download audio: ${errorMessage}`);
      throw error;
    }
  }

  /**
   * Convert audio to WAV format using ffmpeg
   */
  async convertToWav(inputPath: string, videoId: string): Promise<string> {
    this.logger.log(`Converting audio to WAV: ${videoId}`);

    const outputPath = path.join(this.tempDir, `${videoId}.wav`);

    try {
      // Convert to 16kHz mono WAV
      const command = `ffmpeg -i "${inputPath}" -ar 16000 -ac 1 "${outputPath}"`;

      this.logger.log(`Executing: ${command}`);
      const { stdout, stderr } = await execAsync(command, {
        timeout: 120000, // 2 minutes timeout
      });

      if (stderr) {
        this.logger.warn(`ffmpeg stderr: ${stderr}`);
      }

      if (!fs.existsSync(outputPath)) {
        throw new Error('WAV file not found after conversion');
      }

      // Delete original file
      fs.unlinkSync(inputPath);

      this.logger.log(`Successfully converted to WAV: ${outputPath}`);
      return outputPath;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`Failed to convert audio: ${errorMessage}`);
      throw error;
    }
  }

  /**
   * Get video metadata using yt-dlp
   */
  async getVideoInfo(url: string): Promise<VideoInfo> {
    this.logger.log(`Getting video info for: ${url}`);

    try {
      const command = `yt-dlp --dump-json "${url}"`;

      const { stdout } = await execAsync(command, { timeout: 30000 });
      const info = JSON.parse(stdout);

      return {
        title: info.title || 'Unknown',
        duration: info.duration || 0,
        thumbnailUrl: info.thumbnail,
        videoId: info.id || info.display_id,
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`Failed to get video info: ${errorMessage}`);
      throw error;
    }
  }

  /**
   * Clean up temporary audio file
   */
  async cleanupAudio(filePath: string): Promise<void> {
    try {
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
        this.logger.log(`Cleaned up audio file: ${filePath}`);
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      this.logger.warn(`Failed to cleanup audio file: ${errorMessage}`);
    }
  }

  /**
   * Check if yt-dlp is available
   */
  async checkYtDlpAvailable(): Promise<boolean> {
    try {
      await execAsync('yt-dlp --version', { timeout: 5000 });
      return true;
    } catch (error) {
      this.logger.warn('yt-dlp not available');
      return false;
    }
  }

  /**
   * Check if ffmpeg is available
   */
  async checkFfmpegAvailable(): Promise<boolean> {
    try {
      await execAsync('ffmpeg -version', { timeout: 5000 });
      return true;
    } catch (error) {
      this.logger.warn('ffmpeg not available');
      return false;
    }
  }
}
