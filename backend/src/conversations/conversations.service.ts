import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Conversation, ConversationDocument } from './conversation.schema';
import { Message, MessageDocument } from './message.schema';

const SIMPLE_WORDS = new Set([
  'apple',
  'blue',
  'dragon',
  'fly',
  'forest',
  'green',
  'red',
  'star',
  'sky',
]);

@Injectable()
export class ConversationsService {
  constructor(
    @InjectModel(Conversation.name) private readonly conversationModel: Model<ConversationDocument>,
    @InjectModel(Message.name) private readonly messageModel: Model<MessageDocument>,
  ) {}

  async start(profileId: string, taskId?: string): Promise<ConversationDocument> {
    return this.conversationModel.create({
      profileId: new Types.ObjectId(profileId),
      taskId: taskId ? new Types.ObjectId(taskId) : undefined,
      status: 'active',
      startedAt: new Date(),
    });
  }

  async end(conversationId: string, status: 'ended' | 'error' = 'ended') {
    return this.conversationModel.findByIdAndUpdate(
      conversationId,
      { status, endedAt: new Date() },
      { new: true },
    );
  }

  async addMessage(conversationId: string, role: 'child' | 'astra', text: string) {
    return this.messageModel.create({
      conversationId: new Types.ObjectId(conversationId),
      role,
      text,
      newWords: extractSimpleWords(text),
    });
  }

  async newWordsForConversation(conversationId: string): Promise<string[]> {
    const messages = await this.messageModel.find({ conversationId: new Types.ObjectId(conversationId) }).exec();
    return [...new Set(messages.flatMap((message) => message.newWords))];
  }

  async messagesForConversation(conversationId: string) {
    return this.messageModel.find({ conversationId: new Types.ObjectId(conversationId) }).sort({ createdAt: 1 }).exec();
  }
}

export function extractSimpleWords(text: string): string[] {
  const words = text
    .toLowerCase()
    .replace(/[^a-z\s]/g, ' ')
    .split(/\s+/)
    .filter(Boolean);

  return [...new Set(words.filter((word) => SIMPLE_WORDS.has(word)))];
}
