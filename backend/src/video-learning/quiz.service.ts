import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

interface QuizQuestion {
  questionId: string;
  type: 'multiple_choice' | 'fill_blank' | 'true_false';
  question: string;
  options?: string[];
  correctAnswer: string;
  explanation?: string;
}

@Injectable()
export class QuizService {
  private readonly logger = new Logger(QuizService.name);
  private readonly llmApiUrl: string;
  private readonly appKey: string;
  private readonly token: string;

  constructor(private configService: ConfigService) {
    this.llmApiUrl = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
    this.appKey = '';
    this.token = this.configService.get<string>('DOUBAO_ARK_API_KEY') || '';
  }

  /**
   * Generate quiz questions based on video transcript
   */
  async generateQuiz(
    transcriptText: string,
    difficulty: 'easy' | 'medium' | 'hard',
    questionCount: number,
  ): Promise<QuizQuestion[]> {
    this.logger.log(
      `Generating ${questionCount} ${difficulty} questions from transcript (${transcriptText.length} chars)`,
    );

    try {
      const prompt = this.buildQuizPrompt(transcriptText, difficulty, questionCount);

      // Call Doubao LLM API
      const response = await axios.post(
        this.llmApiUrl,
        {
          model: 'doubao-seed-2-0-pro-260215',
          messages: [
            {
              role: 'system',
              content:
                'You are a quiz generator for children\'s English learning. Generate questions in valid JSON format.',
            },
            {
              role: 'user',
              content: prompt,
            },
          ],
          temperature: 0.7,
          max_tokens: 2000,
        },
        {
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${this.token}`,
          },
          timeout: 60000,
        },
      );

      const content = response.data.choices[0].message.content;

      // Parse JSON response
      const quizData = this.parseQuizResponse(content);

      // Add unique IDs to questions
      const questions = quizData.questions.map((q, index) => ({
        ...q,
        questionId: `q${index + 1}`,
      }));

      this.logger.log(`Successfully generated ${questions.length} questions`);
      return questions;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`Failed to generate quiz: ${errorMessage}`);
      throw error;
    }
  }

  /**
   * Build quiz generation prompt
   */
  private buildQuizPrompt(
    transcriptText: string,
    difficulty: string,
    questionCount: number,
  ): string {
    // Truncate transcript if too long
    const maxLength = 3000;
    const transcript =
      transcriptText.length > maxLength
        ? transcriptText.substring(0, maxLength) + '...'
        : transcriptText;

    const difficultyGuide: Record<string, string> = {
      easy: 'Focus on simple vocabulary and basic comprehension. Questions should be suitable for 6-year-old children.',
      medium: 'Focus on sentence understanding and simple inference. Questions should challenge but not frustrate.',
      hard: 'Focus on comprehensive understanding and critical thinking. Questions should require deeper analysis.',
    };

    return `Based on this video transcript, generate ${questionCount} ${difficulty} level English learning multiple choice questions for children.

Transcript:
${transcript}

Requirements:
- ${difficultyGuide[difficulty] || difficultyGuide.easy}
- ALL questions must be type "multiple_choice"
- Each question must have exactly 4 options, only one correct
- Include a brief explanation for each answer
- Questions should test understanding of the video content

Return ONLY valid JSON in this exact format:
{
  "questions": [
    {
      "type": "multiple_choice",
      "question": "What food does the family cook at the barbecue?",
      "options": ["Sausages", "Pizza", "Chicken", "Fish"],
      "correctAnswer": "Sausages",
      "explanation": "The video mentions sausages being cooked at the barbecue."
    }
  ]
}`;
  }

  /**
   * Parse quiz response from LLM
   */
  private parseQuizResponse(content: string): { questions: QuizQuestion[] } {
    try {
      // Try to extract JSON from markdown code blocks
      const jsonMatch = content.match(/```json\s*([\s\S]*?)\s*```/) ||
                       content.match(/```\s*([\s\S]*?)\s*```/);

      const jsonStr = jsonMatch ? jsonMatch[1] : content;

      return JSON.parse(jsonStr);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(`Failed to parse quiz response: ${errorMessage}`);
      throw new Error('Invalid quiz response format');
    }
  }
}
