import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type MessageDocument = HydratedDocument<Message> & {
  createdAt: Date;
  updatedAt: Date;
};

@Schema({ timestamps: true })
export class Message {
  @Prop({ type: Types.ObjectId, required: true, index: true })
  conversationId: Types.ObjectId;

  @Prop({ required: true })
  role: 'child' | 'astra';

  @Prop({ required: true })
  text: string;

  @Prop({ type: [String], default: [] })
  newWords: string[];
}

export const MessageSchema = SchemaFactory.createForClass(Message);
MessageSchema.index({ conversationId: 1, createdAt: 1 });
