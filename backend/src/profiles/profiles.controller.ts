import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ProfilesService, UpdateProfileInput } from './profiles.service';

@Controller('profile')
export class ProfilesController {
  constructor(private readonly profiles: ProfilesService) {}

  @Get('current')
  async current() {
    const profile = await this.profiles.getCurrentProfile();
    return {
      id: profile.id,
      nickname: profile.nickname,
      age: profile.age,
      interests: profile.interests,
    };
  }

  @Patch('current')
  async update(@Body() body: UpdateProfileInput) {
    const profile = await this.profiles.updateCurrentProfile(body);
    return {
      id: profile.id,
      nickname: profile.nickname,
      age: profile.age,
      interests: profile.interests,
    };
  }
}
