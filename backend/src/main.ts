import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { networkInterfaces } from 'node:os';
import { AppModule } from './app.module';

function getLanUrls(port: number): string[] {
  return Object.values(networkInterfaces())
    .flatMap((items) => items ?? [])
    .filter((item) => item.family === 'IPv4' && !item.internal)
    .map((item) => `http://${item.address}:${port}`);
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);
  const port = config.get<number>('PORT') ?? 3000;
  const host = config.get<string>('HOST') ?? '0.0.0.0';

  app.enableCors({
    origin: true,
    credentials: true,
  });

  await app.listen(port, host);
  console.log(`LingoBuddy API listening on http://${host}:${port}`);
  for (const url of getLanUrls(port)) {
    console.log(`LAN API reachable at ${url}`);
  }
}

bootstrap().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});

process.on('beforeExit', (code) => {
  console.log(`LingoBuddy API process beforeExit: ${code}`);
});
