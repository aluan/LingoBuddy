import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  Logger,
} from '@nestjs/common';
import axios from 'axios';
import { VideoLearningService } from './video-learning.service';
import { VideoProcessorService } from './video-processor.service';
import { QuizService } from './quiz.service';
import { VideoChatService } from './video-chat.service';

@Controller('video-learning')
export class VideoLearningController {
  private readonly logger = new Logger(VideoLearningController.name);

  constructor(
    private readonly videoLearningService: VideoLearningService,
    private readonly videoProcessorService: VideoProcessorService,
    private readonly quizService: QuizService,
    private readonly videoChatService: VideoChatService,
  ) {}

  @Post('submit')
  async submitVideo(@Body() body: { url: string }) {
    this.logger.log(`Submitting video: ${body.url}`);

    // Extract URL from mixed text (e.g. "【Title】 https://b23.tv/xxx")
    const urlMatch = body.url.match(/https?:\/\/\S+/);
    if (!urlMatch) {
      throw new Error('No URL found in input');
    }
    const rawUrl = urlMatch[0].replace(/[��）)】]*$/, ''); // strip trailing CJK brackets

    // Resolve b23.tv short URLs to full Bilibili URL
    let resolvedUrl = rawUrl;
    if (rawUrl.includes('b23.tv')) {
      const res = await axios.get(rawUrl, {
        maxRedirects: 5,
        validateStatus: () => true,
      });
      resolvedUrl = res.request?.res?.responseUrl ?? res.config?.url ?? rawUrl;
      this.logger.log(`Resolved short URL to: ${resolvedUrl}`);
    }

    // Extract BV ID from URL
    const bvMatch = resolvedUrl.match(/BV[\w]+/);
    if (!bvMatch) {
      throw new Error('Invalid Bilibili URL: could not extract BV ID');
    }
    const videoId = bvMatch[0];

    // TODO: Get current profile ID from session/auth
    const profileId = '000000000000000000000001';

    const video = await this.videoLearningService.create(
      profileId,
      resolvedUrl,
      videoId,
    );

    // Enqueue video processing task
    await this.videoProcessorService.enqueueVideo(video.id, resolvedUrl, videoId);

    return {
      videoId: video.id,
      status: 'pending',
    };
  }

  @Get(':videoId/status')
  async getVideoStatus(@Param('videoId') videoId: string) {
    const video = await this.videoLearningService.findById(videoId);

    // Calculate progress based on status
    let progress = 0;
    if (video.transcriptStatus === 'processing') {
      progress = 50;
    } else if (video.transcriptStatus === 'completed') {
      progress = 100;
    }

    return {
      status: video.transcriptStatus,
      progress,
      transcriptText: video.transcriptText,
      transcriptSource: video.transcriptSource,
      error: video.transcriptError,
    };
  }

  @Get('list')
  async listVideos() {
    // TODO: Get current profile ID from session/auth
    const profileId = '000000000000000000000001';

    const videos = await this.videoLearningService.findByProfileId(profileId);

    return { videos };
  }

  @Get(':videoId')
  async getVideo(@Param('videoId') videoId: string) {
    return this.videoLearningService.findById(videoId);
  }

  @Delete(':videoId')
  async deleteVideo(@Param('videoId') videoId: string) {
    await this.videoLearningService.delete(videoId);
    return { success: true };
  }

  @Post(':videoId/start-session')
  async startSession(@Param('videoId') videoId: string) {
    const video = await this.videoLearningService.findById(videoId);

    if (video.transcriptStatus !== 'completed') {
      throw new Error('Video transcript not ready');
    }

    await this.videoLearningService.incrementConversationCount(videoId);

    // TODO: Integrate with VoiceSessionService
    return {
      sessionId: 'temp-session-id',
      conversationId: 'temp-conversation-id',
    };
  }

  @Post(':videoId/chat')
  async chat(
    @Param('videoId') videoId: string,
    @Body() body: { message: string },
  ) {
    const video = await this.videoLearningService.findById(videoId);

    if (video.transcriptStatus !== 'completed') {
      throw new Error('Video transcript not ready');
    }

    const reply = await this.videoChatService.chat(
      video.transcriptText || '',
      body.message,
    );

    return { reply };
  }

  @Post(':videoId/generate-quiz')
  async generateQuiz(
    @Param('videoId') videoId: string,
    @Body() body: { difficulty: string; questionCount: number },
  ) {
    const video = await this.videoLearningService.findById(videoId);

    if (video.transcriptStatus !== 'completed') {
      throw new Error('Video transcript not ready');
    }

    // Generate quiz using LLM
    const questions = await this.quizService.generateQuiz(
      video.transcriptText || '',
      body.difficulty as 'easy' | 'medium' | 'hard',
      body.questionCount,
    );

    // TODO: Get current profile ID
    const profileId = '000000000000000000000001';

    const quiz = await this.videoLearningService.createQuiz(
      videoId,
      profileId,
      body.difficulty,
      questions,
    );

    return quiz;
  }

  @Get(':videoId/quizzes')
  async getQuizzes(@Param('videoId') videoId: string) {
    const quizzes = await this.videoLearningService.findQuizzesByVideoId(
      videoId,
    );
    return { quizzes };
  }

  @Post('quizzes/:quizId/submit')
  async submitQuiz(
    @Param('quizId') quizId: string,
    @Body() body: { answers: { questionId: string; answer: string }[] },
  ) {
    const quiz = await this.videoLearningService.findQuizById(quizId);

    if (quiz.submitted) {
      throw new Error('Quiz already submitted');
    }

    // Calculate score
    let correctCount = 0;
    quiz.questions.forEach((q) => {
      const userAnswer = body.answers.find((a) => a.questionId === q.questionId);
      if (userAnswer && userAnswer.answer === q.correctAnswer) {
        correctCount++;
      }
    });

    const score = Math.round((correctCount / quiz.questions.length) * 100);
    const stars = Math.floor(score / 20); // 20 points = 1 star, max 5 stars

    await this.videoLearningService.submitQuiz(
      quizId,
      body.answers,
      score,
      correctCount,
      stars,
    );

    // TODO: Grant stars to user via RewardsService

    return {
      quizId,
      score,
      correctCount,
      totalCount: quiz.questions.length,
      stars,
      answers: body.answers.map((a) => {
        const q = quiz.questions.find((q) => q.questionId === a.questionId);
        return { questionId: a.questionId, answer: a.answer, isCorrect: a.answer === q?.correctAnswer };
      }),
    };
  }
}
