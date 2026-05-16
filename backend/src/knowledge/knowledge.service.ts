import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectModel } from '@nestjs/mongoose';
import axios from 'axios';
import { Model, Types } from 'mongoose';
import { Conversation, ConversationDocument } from '../conversations/conversation.schema';
import { Message, MessageDocument } from '../conversations/message.schema';
import { Quiz, QuizDocument } from '../video-learning/quiz.schema';
import { VideoContent, VideoContentDocument } from '../video-learning/video-content.schema';
import { KnowledgeLink, KnowledgeLinkDocument, KnowledgeRelation } from './knowledge-link.schema';
import { KnowledgeNode, KnowledgeNodeDocument, KnowledgeNodeType } from './knowledge-node.schema';

type KnowledgeItem = {
  title: string;
  body?: string;
  tags?: string[];
  metadata?: Record<string, unknown>;
};

type ExtractedKnowledge = {
  summary: string;
  vocabulary: KnowledgeItem[];
  sentences: KnowledgeItem[];
  reviewPrompts: string[];
};

@Injectable()
export class KnowledgeService {
  private readonly logger = new Logger(KnowledgeService.name);
  private readonly apiUrl = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
  private readonly model = 'doubao-seed-2-0-pro-260215';

  constructor(
    private readonly configService: ConfigService,
    @InjectModel(KnowledgeNode.name)
    private readonly nodeModel: Model<KnowledgeNodeDocument>,
    @InjectModel(KnowledgeLink.name)
    private readonly linkModel: Model<KnowledgeLinkDocument>,
    @InjectModel(VideoContent.name)
    private readonly videoModel: Model<VideoContentDocument>,
    @InjectModel(Quiz.name)
    private readonly quizModel: Model<QuizDocument>,
    @InjectModel(Conversation.name)
    private readonly conversationModel: Model<ConversationDocument>,
    @InjectModel(Message.name)
    private readonly messageModel: Model<MessageDocument>,
  ) {}

  async home(profileId: string) {
    const pid = new Types.ObjectId(profileId);
    const [recentNodes, videoNotes, vocabulary, mistakes] = await Promise.all([
      this.nodeModel.find({ profileId: pid }).sort({ updatedAt: -1 }).limit(12).exec(),
      this.nodeModel.find({ profileId: pid, type: 'video_note' }).sort({ updatedAt: -1 }).limit(6).exec(),
      this.nodeModel.find({ profileId: pid, type: 'vocabulary' }).sort({ updatedAt: -1 }).limit(12).exec(),
      this.nodeModel.find({ profileId: pid, type: 'quiz_mistake' }).sort({ updatedAt: -1 }).limit(8).exec(),
    ]);

    return {
      recentNodes: recentNodes.map((node) => this.toNodeDto(node)),
      videoNotes: videoNotes.map((node) => this.toNodeDto(node)),
      vocabulary: vocabulary.map((node) => this.toNodeDto(node)),
      mistakes: mistakes.map((node) => this.toNodeDto(node)),
    };
  }

  async search(profileId: string, query = '') {
    const pid = new Types.ObjectId(profileId);
    const trimmed = query.trim();
    const filter = trimmed
      ? {
          profileId: pid,
          $or: [
            { title: { $regex: this.escapeRegex(trimmed), $options: 'i' } },
            { body: { $regex: this.escapeRegex(trimmed), $options: 'i' } },
            { tags: { $regex: this.escapeRegex(trimmed), $options: 'i' } },
          ],
        }
      : { profileId: pid };

    const nodes = await this.nodeModel.find(filter).sort({ updatedAt: -1 }).limit(50).exec();
    return { nodes: nodes.map((node) => this.toNodeDto(node)) };
  }

  async nodeDetail(profileId: string, nodeId: string) {
    const node = await this.nodeModel.findOne({
      _id: new Types.ObjectId(nodeId),
      profileId: new Types.ObjectId(profileId),
    });

    if (!node) {
      throw new NotFoundException(`Knowledge node not found: ${nodeId}`);
    }

    const links = await this.linksForNode(profileId, nodeId);
    return { node: this.toNodeDto(node), links: links.links };
  }

