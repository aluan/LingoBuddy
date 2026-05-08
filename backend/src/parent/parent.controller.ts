import { Controller, Get, Query } from '@nestjs/common';
import { ParentService } from './parent.service';

@Controller('parent')
export class ParentController {
  constructor(private readonly parent: ParentService) {}

  @Get('summary')
  async summary(@Query('date') date?: string) {
    return this.parent.summary(date);
  }
}
