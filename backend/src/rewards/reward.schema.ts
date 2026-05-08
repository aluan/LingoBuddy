import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type RewardDocument = HydratedDocument<Reward>;

@Schema({ timestamps: true })
export class Reward {
  @Prop({ type: Types.ObjectId, required: true, index: true })
  profileId: Types.ObjectId;

  @Prop({ required: true })
  type: 'stars' | 'hat' | 'map';

  @Prop({ required: true })
  title: string;

  @Prop({ default: 0 })
  amount: number;

  @Prop({ default: true })
  unlocked: boolean;
}

export const RewardSchema = SchemaFactory.createForClass(Reward);
RewardSchema.index({ profileId: 1, type: 1, title: 1 });
