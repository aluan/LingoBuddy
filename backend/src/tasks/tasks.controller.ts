import { Controller, Get, Param, Post } from '@nestjs/common';
import { TasksService } from './tasks.service';

@Controller('tasks')
export class TasksController {
  constructor(private readonly tasks: TasksService) {}

  @Get('today')
  async today() {
    const task = await this.tasks.getTodayTask();
    return this.tasks.serializeTask(task);
  }

  @Post(':id/complete')
  async complete(@Param('id') id: string) {
    return this.tasks.completeTask(id);
  }
}
