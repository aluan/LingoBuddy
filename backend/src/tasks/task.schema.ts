import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type TaskDocument = HydratedDocument<Task>;

@Schema({ timestamps: true })
export class Task {
  @Prop({ required: true })
  title: string;

  @Prop({ required: true })
  scene: string;

  @Prop({ required: true })
  promptHint: string;

  @Prop({ default: 3 })
  rewardStars: number;

  @Prop({ default: true })
  active: boolean;
}

export const TaskSchema = SchemaFactory.createForClass(Task);
TaskSchema.index({ active: 1 });
