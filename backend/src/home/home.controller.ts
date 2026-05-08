import { Controller, Get } from '@nestjs/common';
import { ProfilesService } from '../profiles/profiles.service';
import { TasksService } from '../tasks/tasks.service';

@Controller('home')
export class HomeController {
  constructor(
    private readonly profiles: ProfilesService,
    private readonly tasks: TasksService,
  ) {}

  @Get('today')
  async today() {
    const profile = await this.profiles.getCurrentProfile();
    return this.tasks.homePayload(profile);
  }
}
