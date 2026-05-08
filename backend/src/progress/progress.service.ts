import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { todayKey } from '../common/date';
import { DailyProgress, DailyProgressDocument } from './daily-progress.schema';

@Injectable()
export class ProgressService {
  constructor(
    @InjectModel(DailyProgress.name) private readonly progressModel: Model<DailyProgressDocument>,
  ) {}

  async getToday(profileId: string): Promise<DailyProgressDocument> {
    return this.getByDate(profileId, todayKey());
  }

  async getByDate(profileId: string, date: string): Promise<DailyProgressDocument> {
    const objectId = new Types.ObjectId(profileId);
    const progress = await this.progressModel.findOne({ profileId: objectId, date }).exec();
    if (progress) return progress;

    return this.progressModel.create({
      profileId: objectId,
      date,
      stars: 0,
      speakingTurns: 0,
      speakingSeconds: 0,
      streakDays: 1,
      taskCompleted: false,
    });
  }

  async addSpeakingTurn(profileId: string, seconds = 8): Promise<DailyProgressDocument> {
    return this.addProgress(profileId, {
      stars: 1,
      speakingTurns: 1,
      speakingSeconds: seconds,
    });
  }

  async completeTask(profileId: string, rewardStars: number): Promise<DailyProgressDocument> {
    return this.addProgress(profileId, {
      stars: rewardStars,
      taskCompleted: true,
    });
  }

  private async addProgress(
    profileId: string,
    update: { stars?: number; speakingTurns?: number; speakingSeconds?: number; taskCompleted?: boolean },
  ): Promise<DailyProgressDocument> {
    const objectId = new Types.ObjectId(profileId);
    const date = todayKey();

    const $inc: Record<string, number> = {};
    if (update.stars) $inc.stars = update.stars;
    if (update.speakingTurns) $inc.speakingTurns = update.speakingTurns;
    if (update.speakingSeconds) $inc.speakingSeconds = update.speakingSeconds;

    return this.progressModel
      .findOneAndUpdate(
        { profileId: objectId, date },
        {
          $setOnInsert: { profileId: objectId, date, streakDays: 1 },
          $set: update.taskCompleted === undefined ? {} : { taskCompleted: update.taskCompleted },
          ...(Object.keys($inc).length > 0 ? { $inc } : {}),
        },
        { upsert: true, new: true },
      )
      .exec();
  }
}
