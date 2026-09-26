import { Injectable } from '@nestjs/common';
import vision from '@google-cloud/vision';
import {v2} from '@google-cloud/translate'

import {createCanvas, loadImage} from '@napi-rs/canvas'


export interface Box {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface TextBlock {
  text: string;
  box: Box;
}

@Injectable()
export class OcrService {
  private readonly client = new vision.ImageAnnotatorClient();

  async detect(image:Buffer): Promise<TextBlock[]> {
    const [result] = await this.client.documentTextDetection({
      image: {content:image}}
    )

    const blocks: TextBlock[] = [];

    // pages -> blocks -> paragraphs; each paragraph is one piece of text to translate
    for (const page of result.fullTextAnnotation?.pages ?? []) {
      for (const block of page.blocks ?? []) {
        for (const paragraph of block.paragraphs ?? []) {
          // paragraphs -> words -> symbols (single letters); rebuild the sentence
          let text = '';
          for (const word of paragraph.words ?? []) {
            for (const symbol of word.symbols ?? []) {
              text += symbol.text ?? '';
              // a detectedBreak means a space or line break comes after this letter
              if (symbol.property?.detectedBreak) {
                text += ' ';
              }
            }
          }

          text = text.trim();
          if (text) {
            blocks.push({ text, box: toBox(paragraph.boundingBox?.vertices ?? []) });
          }
        }
      }
    }

    return blocks;
  }
}

// Turns Google's 4 corner points into x/y/width/height.
// Google leaves out x or y when it is 0, hence the ?? 0.
function toBox(vertices: { x?: number | null; y?: number | null }[]): Box {
  const xs = vertices.map((v) => v.x ?? 0);
  const ys = vertices.map((v) => v.y ?? 0);
  const x = Math.min(...xs);
  const y = Math.min(...ys);
  return { x, y, width: Math.max(...xs) - x, height: Math.max(...ys) - y };
}




@Injectable() 
export class TranslateService{
  private readonly trans = new v2.Translate()

  async translate(texts: string[]): Promise<string[]>{
    let [translations] = await this.trans.translate(texts, { from: 'es', to: 'en' });
    translations = Array.isArray(translations) ? translations : [translations];
    return translations
  }
}


@Injectable()
export class canvas{
  async drawImage(image:Buffer, blocks:TextBlock[], translations:string[]): Promise<Buffer>{
    const img = await loadImage(image);
    const canvas = createCanvas(img.width, img.height);
    const ctx = canvas.getContext('2d')
    ctx.drawImage(img, 0, 0 )
    // make y the top of the text, so it lines up with box.y
    ctx.textBaseline = 'top';

    for (let i=0; i < blocks.length; i ++) {
      const box = blocks[i].box;
      const message = translations[i];
      // fillStyle is shared: white for the cover box, then black for the text
      ctx.fillStyle = "white";
      // grow the cover a few pixels so accents and ¿ ¡ that stick out of the box are hidden too
      const pad = 4;
      ctx.fillRect(box.x - pad, box.y - pad, box.width + pad * 2, box.height + pad * 2)
      // scale the font to the box instead of a fixed size (screenshots are high resolution)
      ctx.font = `${Math.round(box.height * 0.8)}px Arial`;
      ctx.fillStyle = "black";
      ctx.fillText(message,box.x, box.y)
    }
    return canvas.encode('png')
  }

}