import { Body, Controller, Param, Post } from '@nestjs/common';
import { VoiceSessionService } from './voice-session.service';

@Controller('voice/sessions')
export class VoiceSessionController {
  constructor(private readonly voiceSession: VoiceSessionService) {}

  @Post('start')
  async startSession(@Body() body: { taskId?: string; videoId?: string }) {
    return this.voiceSession.startSession(body.taskId, body.videoId);
  }

  @Post(':sessionId/transcript')
  async saveTranscript(
    @Param('sessionId') sessionId: string,
    @Body() body: { text: string; role: 'child' | 'astra' },
  ) {
    return this.voiceSession.saveTranscript(sessionId, body.text, body.role);
  }

  @Post(':sessionId/reward')
  async grantReward(
    @Param('sessionId') sessionId: string,
    @Body() body: { stars: number },
  ) {
    return this.voiceSession.grantReward(sessionId, body.stars);
  }

  @Post(':sessionId/end')
  async endSession(@Param('sessionId') sessionId: string) {
    return this.voiceSession.endSession(sessionId);
  }
}
