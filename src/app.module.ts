import { Module } from '@nestjs/common';
import {translation} from './app.controller.js';
import {OcrService, TranslateService } from './app.service.js';

@Module({
  controllers: [translation],
  providers: [OcrService, TranslateService],
})
export class AppModule {} 