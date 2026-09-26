import { StreamableFile, Header, Controller, Post, UseInterceptors, UploadedFile, ParseFilePipe, FileTypeValidator} from '@nestjs/common';
import {FileInterceptor} from '@nestjs/platform-express'
import { MaxFileSizeValidator } from '@nestjs/common';
import { OcrService, TranslateService, canvas } from './app.service.js';



const MAX_UPLOAD_BYTES = 10 * 1024 * 1024; // 10 MB

@Controller()
export class translation {
  constructor(private readonly ocr:OcrService, 
    private readonly translator: TranslateService,
    private readonly draw:canvas) {} 
  @Post('translate')
  @Header('Content-type', 'image/png')
  @UseInterceptors(FileInterceptor('file', {
    limits: {
      fileSize: MAX_UPLOAD_BYTES,
      files: 1,
    },
  }))
  async uploadfile(@UploadedFile(
    new ParseFilePipe({
      validators: [
        new MaxFileSizeValidator({maxSize: MAX_UPLOAD_BYTES}),
        new FileTypeValidator({fileType: /^image\/(png|jpeg)$/}),
      ],
  }),
  )
  file: Express.Multer.File
  ) {
    const blocks = await this.ocr.detect(file.buffer);
    // no text found: send the original screenshot back unchanged
    if (blocks.length === 0) {
      return new StreamableFile(file.buffer);
    }
    const text = blocks.map((b) => b.text);

    const translations = await this.translator.translate(text);
    const png = await this.draw.drawImage(file.buffer, blocks, translations);

    return new StreamableFile(png)
  }

}


