import { Controller, Get } from '@nestjs/common';
import { RewardsService } from './rewards.service';

@Controller('rewards')
export class RewardsController {
  constructor(private readonly rewards: RewardsService) {}

  @Get()
  async list() {
    return this.rewards.listRewards();
  }
}
