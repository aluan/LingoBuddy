import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';
import { createHash, randomUUID } from 'crypto';

export type UploadedLearningFile = {
  originalname: string;
  mimetype: string;
  size: number;
  buffer: Buffer;
};

@Injectable()
export class ContentIngestService {
  private readonly logger = new Logger(ContentIngestService.name);

  async fetchWebpage(url: string) {
    const response = await axios.get<string>(url, {
      timeout: 15000,
      maxRedirects: 5,
      responseType: 'text',
      headers: {
        'User-Agent': 'LingoBuddy/1.0 learning-content-ingest',
      },
      transformResponse: [(data) => data],
    });

    const html = String(response.data || '');
    const title = this.extractTitle(html) || url;
    const text = this.htmlToText(html);

    return {
      title,
      text: text || `Web page: ${title}\n${url}`,
      resolvedUrl: response.request?.res?.responseUrl ?? url,
    };
  }

  textToLearningText(text: string, title?: string) {
    const cleaned = text.trim();
    const firstLine = cleaned.split(/\r?\n/).map((line) => line.trim()).find(Boolean);
    const inferredTitle = title?.trim() || (firstLine ? firstLine.slice(0, 80) : 'Shared Text');

    return {
      title: inferredTitle || 'Shared Text',
      text: cleaned || 'Shared text learning material',
      sourceId: `text-${createHash('sha1').update(cleaned || randomUUID()).digest('hex').slice(0, 16)}`,
    };
  }

  fileToLearningText(file: UploadedLearningFile, contentType: 'image' | 'pdf') {
    const title = file.originalname || (contentType === 'pdf' ? 'PDF Learning Material' : 'Image Learning Material');
    const fileKind = contentType === 'pdf' ? 'PDF' : 'Image';

    return {
      title,
      text: `${fileKind} learning material: ${title}\n\nThis file was added from the app. Use Chat or Voice to describe, ask questions, and turn it into vocabulary, sentences, and review notes.`,
      sourceId: `${contentType}-${randomUUID()}`,
    };
  }

  sourceIdForUrl(prefix: string, url: string) {
    return `${prefix}-${createHash('sha1').update(url).digest('hex').slice(0, 16)}`;
  }

  private extractTitle(html: string) {
    const match = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
    return match ? this.decodeEntities(match[1]).trim().replace(/\s+/g, ' ') : undefined;
  }

  private htmlToText(html: string) {
    return this.decodeEntities(
      html
        .replace(/<script[\s\S]*?<\/script>/gi, ' ')
        .replace(/<style[\s\S]*?<\/style>/gi, ' ')
        .replace(/<[^>]+>/g, ' ')
        .replace(/\s+/g, ' ')
        .trim(),
    ).slice(0, 12000);
  }

  private decodeEntities(value: string) {
    return value
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'");
  }
}
