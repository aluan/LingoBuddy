import { Injectable, Logger } from '@nestjs/common';
import { Queue, Job } from 'bull';
import { InjectQueue } from '@nestjs/bull';
import { VideoLearningService } from './video-learning.service';
import { BilibiliSubtitleService } from './bilibili-subtitle.service';
import { BilibiliDownloaderService } from './bilibili-downloader.service';
import { DoubaoAsrService } from './doubao-asr.service';

interface VideoProcessingJob {
  videoId: string;
  url: string;
  bvId: string;
}

@Injectable()
export class VideoProcessorService {
  private readonly logger = new Logger(VideoProcessorService.name);

  constructor(
    @InjectQueue('video-processing') private videoQueue: Queue,
    private videoLearningService: VideoLearningService,
    private subtitleService: BilibiliSubtitleService,
    private downloaderService: BilibiliDownloaderService,
    private asrService: DoubaoAsrService,
  ) {
    this.setupQueueProcessor();
  }

  /**
   * Enqueue video processing job
   */
  async enqueueVideo(videoId: string, url: string, bvId: string): Promise<void> {
    await this.videoQueue.add(
      'process-video',
      { videoId, url, bvId } as VideoProcessingJob,
      {
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 5000,
        },
      },
    );

    this.logger.log(`Enqueued video processing: ${videoId}`);
  }

  /**
   * Setup queue processor
   */
  private setupQueueProcessor(): void {
    this.videoQueue.process('process-video', async (job: Job<VideoProcessingJob>) => {
      const { videoId, url, bvId } = job.data;

      this.logger.log(`Processing video: ${videoId}`);

      try {
        // Update status to processing
        await this.videoLearningService.updateTranscript(videoId, {
          transcriptStatus: 'processing',
        });

        // Step 1: Try to download subtitle first (priority)
        let transcriptResult = null;
        let source: 'subtitle' | 'asr' = 'subtitle';

        try {
          this.logger.log(`Attempting to download subtitle for: ${bvId}`);
          transcriptResult = await this.subtitleService.downloadSubtitle(url, bvId);
          this.logger.log(`Successfully got subtitle for: ${bvId}`);
        } catch (subtitleError) {
          const errorMessage = subtitleError instanceof Error ? subtitleError.message : 'Unknown error';
          this.logger.warn(`Subtitle download failed: ${errorMessage}`);
          this.logger.log(`Falling back to audio download + ASR`);

          // Step 2: Fallback to audio download + ASR
          source = 'asr';

          // Download audio
          const audioPath = await this.downloaderService.downloadAudio(url, bvId);

          // Convert to WAV
          const wavPath = await this.downloaderService.convertToWav(audioPath, bvId);

          // Transcribe using ASR
          const asrResult = await this.asrService.transcribe(wavPath);

          // Get video metadata
          const videoInfo = await this.downloaderService.getVideoInfo(url);

          transcriptResult = {
            text: asrResult.text,
            segments: asrResult.segments,
            metadata: videoInfo,
          };

          // Clean up audio file
          await this.downloaderService.cleanupAudio(wavPath);
        }

        // Update video with transcript
        await this.videoLearningService.updateTranscript(videoId, {
          transcriptStatus: 'completed',
          transcriptSource: source,
          transcriptText: transcriptResult.text,
          transcriptSegments: transcriptResult.segments,
          title: transcriptResult.metadata.title,
          duration: transcriptResult.metadata.duration,
          thumbnailUrl: transcriptResult.metadata.thumbnailUrl,
        });

        this.logger.log(`Successfully processed video: ${videoId}, source: ${source}`);
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        this.logger.error(`Failed to process video ${videoId}: ${errorMessage}`);

        // Update status to failed
        await this.videoLearningService.updateTranscript(videoId, {
          transcriptStatus: 'failed',
          transcriptError: errorMessage,
        });

        throw error;
      }
    });

    // Queue event listeners
    this.videoQueue.on('completed', (job: Job) => {
      this.logger.log(`Job completed: ${job.id}`);
    });

    this.videoQueue.on('failed', (job: Job, error: Error) => {
      this.logger.error(`Job failed: ${job.id}, error: ${error.message}`);
    });
  }

  /**
   * Get queue status
   */
  async getQueueStatus() {
    const waiting = await this.videoQueue.getWaitingCount();
    const active = await this.videoQueue.getActiveCount();
    const completed = await this.videoQueue.getCompletedCount();
    const failed = await this.videoQueue.getFailedCount();

    return { waiting, active, completed, failed };
  }
}
