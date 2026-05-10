import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { RedisModule } from './redis/redis.module';
import { Profile, ProfileSchema } from './profiles/profile.schema';
import { ProfilesController } from './profiles/profiles.controller';
import { ProfilesService } from './profiles/profiles.service';
import { DailyProgress, DailyProgressSchema } from './progress/daily-progress.schema';
import { ProgressService } from './progress/progress.service';
import { Task, TaskSchema } from './tasks/task.schema';
import { TasksController } from './tasks/tasks.controller';
import { TasksService } from './tasks/tasks.service';
import { Reward, RewardSchema } from './rewards/reward.schema';
import { RewardsController } from './rewards/rewards.controller';
import { RewardsService } from './rewards/rewards.service';
import { Conversation, ConversationSchema } from './conversations/conversation.schema';
import { Message, MessageSchema } from './conversations/message.schema';
import { ConversationsService } from './conversations/conversations.service';
import { HomeController } from './home/home.controller';
import { ParentController } from './parent/parent.controller';
import { ParentService } from './parent/parent.service';
import { VoiceSessionController } from './voice/voice-session.controller';
import { VoiceSessionService } from './voice/voice-session.service';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    MongooseModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        uri: config.get<string>('MONGODB_URI') ?? 'mongodb://localhost:27017/lingobuddy',
      }),
    }),
    MongooseModule.forFeature([
      { name: Profile.name, schema: ProfileSchema },
      { name: DailyProgress.name, schema: DailyProgressSchema },
      { name: Task.name, schema: TaskSchema },
      { name: Reward.name, schema: RewardSchema },
      { name: Conversation.name, schema: ConversationSchema },
      { name: Message.name, schema: MessageSchema },
    ]),
    RedisModule,
  ],
  controllers: [
    ProfilesController,
    TasksController,
    RewardsController,
    HomeController,
    ParentController,
    VoiceSessionController,
  ],
  providers: [
    ProfilesService,
    ProgressService,
    TasksService,
    RewardsService,
    ConversationsService,
    ParentService,
    VoiceSessionService,
  ],
})
export class AppModule {}
