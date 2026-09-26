import { Module } from '@nestjs/common';
import {translation} from './app.controller.js';
import {OcrService, TranslateService, canvas } from './app.service.js';

@Module({
  controllers: [translation],
  providers: [OcrService, TranslateService, canvas],
})
export class AppModule {} 