  async linksForNode(profileId: string, nodeId: string) {
    const pid = new Types.ObjectId(profileId);
    const nid = new Types.ObjectId(nodeId);
    const links = await this.linkModel
      .find({ profileId: pid, $or: [{ fromNodeId: nid }, { toNodeId: nid }] })
      .exec();

    const relatedIds = links.map((link) =>
      link.fromNodeId.equals(nid) ? link.toNodeId : link.fromNodeId,
    );
    const related = relatedIds.length
      ? await this.nodeModel.find({ _id: { $in: relatedIds }, profileId: pid }).exec()
      : [];
    const nodeById = new Map(related.map((node) => [node.id, this.toNodeDto(node)]));

    return {
      links: links
        .map((link) => {
          const isOutgoing = link.fromNodeId.equals(nid);
          const relatedId = (isOutgoing ? link.toNodeId : link.fromNodeId).toString();
          const node = nodeById.get(relatedId);
          return node
            ? {
                id: link.id,
                relation: link.relation,
                direction: isOutgoing ? 'outgoing' : 'incoming',
                node,
              }
            : undefined;
        })
        .filter(Boolean),
    };
  }

  async buildForVideo(profileId: string, videoId: string) {
    const pid = new Types.ObjectId(profileId);
    const vid = new Types.ObjectId(videoId);
    const video = await this.videoModel.findOne({ _id: vid, profileId: pid });
    if (!video) {
      throw new NotFoundException(`Video not found: ${videoId}`);
    }
    if (video.transcriptStatus !== 'completed') {
      throw new Error('Video transcript not ready');
    }

    const extracted = await this.extractKnowledge(video.transcriptText || '', video.title);
    const videoNode = await this.upsertNode(profileId, {
      type: 'video_note',
      key: `video:${video.id}`,
      title: video.title,
      body: extracted.summary,
      tags: ['LingoBuddy', 'VideoLearning', 'English'],
      sourceVideoId: vid,
      metadata: {
        url: video.url,
        videoId: video.videoId,
        duration: video.duration,
        transcriptSource: video.transcriptSource,
        reviewPrompts: extracted.reviewPrompts,
      },
    });

    const vocabularyNodes = await Promise.all(
      extracted.vocabulary.map((item) =>
        this.upsertNode(profileId, {
          type: 'vocabulary',
          key: `vocab:${this.slug(item.title)}`,
          title: item.title,
          body: item.body || '',
          tags: ['Vocabulary', ...(item.tags || [])],
          sourceVideoId: vid,
          metadata: item.metadata || {},
        }),
      ),
    );

    const sentenceNodes = await Promise.all(
      extracted.sentences.map((item) =>
        this.upsertNode(profileId, {
          type: 'sentence',
          key: `sentence:${this.slug(item.title)}`,
          title: item.title,
          body: item.body || '',
          tags: ['Sentence', ...(item.tags || [])],
          sourceVideoId: vid,
          metadata: item.metadata || {},
        }),
      ),
    );

    for (const node of [...vocabularyNodes, ...sentenceNodes]) {
      await this.upsertLink(profileId, node.id, videoNode.id, 'learned_from');
    }

    const [questionNodes, mistakeNodes] = await Promise.all([
      this.buildQuestionNodes(profileId, video.id, videoNode.id),
      this.buildMistakeNodes(profileId, video.id, videoNode.id),
    ]);

    return {
      videoNote: this.toNodeDto(videoNode),
      created: {
        vocabulary: vocabularyNodes.length,
        sentences: sentenceNodes.length,
        questions: questionNodes.length,
        mistakes: mistakeNodes.length,
      },
      nodes: [videoNode, ...vocabularyNodes, ...sentenceNodes, ...questionNodes, ...mistakeNodes].map((node) =>
        this.toNodeDto(node),
      ),
    };
  }

  async videoKnowledge(profileId: string, videoId: string) {
    const pid = new Types.ObjectId(profileId);
    const vid = new Types.ObjectId(videoId);
    const nodes = await this.nodeModel
      .find({ profileId: pid, sourceVideoId: vid })
      .sort({ type: 1, updatedAt: -1 })
      .exec();
    return { nodes: nodes.map((node) => this.toNodeDto(node)) };
  }

