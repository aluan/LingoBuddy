import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  Logger,
  Res,
} from '@nestjs/common';
import axios from 'axios';
import { VideoLearningService } from './video-learning.service';
import { VideoProcessorService } from './video-processor.service';
import { QuizService } from './quiz.service';
import { VideoChatService } from './video-chat.service';
import { ConversationsService } from '../conversations/conversations.service';
import { MessageDocument } from '../conversations/message.schema';

type StreamResponse = NodeJS.WritableStream & {
  setHeader: (name: string, value: string) => void;
  status: (code: number) => void;
  headersSent: boolean;
  flushHeaders?: () => void;
};

const CURRENT_PROFILE_ID = '000000000000000000000001';

type LlmHistoryMessage = {
  role: 'assistant' | 'user';
  content: string;
};

@Controller('video-learning')
export class VideoLearningController {
  private readonly logger = new Logger(VideoLearningController.name);

  constructor(
    private readonly videoLearningService: VideoLearningService,
    private readonly videoProcessorService: VideoProcessorService,
    private readonly quizService: QuizService,
    private readonly videoChatService: VideoChatService,
    private readonly conversationsService: ConversationsService,
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
    const profileId = CURRENT_PROFILE_ID;

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
    const profileId = CURRENT_PROFILE_ID;

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

  @Get(':videoId/chat/messages')
  async getChatMessages(@Param('videoId') videoId: string) {
    const { conversation, messages } =
      await this.conversationsService.messagesForVideoConversation(
        CURRENT_PROFILE_ID,
        videoId,
      );

    return {
      conversationId: conversation.id,
      messages: messages.map((message) => ({
        id: message.id,
        role: message.role === 'child' ? 'user' : 'assistant',
        text: message.text,
        createdAt: message.createdAt,
      })),
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

    const conversation = await this.conversationsService.getOrStartVideoConversation(
      CURRENT_PROFILE_ID,
      videoId,
      video.transcriptText,
    );
    const history = await this.chatHistory(CURRENT_PROFILE_ID, videoId);

    await this.conversationsService.addMessage(
      conversation.id,
      'child',
      body.message,
    );

    const reply = await this.videoChatService.chat(
      video.transcriptText || '',
      body.message,
      history,
    );

    await this.conversationsService.addMessage(conversation.id, 'astra', reply);

    return { reply, conversationId: conversation.id };
  }

  @Post(':videoId/chat/stream')
  async chatStream(
    @Param('videoId') videoId: string,
    @Body() body: { message: string },
    @Res() res: StreamResponse,
  ) {
    const video = await this.videoLearningService.findById(videoId);

    if (video.transcriptStatus !== 'completed') {
      throw new Error('Video transcript not ready');
    }

    const conversation = await this.conversationsService.getOrStartVideoConversation(
      CURRENT_PROFILE_ID,
      videoId,
      video.transcriptText,
    );
    const history = await this.chatHistory(CURRENT_PROFILE_ID, videoId);

    await this.conversationsService.addMessage(
      conversation.id,
      'child',
      body.message,
    );

    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders?.();

    let fullReply = '';

    try {
      for await (const delta of this.videoChatService.chatStream(
        video.transcriptText || '',
        body.message,
        history,
      )) {
        fullReply += delta;
        res.write(`data: ${JSON.stringify({ delta })}\n\n`);
      }

      const savedMessage = fullReply.trim()
        ? await this.conversationsService.addMessage(
            conversation.id,
            'astra',
            fullReply,
          )
        : undefined;

      res.write(`data: ${JSON.stringify({ done: true, conversationId: conversation.id, messageId: savedMessage?.id })}\n\n`);
      res.write('data: [DONE]\n\n');
      res.end();
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`Streaming chat failed: ${message}`);
      if (!res.headersSent) {
        res.status(500);
      }
      res.write(`data: ${JSON.stringify({ error: message })}\n\n`);
      res.end();
    }
  }


  private async chatHistory(
    profileId: string,
    videoId: string,
  ): Promise<LlmHistoryMessage[]> {
    const messages = await this.conversationsService.recentMessagesForVideoConversation(
      profileId,
      videoId,
      12,
    );

    return messages.map((message: MessageDocument) => ({
      role: message.role === 'child' ? 'user' : 'assistant',
      content: message.text,
    }));
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
    const profileId = CURRENT_PROFILE_ID;

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
