import { Injectable } from '@nestjs/common';
import vision from '@google-cloud/vision';
import {v2} from '@google-cloud/translate'

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

  async translate(texts: string[], to: string): Promise<string[]>{
    let [translations] = await this.trans.translate(texts, to);
    translations = Array.isArray(translations) ? translations : [translations];
    return translations
  }
}