  async deleteForVideo(profileId: string, videoId: string) {
    const pid = new Types.ObjectId(profileId);
    const vid = new Types.ObjectId(videoId);
    const nodes = await this.nodeModel
      .find({ profileId: pid, sourceVideoId: vid })
      .select('_id')
      .exec();

    const nodeIds = nodes.map((node) => node._id);
    if (!nodeIds.length) {
      return { deletedNodes: 0, deletedLinks: 0 };
    }

    const [linksResult, nodesResult] = await Promise.all([
      this.linkModel.deleteMany({
        profileId: pid,
        $or: [
          { fromNodeId: { $in: nodeIds } },
          { toNodeId: { $in: nodeIds } },
        ],
      }),
      this.nodeModel.deleteMany({ profileId: pid, _id: { $in: nodeIds } }),
    ]);

    this.logger.log(
      `Deleted knowledge for video ${videoId}: ${nodesResult.deletedCount} nodes, ${linksResult.deletedCount} links`,
    );

    return {
      deletedNodes: nodesResult.deletedCount || 0,
      deletedLinks: linksResult.deletedCount || 0,
    };
  }

  private async buildQuestionNodes(profileId: string, videoId: string, videoNodeId: string) {
    const conversations = await this.conversationModel.find({ videoId }).exec();
    if (!conversations.length) return [];

    const messages = await this.messageModel
      .find({
        conversationId: { $in: conversations.map((conversation) => conversation._id) },
        role: 'child',
      })
      .sort({ createdAt: -1 })
      .limit(12)
      .exec();

    const questionMessages = messages.filter((message) =>
      /[?？]|what|why|how|when|where|who|can you/i.test(message.text),
    );

    const nodes: KnowledgeNodeDocument[] = [];
    for (const message of questionMessages) {
      const node = await this.upsertNode(profileId, {
        type: 'question',
        key: `question:${message.id}`,
        title: message.text.slice(0, 80),
        body: message.text,
        tags: ['Question'],
        sourceVideoId: new Types.ObjectId(videoId),
        metadata: { messageId: message.id },
      });
      await this.upsertLink(profileId, node.id, videoNodeId, 'asked_about');
      nodes.push(node);
    }
    return nodes;
  }

  private async buildMistakeNodes(profileId: string, videoId: string, videoNodeId: string) {
    const quizzes = await this.quizModel
      .find({ videoId: new Types.ObjectId(videoId), submitted: true })
      .sort({ submittedAt: -1 })
      .exec();

    const nodes: KnowledgeNodeDocument[] = [];
    for (const quiz of quizzes) {
      for (const question of quiz.questions) {
        const answer = quiz.answers?.find((item) => item.questionId === question.questionId);
        if (!answer || answer.answer === question.correctAnswer) continue;

        const node = await this.upsertNode(profileId, {
          type: 'quiz_mistake',
          key: `mistake:${quiz.id}:${question.questionId}`,
          title: question.question,
          body: question.explanation || '',
          tags: ['Mistake', quiz.difficulty],
          sourceVideoId: new Types.ObjectId(videoId),
          metadata: {
            quizId: quiz.id,
            questionId: question.questionId,
            userAnswer: answer.answer,
            correctAnswer: question.correctAnswer,
            options: question.options || [],
          },
        });
        await this.upsertLink(profileId, node.id, videoNodeId, 'tested_in');
        nodes.push(node);
      }
    }
    return nodes;
  }

  private async upsertNode(
    profileId: string,
    input: {
      type: KnowledgeNodeType;
      key: string;
      title: string;
      body?: string;
      tags?: string[];
      sourceVideoId?: Types.ObjectId;
      metadata?: Record<string, unknown>;
    },
  ) {
    const pid = new Types.ObjectId(profileId);
    const node = await this.nodeModel.findOneAndUpdate(
      { profileId: pid, type: input.type, key: input.key },
      {
        $set: {
          title: input.title,
          body: input.body || '',
          tags: input.tags || [],
          sourceVideoId: input.sourceVideoId,
          metadata: input.metadata || {},
        },
        $setOnInsert: { profileId: pid, type: input.type, key: input.key },
      },
      { upsert: true, new: true },
    );
    return node;
  }

  private async upsertLink(profileId: string, fromNodeId: string, toNodeId: string, relation: KnowledgeRelation) {
    await this.linkModel.findOneAndUpdate(
      {
        profileId: new Types.ObjectId(profileId),
        fromNodeId: new Types.ObjectId(fromNodeId),
        toNodeId: new Types.ObjectId(toNodeId),
        relation,
      },
      {
        $setOnInsert: {
          profileId: new Types.ObjectId(profileId),
          fromNodeId: new Types.ObjectId(fromNodeId),
          toNodeId: new Types.ObjectId(toNodeId),
          relation,
        },
      },
      { upsert: true, new: true },
    );
  }

