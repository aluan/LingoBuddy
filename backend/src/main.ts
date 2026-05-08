import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { VoiceRealtimeServer } from './voice/voice-realtime.server';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);
  const voiceServer = app.get(VoiceRealtimeServer);
  const port = config.get<number>('PORT') ?? 3000;

  app.enableCors({
    origin: true,
    credentials: true,
  });

  voiceServer.attach(app.getHttpServer());

  await app.listen(port);
  console.log(`LingoBuddy API listening on http://localhost:${port}`);
  console.log(`Realtime voice WebSocket listening on ws://localhost:${port}/voice/realtime`);
}

bootstrap().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});

process.on('beforeExit', (code) => {
  console.log(`LingoBuddy API process beforeExit: ${code}`);
});
