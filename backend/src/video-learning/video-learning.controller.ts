import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  Logger,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import axios from 'axios';
import { FileInterceptor } from '@nestjs/platform-express';
import { VideoLearningService } from './video-learning.service';
import { VideoProcessorService } from './video-processor.service';
import { QuizService } from './quiz.service';
import { VideoChatService } from './video-chat.service';
import { ConversationsService } from '../conversations/conversations.service';
import { MessageDocument } from '../conversations/message.schema';
import { KnowledgeService } from '../knowledge/knowledge.service';
import { ContentIngestService, UploadedLearningFile } from './content-ingest.service';

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
    private readonly knowledgeService: KnowledgeService,
    private readonly contentIngestService: ContentIngestService,
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


  @Post('submit-webpage')
  async submitWebpage(@Body() body: { url: string }) {
    const urlMatch = body.url?.match(/https?:\/\/\S+/);
    if (!urlMatch) {
      throw new Error('No URL found in input');
    }

    const url = urlMatch[0].replace(/[，。；、）)】]*$/, '');
    const page = await this.contentIngestService.fetchWebpage(url);
    const video = await this.videoLearningService.createContent(CURRENT_PROFILE_ID, {
      url: page.resolvedUrl,
      videoId: this.contentIngestService.sourceIdForUrl('web', page.resolvedUrl),
      platform: 'webpage',
      contentType: 'webpage',
      title: page.title,
      duration: 0,
      transcriptStatus: 'completed',
      transcriptSource: 'subtitle',
      transcriptText: page.text,
      transcriptSegments: [{ startTime: 0, endTime: 0, text: page.text }],
    });

    return { videoId: video.id, status: 'completed' };
  }

  @Post('submit-text')
  async submitText(@Body() body: { text: string; title?: string }) {
    const text = body.text?.trim();
    if (!text) {
      throw new Error('No text found in input');
    }

    const material = this.contentIngestService.textToLearningText(text, body.title);
    const video = await this.videoLearningService.createContent(CURRENT_PROFILE_ID, {
      url: `text://${material.sourceId}`,
      videoId: material.sourceId,
      platform: 'text',
      contentType: 'text',
      title: material.title,
      duration: 0,
      transcriptStatus: 'completed',
      transcriptSource: 'subtitle',
      transcriptText: material.text,
      transcriptSegments: [{ startTime: 0, endTime: 0, text: material.text }],
    });

    return { videoId: video.id, status: 'completed' };
  }

  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  async uploadLearningFile(
    @UploadedFile() file: UploadedLearningFile,
    @Body() body: { contentType?: 'image' | 'pdf' },
  ) {
    if (!file) {
      throw new Error('No file uploaded');
    }

    const inferredType = file.mimetype === 'application/pdf' ? 'pdf' : 'image';
    const contentType = body.contentType || inferredType;
    if (contentType !== 'image' && contentType !== 'pdf') {
      throw new Error('Unsupported upload content type');
    }

    const material = this.contentIngestService.fileToLearningText(file, contentType);
    const video = await this.videoLearningService.createContent(CURRENT_PROFILE_ID, {
      url: `upload://${material.sourceId}`,
      videoId: material.sourceId,
      platform: contentType,
      contentType,
      title: material.title,
      duration: 0,
      transcriptStatus: 'completed',
      transcriptSource: 'subtitle',
      transcriptText: material.text,
      transcriptSegments: [{ startTime: 0, endTime: 0, text: material.text }],
      fileName: file.originalname,
      mimeType: file.mimetype,
      fileSize: file.size,
    });

    return { videoId: video.id, status: 'completed' };
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

  @Post(':videoId/build-knowledge')
  async buildKnowledge(@Param('videoId') videoId: string) {
    return this.knowledgeService.buildForVideo(CURRENT_PROFILE_ID, videoId);
  }

  @Get(':videoId/knowledge-note')
  async getKnowledgeNote(@Param('videoId') videoId: string) {
    return this.knowledgeService.videoKnowledge(CURRENT_PROFILE_ID, videoId);
  }

  @Get(':videoId')
  async getVideo(@Param('videoId') videoId: string) {
    return this.videoLearningService.findById(videoId);
  }

  @Delete(':videoId')
  async deleteVideo(@Param('videoId') videoId: string) {
    const knowledgeCleanup = await this.knowledgeService.deleteForVideo(
      CURRENT_PROFILE_ID,
      videoId,
    );
    await this.videoLearningService.delete(videoId);
    return { success: true, knowledgeCleanup };
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
