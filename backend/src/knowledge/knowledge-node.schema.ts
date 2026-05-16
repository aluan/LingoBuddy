import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type KnowledgeNodeDocument = HydratedDocument<KnowledgeNode> & {
  createdAt: Date;
  updatedAt: Date;
};

export type KnowledgeNodeType =
  | 'video_note'
  | 'vocabulary'
  | 'sentence'
  | 'quiz_mistake'
  | 'question';

@Schema({ timestamps: true })
export class KnowledgeNode {
  @Prop({ type: Types.ObjectId, required: true, index: true })
  profileId: Types.ObjectId;

  @Prop({ required: true, index: true })
  type: KnowledgeNodeType;

  @Prop({ required: true })
  title: string;

  @Prop({ type: String, default: '' })
  body: string;

  @Prop({ required: true, index: true })
  key: string;

  @Prop({ type: [String], default: [] })
  tags: string[];

  @Prop({ type: Types.ObjectId, index: true })
  sourceVideoId?: Types.ObjectId;

  @Prop({ type: Object, default: {} })
  metadata: Record<string, unknown>;
}

export const KnowledgeNodeSchema = SchemaFactory.createForClass(KnowledgeNode);
KnowledgeNodeSchema.index({ profileId: 1, type: 1, key: 1 }, { unique: true });
KnowledgeNodeSchema.index({ profileId: 1, updatedAt: -1 });
KnowledgeNodeSchema.index({ title: 'text', body: 'text', tags: 'text' });
