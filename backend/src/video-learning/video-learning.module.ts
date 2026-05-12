import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { BullModule } from '@nestjs/bull';
import { VideoLearningController } from './video-learning.controller';
import { VideoLearningService } from './video-learning.service';
import { VideoContent, VideoContentSchema } from './video-content.schema';
import { Quiz, QuizSchema } from './quiz.schema';
import { VideoProcessorService } from './video-processor.service';
import { BilibiliSubtitleService } from './bilibili-subtitle.service';
import { BilibiliDownloaderService } from './bilibili-downloader.service';
import { DoubaoAsrService } from './doubao-asr.service';
import { QuizService } from './quiz.service';
import { VideoChatService } from './video-chat.service';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: VideoContent.name, schema: VideoContentSchema },
      { name: Quiz.name, schema: QuizSchema },
    ]),
    BullModule.registerQueue({
      name: 'video-processing',
    }),
  ],
  controllers: [VideoLearningController],
  providers: [
    VideoLearningService,
    VideoProcessorService,
    BilibiliSubtitleService,
    BilibiliDownloaderService,
    DoubaoAsrService,
    QuizService,
    VideoChatService,
  ],
  exports: [VideoLearningService],
})
export class VideoLearningModule {}
