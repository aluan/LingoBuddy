import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type ConversationDocument = HydratedDocument<Conversation>;

@Schema({ timestamps: true })
export class Conversation {
  @Prop({ type: Types.ObjectId, required: true, index: true })
  profileId: Types.ObjectId;

  @Prop({ type: Types.ObjectId })
  taskId?: Types.ObjectId;

  @Prop({ required: true, default: 'active' })
  status: 'active' | 'ended' | 'error';

  @Prop({ required: true })
  startedAt: Date;

  @Prop()
  endedAt?: Date;
}

export const ConversationSchema = SchemaFactory.createForClass(Conversation);
ConversationSchema.index({ profileId: 1, startedAt: -1 });
