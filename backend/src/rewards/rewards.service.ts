import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { ProfilesService } from '../profiles/profiles.service';
import { Reward, RewardDocument } from './reward.schema';

@Injectable()
export class RewardsService {
  constructor(
    @InjectModel(Reward.name) private readonly rewardModel: Model<RewardDocument>,
    private readonly profiles: ProfilesService,
  ) {}

  async listRewards() {
    const profile = await this.profiles.getCurrentProfile();
    await this.seedStarterRewards(profile.id);
    const rewards = await this.rewardModel.find({ profileId: profile._id }).sort({ createdAt: 1 }).exec();

    return rewards.map((reward) => ({
      id: reward.id,
      type: reward.type,
      title: reward.title,
      amount: reward.amount,
      unlocked: reward.unlocked,
    }));
  }

  async grantStars(profileId: string, amount: number, title = 'Voice adventure stars') {
    return this.rewardModel.create({
      profileId: new Types.ObjectId(profileId),
      type: 'stars',
      title,
      amount,
      unlocked: true,
    });
  }

  private async seedStarterRewards(profileId: string) {
    const objectId = new Types.ObjectId(profileId);
    const count = await this.rewardModel.countDocuments({ profileId: objectId }).exec();
    if (count > 0) return;

    await this.rewardModel.insertMany([
      { profileId: objectId, type: 'hat', title: 'Rider Helmet', amount: 0, unlocked: true },
      { profileId: objectId, type: 'map', title: 'Training Camp', amount: 0, unlocked: true },
    ]);
  }
}
