import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type ProfileDocument = HydratedDocument<Profile>;

@Schema({ timestamps: true })
export class Profile {
  @Prop({ required: true, default: 'Little Rider' })
  nickname: string;

  @Prop({ required: true, default: 6 })
  age: number;

  @Prop({ type: [String], default: ['dragons', 'flying', 'forest'] })
  interests: string[];

  @Prop({ default: true })
  isDefault: boolean;
}

export const ProfileSchema = SchemaFactory.createForClass(Profile);
ProfileSchema.index({ isDefault: 1 });
