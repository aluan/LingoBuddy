import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Profile, ProfileDocument } from './profile.schema';

export interface UpdateProfileInput {
  nickname?: string;
  age?: number;
  interests?: string[];
}

@Injectable()
export class ProfilesService {
  constructor(
    @InjectModel(Profile.name) private readonly profileModel: Model<ProfileDocument>,
  ) {}

  async getCurrentProfile(): Promise<ProfileDocument> {
    const existing = await this.profileModel.findOne({ isDefault: true }).exec();
    if (existing) {
      return existing;
    }

    return this.profileModel.create({
      nickname: 'Little Rider',
      age: 6,
      interests: ['dragons', 'flying', 'forest'],
      isDefault: true,
    });
  }

  async updateCurrentProfile(input: UpdateProfileInput): Promise<ProfileDocument> {
    const profile = await this.getCurrentProfile();

    if (input.nickname !== undefined) profile.nickname = input.nickname;
    if (input.age !== undefined) profile.age = input.age;
    if (input.interests !== undefined) profile.interests = input.interests;

    return profile.save();
  }
}
