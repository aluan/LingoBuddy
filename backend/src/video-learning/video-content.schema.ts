import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type VideoContentDocument = HydratedDocument<VideoContent>;

interface TranscriptSegment {
  startTime: number;
  endTime: number;
  text: string;
}

@Schema({ timestamps: true })
export class VideoContent {
  @Prop({ type: Types.ObjectId, required: true, index: true })
  profileId: Types.ObjectId;

  @Prop({ required: true })
  url: string;

  @Prop({ required: true, default: 'bilibili' })
  platform: string;

  @Prop({ required: true, default: 'video' })
  contentType: 'video' | 'webpage' | 'text' | 'image' | 'pdf';

  @Prop({ required: true })
  videoId: string;

  @Prop({ required: true })
  title: string;

  @Prop({ required: true })
  duration: number;

  @Prop()
  thumbnailUrl?: string;

  @Prop()
  fileName?: string;

  @Prop()
  mimeType?: string;

  @Prop()
  fileSize?: number;

  // Transcript/Subtitle
  @Prop({ required: true, default: 'pending' })
  transcriptStatus: 'pending' | 'processing' | 'completed' | 'failed';

  @Prop()
  transcriptSource?: 'subtitle' | 'asr';

  @Prop({ type: String })
  transcriptText?: string;

  @Prop({ type: Array })
  transcriptSegments?: TranscriptSegment[];

  @Prop()
  transcriptError?: string;

  // Audio file (temporary)
  @Prop()
  audioFilePath?: string;

  @Prop()
  audioFileSize?: number;

  // Learning data
  @Prop({ default: 0 })
  conversationCount: number;

  @Prop({ default: 0 })
  quizCount: number;

  @Prop()
  lastAccessedAt?: Date;
}

export const VideoContentSchema = SchemaFactory.createForClass(VideoContent);
VideoContentSchema.index({ profileId: 1, createdAt: -1 });
VideoContentSchema.index({ videoId: 1 });
