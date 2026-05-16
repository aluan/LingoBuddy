import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type KnowledgeLinkDocument = HydratedDocument<KnowledgeLink>;

export type KnowledgeRelation =
  | 'learned_from'
  | 'tested_in'
  | 'confused_with'
  | 'asked_about'
  | 'related_to';

@Schema({ timestamps: true })
export class KnowledgeLink {
  @Prop({ type: Types.ObjectId, required: true, index: true })
  profileId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, required: true, index: true })
  fromNodeId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, required: true, index: true })
  toNodeId: Types.ObjectId;

  @Prop({ required: true })
  relation: KnowledgeRelation;
}

export const KnowledgeLinkSchema = SchemaFactory.createForClass(KnowledgeLink);
KnowledgeLinkSchema.index(
  { profileId: 1, fromNodeId: 1, toNodeId: 1, relation: 1 },
  { unique: true },
);
