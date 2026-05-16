import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { Conversation, ConversationSchema } from '../conversations/conversation.schema';
import { Message, MessageSchema } from '../conversations/message.schema';
import { Quiz, QuizSchema } from '../video-learning/quiz.schema';
import { VideoContent, VideoContentSchema } from '../video-learning/video-content.schema';
import { KnowledgeController } from './knowledge.controller';
import { KnowledgeLink, KnowledgeLinkSchema } from './knowledge-link.schema';
import { KnowledgeNode, KnowledgeNodeSchema } from './knowledge-node.schema';
import { KnowledgeService } from './knowledge.service';

@Module({
  imports: [
    ConfigModule,
    MongooseModule.forFeature([
      { name: KnowledgeNode.name, schema: KnowledgeNodeSchema },
      { name: KnowledgeLink.name, schema: KnowledgeLinkSchema },
      { name: VideoContent.name, schema: VideoContentSchema },
      { name: Quiz.name, schema: QuizSchema },
      { name: Conversation.name, schema: ConversationSchema },
      { name: Message.name, schema: MessageSchema },
    ]),
  ],
  controllers: [KnowledgeController],
  providers: [KnowledgeService],
  exports: [KnowledgeService],
})
export class KnowledgeModule {}
