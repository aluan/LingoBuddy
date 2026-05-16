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
import { ContentIngestService } from './content-ingest.service';
import { Conversation, ConversationSchema } from '../conversations/conversation.schema';
import { Message, MessageSchema } from '../conversations/message.schema';
import { ConversationsService } from '../conversations/conversations.service';
import { KnowledgeService } from '../knowledge/knowledge.service';
import { KnowledgeNode, KnowledgeNodeSchema } from '../knowledge/knowledge-node.schema';
import { KnowledgeLink, KnowledgeLinkSchema } from '../knowledge/knowledge-link.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: VideoContent.name, schema: VideoContentSchema },
      { name: Quiz.name, schema: QuizSchema },
      { name: Conversation.name, schema: ConversationSchema },
      { name: Message.name, schema: MessageSchema },
      { name: KnowledgeNode.name, schema: KnowledgeNodeSchema },
      { name: KnowledgeLink.name, schema: KnowledgeLinkSchema },
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
    ContentIngestService,
    ConversationsService,
    KnowledgeService,
  ],
  exports: [VideoLearningService],
})
export class VideoLearningModule {}
