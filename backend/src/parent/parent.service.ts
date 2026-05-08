import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { todayKey } from '../common/date';
import { Message, MessageDocument } from '../conversations/message.schema';
import { ProfilesService } from '../profiles/profiles.service';
import { DailyProgress, DailyProgressDocument } from '../progress/daily-progress.schema';

@Injectable()
export class ParentService {
  constructor(
    private readonly profiles: ProfilesService,
    @InjectModel(DailyProgress.name) private readonly progressModel: Model<DailyProgressDocument>,
    @InjectModel(Message.name) private readonly messageModel: Model<MessageDocument>,
  ) {}

  async summary(date = todayKey()) {
    const profile = await this.profiles.getCurrentProfile();
    const profileId = new Types.ObjectId(profile.id);
    const progress = await this.progressModel.findOne({ profileId, date }).exec();
    const messages = await this.messageModel.find({ role: 'child' }).sort({ createdAt: -1 }).limit(80).exec();
    const newWords = [...new Set(messages.flatMap((message) => message.newWords))].slice(0, 8);

    return {
      date,
      profile: {
        id: profile.id,
        nickname: profile.nickname,
      },
      speakingSeconds: progress?.speakingSeconds ?? 0,
      speakingTurns: progress?.speakingTurns ?? 0,
      streakDays: progress?.streakDays ?? 1,
      stars: progress?.stars ?? 0,
      taskCompleted: progress?.taskCompleted ?? false,
      newWords,
    };
  }
}