  private async extractKnowledge(transcript: string, title: string): Promise<ExtractedKnowledge> {
    const apiKey = this.configService.get<string>('DOUBAO_ARK_API_KEY') || '';
    if (!apiKey) {
      return this.fallbackExtract(transcript, title);
    }

    try {
      const response = await axios.post(
        this.apiUrl,
        {
          model: this.model,
          messages: [
            {
              role: 'system',
              content: 'You extract concise English-learning knowledge for children. Return valid JSON only.',
            },
            {
              role: 'user',
              content: this.buildExtractionPrompt(transcript, title),
            },
          ],
          temperature: 0.4,
          max_tokens: 1800,
          thinking: { type: 'disabled' },
        },
        {
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${apiKey}`,
          },
          timeout: 45000,
        },
      );

      const content = response.data.choices?.[0]?.message?.content || '';
      return this.parseExtractedKnowledge(content);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      this.logger.warn(`LLM knowledge extraction failed, using fallback: ${message}`);
      return this.fallbackExtract(transcript, title);
    }
  }

  private buildExtractionPrompt(transcript: string, title: string) {
    return `Video title: ${title}

Transcript:
${transcript.substring(0, 5000)}

Extract knowledge for a child learning English. Return ONLY JSON:
{
  "summary": "2-4 simple English sentences.",
  "vocabulary": [
    { "title": "word or phrase", "body": "Chinese meaning + one simple English example", "tags": ["topic"] }
  ],
  "sentences": [
    { "title": "useful sentence", "body": "Chinese explanation" }
  ],
  "reviewPrompts": ["simple review question"]
}
Use 8-12 vocabulary items, 3-5 sentences, and 3-5 review prompts.`;
  }

  private parseExtractedKnowledge(content: string): ExtractedKnowledge {
    const jsonMatch = content.match(/```json\s*([\s\S]*?)\s*```/) || content.match(/```\s*([\s\S]*?)\s*```/);
    const parsed = JSON.parse(jsonMatch ? jsonMatch[1] : content);
    return {
      summary: String(parsed.summary || ''),
      vocabulary: Array.isArray(parsed.vocabulary) ? parsed.vocabulary.slice(0, 12) : [],
      sentences: Array.isArray(parsed.sentences) ? parsed.sentences.slice(0, 5) : [],
      reviewPrompts: Array.isArray(parsed.reviewPrompts) ? parsed.reviewPrompts.slice(0, 5).map(String) : [],
    };
  }

  private fallbackExtract(transcript: string, title: string): ExtractedKnowledge {
    const cleaned = transcript.replace(/\s+/g, ' ').trim();
    const sentences = cleaned.match(/[^.!?。！？]+[.!?。！？]/g)?.slice(0, 5) || [];
    const words = Array.from(
      new Set(
        cleaned
          .toLowerCase()
          .match(/[a-z][a-z'-]{3,}/g)
          ?.filter((word) => !this.stopWords.has(word)) || [],
      ),
    ).slice(0, 10);

    return {
      summary: sentences.slice(0, 3).join(' ') || `Learning note for ${title}.`,
      vocabulary: words.map((word) => ({
        title: word,
        body: `Meaning: to review. Example: I can use "${word}" in a sentence.`,
        tags: ['auto'],
      })),
      sentences: sentences.slice(0, 4).map((sentence) => ({
        title: sentence.trim(),
        body: 'Useful sentence from the video.',
      })),
      reviewPrompts: [
        'What is this video about?',
        'Which new words can you remember?',
        'Can you make one sentence with a new word?',
      ],
    };
  }

  private toNodeDto(node: KnowledgeNodeDocument) {
    return {
      id: node.id,
      type: node.type,
      title: node.title,
      body: node.body,
      key: node.key,
      tags: node.tags || [],
      sourceVideoId: node.sourceVideoId?.toString(),
      metadata: node.metadata || {},
      createdAt: node.createdAt,
      updatedAt: node.updatedAt,
    };
  }

  private slug(value: string) {
    return value.toLowerCase().trim().replace(/[^a-z0-9\u4e00-\u9fa5]+/gi, '-').replace(/^-+|-+$/g, '').slice(0, 80) || 'item';
  }

  private escapeRegex(value: string) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  private readonly stopWords = new Set([
    'this', 'that', 'with', 'have', 'from', 'they', 'them', 'there', 'what', 'when', 'where',
    'your', 'about', 'would', 'could', 'should', 'because', 'their', 'which', 'will', 'just',
    'like', 'into', 'then', 'than', 'were', 'been', 'very', 'also', 'make', 'made', 'some',
  ]);
}
