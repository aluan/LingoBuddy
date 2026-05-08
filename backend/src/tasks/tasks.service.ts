import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { ProfileDocument } from '../profiles/profile.schema';
import { ProfilesService } from '../profiles/profiles.service';
import { ProgressService } from '../progress/progress.service';
import { Task, TaskDocument } from './task.schema';

const DEFAULT_TASKS = [
  {
    title: 'Find a baby dragon',
    scene: 'Dragon training camp',
    promptHint: 'Invite the child to find a baby dragon and describe it.',
    rewardStars: 3,
  },
  {
    title: 'Find something red',
    scene: 'Viking village',
    promptHint: 'Ask the child to find something red nearby.',
    rewardStars: 2,
  },
  {
    title: 'Count 3 dragons',
    scene: 'Sky island',
    promptHint: 'Ask the child to count three dragons in simple English.',
    rewardStars: 2,
  },
  {
    title: 'What did you eat today?',
    scene: 'Campfire snack',
    promptHint: 'Ask one short question about food today.',
    rewardStars: 2,
  },
];

@Injectable()
export class TasksService {
  constructor(
    @InjectModel(Task.name) private readonly taskModel: Model<TaskDocument>,
    private readonly profiles: ProfilesService,
    private readonly progress: ProgressService,
  ) {}

  async getTodayTask(): Promise<TaskDocument> {
    await this.seedDefaults();
    const dayIndex = Math.floor(Date.now() / 86_400_000);
    const tasks = await this.taskModel.find({ active: true }).sort({ createdAt: 1 }).exec();
    return tasks[dayIndex % tasks.length];
  }

  async completeTask(taskId: string) {
    const profile = await this.profiles.getCurrentProfile();
    const task = await this.taskModel.findById(taskId).exec();
    const rewardStars = task?.rewardStars ?? 2;
    const progress = await this.progress.completeTask(profile.id, rewardStars);

    return {
      taskId,
      rewardStars,
      progress: this.serializeProgress(progress),
    };
  }

  async homePayload(profile: ProfileDocument) {
    const task = await this.getTodayTask();
    const progress = await this.progress.getToday(profile.id);

    return {
      profile: {
        id: profile.id,
        nickname: profile.nickname,
        age: profile.age,
        interests: profile.interests,
      },
      task: this.serializeTask(task),
      progress: this.serializeProgress(progress),
      dinoState: 'ready',
    };
  }

  serializeTask(task: TaskDocument) {
    return {
      id: task.id,
      title: task.title,
      scene: task.scene,
      promptHint: task.promptHint,
      rewardStars: task.rewardStars,
    };
  }

  private serializeProgress(progress: { stars: number; speakingTurns: number; speakingSeconds: number; streakDays: number; taskCompleted: boolean }) {
    return {
      stars: progress.stars,
      speakingTurns: progress.speakingTurns,
      speakingSeconds: progress.speakingSeconds,
      streakDays: progress.streakDays,
      taskCompleted: progress.taskCompleted,
    };
  }

  private async seedDefaults() {
    const count = await this.taskModel.countDocuments().exec();
    if (count > 0) return;
    await this.taskModel.insertMany(DEFAULT_TASKS);
  }
}
