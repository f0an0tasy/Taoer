import http from '@ohos.net.http';
import util from '@ohos.util';
import { BusinessError } from '@kit.BasicServicesKit';

// ↓↓↓ 在这里换成你的智谱 API Key（https://open.bigmodel.cn/usercenter/proj-mgmt/apikeys）
const ZHIPU_API_KEY = '18d7db16ce7c46ae90bed0659797f89a.m4iqxRxTNTNNTLFw'
const ZHIPU_API_URL = 'https://open.bigmodel.cn/api/paas/v4/chat/completions'
const ZHIPU_MODEL = 'glm-4.5-flash'

interface Message {
  role: string
  content: string
}

interface Body {
  model: string
  messages: Message[]
  stream: boolean
  temperature: number
}

interface Delta {
  content: string
  reasoning_content: string
}

interface Choice {
  delta: Delta
  index: number
  finish_reason: string
}

interface StreamResponse {
  choices: Choice[]
  id: string
  model: string
  created: number
  error?: ErrorBody
}

interface ErrorBody {
  message: string
  code: string
}

export interface Callback {
  onError: (error: BusinessError | Error) => void
  onDataReceive: (reasonContent: string, content: string) => void
  onCompleted: () => void
}

export class StreamAIUtil {

  private static parseStreamLine(jsonStr: string, callback: Callback): void {
    if (jsonStr === '[DONE]') {
      return;
    }

    try {
      const response = JSON.parse(jsonStr) as StreamResponse;

      if (response.error) {
        callback.onError(new Error(response.error.message));
        return;
      }

      if (!response.choices || response.choices.length === 0) {
        return;
      }

      const delta = response.choices[0].delta;
      if (!delta) {
        return;
      }

      const reasoningContent: string = delta.reasoning_content ? delta.reasoning_content : '';
      const content: string = delta.content ? delta.content : '';

      if (reasoningContent || content) {
        callback.onDataReceive(reasoningContent, content);
      }
    } catch (err) {
      console.error(`JSON解析失败: ${err}`);
      console.error('原始数据:', jsonStr.substring(0, 200));
    }
  }

  private static parseStreamData(dataStr: string, callback: Callback): void {
    const lines = dataStr.split('\n');

    for (const line of lines) {
      const trimmedLine = line.trim();
      if (trimmedLine === '') {
        continue;
      }

      let jsonStr = trimmedLine;
      if (trimmedLine.startsWith('data: ')) {
        jsonStr = trimmedLine.substring(6);
      }

      StreamAIUtil.parseStreamLine(jsonStr, callback);
    }
  }

  private static appendAndParse(
    textBuffer: string,
    newChunk: string,
    callback: Callback
  ): string {
    let buffer = textBuffer + newChunk;
    const lastNewline = buffer.lastIndexOf('\n');

    if (lastNewline >= 0) {
      const completePart = buffer.substring(0, lastNewline);
      buffer = buffer.substring(lastNewline + 1);
      StreamAIUtil.parseStreamData(completePart, callback);
    }

    return buffer;
  }

  static async StreamAI(content: string, callback: Callback): Promise<void> {
    if (ZHIPU_API_KEY.length === 0 || ZHIPU_API_KEY.startsWith('请替换')) {
      callback.onError(new Error('请先在 StreamAIUtil.ets 第6行配置智谱 API Key'));
      return;
    }

    let httpRequest = http.createHttp();

    let textBuffer = '';
    const textDecoder = util.TextDecoder.create('utf-8');

    let isRequestCompleted = false;
    let hasParsedData = false;

    const flushBuffer = (): void => {
      if (textBuffer.length > 0) {
        StreamAIUtil.parseStreamData(textBuffer, callback);
        textBuffer = '';
        hasParsedData = true;
      }
    };

    httpRequest.on('dataReceive', (data: ArrayBuffer) => {
      const chunk = textDecoder.decodeToString(new Uint8Array(data));
      if (chunk.length > 0) {
        textBuffer = StreamAIUtil.appendAndParse(textBuffer, chunk, callback);
        hasParsedData = true;
      }
    });

    httpRequest.on('dataEnd', () => {
      console.info('智谱AI数据接收完毕，开始解析');
      isRequestCompleted = true;

      try {
        flushBuffer();
        callback.onCompleted();
      } catch (err) {
        console.error(`数据解析错误: ${err}`);
        callback.onError(new Error(`${err}`));
      }
    });

    let headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${ZHIPU_API_KEY}`
    };

    const systemMessage: Message = {
      role: 'system',
      content: '你是一位专业的二手商品购买顾问，擅长为用户提供选购建议、价格评估、成色判断和交易注意事项。请勿使用表格（包括Markdown表格、ASCII表格等），回答内容请用纯文本、列表或段落组织。'
    };
    let userMessage: Message = { role: 'user', content: content };
    let body: Body = {
      model: ZHIPU_MODEL,
      messages: [systemMessage, userMessage],
      stream: true,
      temperature: 0.7
    };

    console.info('开始请求智谱AI...');
    console.info('请求体:', JSON.stringify(body));

    httpRequest.requestInStream(
      ZHIPU_API_URL,
      {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(body),
        readTimeout: 6000000
      },
      (err: BusinessError) => {
        if (err) {
          console.error(`请求失败: 错误码 ${err.code}, 信息 ${err.message}`);
          callback.onError(err);
        } else if (!isRequestCompleted) {
          console.warn('请求完成但未收到 dataEnd 事件，尝试解析缓冲区');
          try {
            flushBuffer();
            if (!hasParsedData) {
              callback.onError(new Error('未收到有效回复数据'));
            } else {
              callback.onCompleted();
            }
          } catch (parseErr) {
            callback.onError(new Error(`${parseErr}`));
          }
        }

        httpRequest.destroy();
      }
    );
  }
}

export { StreamAIUtil as getStreamAI }
