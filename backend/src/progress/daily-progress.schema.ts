import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type DailyProgressDocument = HydratedDocument<DailyProgress>;

@Schema({ collection: 'daily_progress', timestamps: true })
export class DailyProgress {
  @Prop({ type: Types.ObjectId, required: true, index: true })
  profileId: Types.ObjectId;

  @Prop({ required: true, index: true })
  date: string;

  @Prop({ default: 0 })
  stars: number;

  @Prop({ default: 0 })
  speakingTurns: number;

  @Prop({ default: 0 })
  speakingSeconds: number;

  @Prop({ default: 1 })
  streakDays: number;

  @Prop({ default: false })
  taskCompleted: boolean;
}

export const DailyProgressSchema = SchemaFactory.createForClass(DailyProgress);
DailyProgressSchema.index({ profileId: 1, date: 1 }, { unique: true });
