import { Injectable, Logger } from '@nestjs/common';
import { ProfilesService } from '../profiles/profiles.service';
import { TasksService } from '../tasks/tasks.service';
import { ProgressService } from '../progress/progress.service';
import { ConversationsService } from '../conversations/conversations.service';
import { RewardsService } from '../rewards/rewards.service';

const VIDEO_LEARNING_PROFILE_ID = '000000000000000000000001';

@Injectable()
export class VoiceSessionService {
  private readonly logger = new Logger(VoiceSessionService.name);
  private readonly sessions = new Map<
    string,
    {
      sessionId: string;
      conversationId: string;
      profileId: string;
      taskId?: string;
      videoId?: string;
      startedAt: Date;
    }
  >();

  constructor(
    private readonly profiles: ProfilesService,
    private readonly tasks: TasksService,
    private readonly progress: ProgressService,
    private readonly conversations: ConversationsService,
    private readonly rewards: RewardsService,
  ) {}

  async startSession(taskId?: string, videoId?: string) {
    const sessionId = crypto.randomUUID();
    const profile = await this.profiles.getCurrentProfile();
    const todayTask = taskId ? undefined : await this.tasks.getTodayTask();
    const finalTaskId = taskId ?? todayTask?.id;

    const profileId = videoId ? VIDEO_LEARNING_PROFILE_ID : profile.id;

    const conversation = videoId
      ? await this.conversations.getOrStartVideoConversation(profileId, videoId)
      : await this.conversations.start(profileId, finalTaskId);

    this.sessions.set(sessionId, {
      sessionId,
      conversationId: conversation.id,
      profileId,
      taskId: finalTaskId,
      videoId,
      startedAt: new Date(),
    });

    this.logger.log(
      `Session started: ${sessionId}, conversation: ${conversation.id}${videoId ? `, video: ${videoId}` : ''}`,
    );

    return {
      sessionId,
      conversationId: conversation.id,
      taskId: finalTaskId,
    };
  }

  async saveTranscript(
    sessionId: string,
    text: string,
    role: 'child' | 'astra',
  ) {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error(`Session not found: ${sessionId}`);
    }

    const message = await this.conversations.addMessage(
      session.conversationId,
      role,
      text,
    );

    this.logger.log(
      `Transcript saved: ${sessionId}, role: ${role}, text: ${text.substring(0, 50)}...`,
    );

    return { messageId: message.id };
  }

  async grantReward(sessionId: string, stars: number) {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error(`Session not found: ${sessionId}`);
    }

    const progressData = await this.progress.addSpeakingTurn(session.profileId);
    await this.rewards.grantStars(session.profileId, stars);

    this.logger.log(
      `Reward granted: ${sessionId}, stars: ${stars}, total: ${progressData.stars}`,
    );

    return {
      totalStars: progressData.stars,
      progress: {
        speakingTurns: progressData.speakingTurns,
        stars: progressData.stars,
      },
    };
  }

  async endSession(sessionId: string) {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error(`Session not found: ${sessionId}`);
    }

    if (!session.videoId) {
      await this.conversations.end(session.conversationId);
    }
    this.sessions.delete(sessionId);

    const duration = Date.now() - session.startedAt.getTime();
    this.logger.log(
      `Session ended: ${sessionId}, duration: ${Math.round(duration / 1000)}s`,
    );

    return {
      conversationId: session.conversationId,
      summary: `Session completed in ${Math.round(duration / 1000)} seconds`,
    };
  }
}
