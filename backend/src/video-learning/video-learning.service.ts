import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { VideoContent, VideoContentDocument } from './video-content.schema';
import { Quiz, QuizDocument } from './quiz.schema';

@Injectable()
export class VideoLearningService {
  private readonly logger = new Logger(VideoLearningService.name);

  constructor(
    @InjectModel(VideoContent.name)
    private videoContentModel: Model<VideoContentDocument>,
    @InjectModel(Quiz.name)
    private quizModel: Model<QuizDocument>,
  ) {}

  async create(profileId: string, url: string, videoId: string) {
    return this.createContent(profileId, {
      url,
      videoId,
      platform: 'bilibili',
      contentType: 'video',
      title: 'Processing...',
      duration: 0,
      transcriptStatus: 'pending',
    });
  }

  async createContent(
    profileId: string,
    data: {
      url: string;
      videoId: string;
      platform: string;
      contentType: 'video' | 'webpage' | 'text' | 'image' | 'pdf';
      title: string;
      duration?: number;
      transcriptStatus: 'pending' | 'processing' | 'completed' | 'failed';
      transcriptSource?: 'subtitle' | 'asr';
      transcriptText?: string;
      transcriptSegments?: any[];
      transcriptError?: string;
      thumbnailUrl?: string;
      fileName?: string;
      mimeType?: string;
      fileSize?: number;
    },
  ) {
    const video = await this.videoContentModel.create({
      profileId: new Types.ObjectId(profileId),
      duration: 0,
      ...data,
    });

    this.logger.log(`Created learning content: ${video.id}, type: ${data.contentType}`);
    return video;
  }

  async findById(videoId: string) {
    const video = await this.videoContentModel.findById(videoId);
    if (!video) {
      throw new NotFoundException(`Video not found: ${videoId}`);
    }
    return video;
  }

  async findByProfileId(profileId: string) {
    return this.videoContentModel
      .find({ profileId: new Types.ObjectId(profileId) })
      .sort({ createdAt: -1 })
      .exec();
  }

  async updateTranscript(
    videoId: string,
    data: {
      transcriptStatus: string;
      transcriptSource?: string;
      transcriptText?: string;
      transcriptSegments?: any[];
      transcriptError?: string;
      title?: string;
      duration?: number;
      thumbnailUrl?: string;
    },
  ) {
    const video = await this.videoContentModel.findByIdAndUpdate(
      videoId,
      { $set: data },
      { new: true },
    );

    if (!video) {
      throw new NotFoundException(`Video not found: ${videoId}`);
    }

    this.logger.log(`Updated video transcript: ${videoId}, status: ${data.transcriptStatus}`);
    return video;
  }

  async delete(videoId: string) {
    const video = await this.videoContentModel.findByIdAndDelete(videoId);
    if (!video) {
      throw new NotFoundException(`Video not found: ${videoId}`);
    }

    // Delete associated quizzes
    await this.quizModel.deleteMany({ videoId: new Types.ObjectId(videoId) });

    this.logger.log(`Deleted video content: ${videoId}`);
    return video;
  }

  async incrementConversationCount(videoId: string) {
    return this.videoContentModel.findByIdAndUpdate(
      videoId,
      {
        $inc: { conversationCount: 1 },
        $set: { lastAccessedAt: new Date() },
      },
      { new: true },
    );
  }

  async incrementQuizCount(videoId: string) {
    return this.videoContentModel.findByIdAndUpdate(
      videoId,
      {
        $inc: { quizCount: 1 },
        $set: { lastAccessedAt: new Date() },
      },
      { new: true },
    );
  }

  // Quiz methods
  async createQuiz(
    videoId: string,
    profileId: string,
    difficulty: string,
    questions: any[],
  ) {
    const quiz = await this.quizModel.create({
      videoId: new Types.ObjectId(videoId),
      profileId: new Types.ObjectId(profileId),
      difficulty,
      questions,
      submitted: false,
    });

    await this.incrementQuizCount(videoId);

    this.logger.log(`Created quiz: ${quiz.id} for video: ${videoId}`);
    return quiz;
  }

  async findQuizById(quizId: string) {
    const quiz = await this.quizModel.findById(quizId);
    if (!quiz) {
      throw new NotFoundException(`Quiz not found: ${quizId}`);
    }
    return quiz;
  }

  async findQuizzesByVideoId(videoId: string) {
    return this.quizModel
      .find({ videoId: new Types.ObjectId(videoId) })
      .sort({ createdAt: -1 })
      .exec();
  }

  async submitQuiz(
    quizId: string,
    answers: { questionId: string; answer: string }[],
    score: number,
    correctCount: number,
    starsEarned: number,
  ) {
    const quiz = await this.quizModel.findByIdAndUpdate(
      quizId,
      {
        $set: {
          submitted: true,
          submittedAt: new Date(),
          answers,
          score,
          correctCount,
          starsEarned,
        },
      },
      { new: true },
    );

    if (!quiz) {
      throw new NotFoundException(`Quiz not found: ${quizId}`);
    }

    this.logger.log(`Submitted quiz: ${quizId}, score: ${score}`);
    return quiz;
  }
}
