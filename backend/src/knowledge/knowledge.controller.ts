import { Controller, Get, Param, Post, Query } from '@nestjs/common';
import { KnowledgeService } from './knowledge.service';

const CURRENT_PROFILE_ID = '000000000000000000000001';

@Controller('knowledge')
export class KnowledgeController {
  constructor(private readonly knowledgeService: KnowledgeService) {}

  @Get('home')
  home() {
    return this.knowledgeService.home(CURRENT_PROFILE_ID);
  }

  @Get('search')
  search(@Query('q') query?: string) {
    return this.knowledgeService.search(CURRENT_PROFILE_ID, query || '');
  }

  @Get('nodes/:id')
  nodeDetail(@Param('id') id: string) {
    return this.knowledgeService.nodeDetail(CURRENT_PROFILE_ID, id);
  }

  @Get('nodes/:id/links')
  nodeLinks(@Param('id') id: string) {
    return this.knowledgeService.linksForNode(CURRENT_PROFILE_ID, id);
  }

  @Post('videos/:videoId/build')
  buildVideo(@Param('videoId') videoId: string) {
    return this.knowledgeService.buildForVideo(CURRENT_PROFILE_ID, videoId);
  }

  @Get('videos/:videoId/nodes')
  videoKnowledge(@Param('videoId') videoId: string) {
    return this.knowledgeService.videoKnowledge(CURRENT_PROFILE_ID, videoId);
  }
}
