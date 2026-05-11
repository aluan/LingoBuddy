import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type QuizDocument = HydratedDocument<Quiz>;

interface QuizQuestion {
  questionId: string;
  type: 'multiple_choice' | 'fill_blank' | 'true_false';
  question: string;
  options?: string[];
  correctAnswer: string;
  explanation?: string;
}

interface QuizAnswer {
  questionId: string;
  answer: string;
}

@Schema({ timestamps: true })
export class Quiz {
  @Prop({ type: Types.ObjectId, required: true, index: true })
  videoId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, required: true, index: true })
  profileId: Types.ObjectId;

  @Prop({ required: true })
  difficulty: 'easy' | 'medium' | 'hard';

  @Prop({ type: Array, required: true })
  questions: QuizQuestion[];

  // Submission data
  @Prop({ default: false })
  submitted: boolean;

  @Prop()
  submittedAt?: Date;

  @Prop({ type: Array })
  answers?: QuizAnswer[];

  @Prop()
  score?: number;

  @Prop()
  correctCount?: number;

  @Prop()
  starsEarned?: number;
}

export const QuizSchema = SchemaFactory.createForClass(Quiz);
QuizSchema.index({ videoId: 1, createdAt: -1 });
QuizSchema.index({ profileId: 1, submitted: 1 });
