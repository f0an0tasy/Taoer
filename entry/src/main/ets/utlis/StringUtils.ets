import util from '@ohos.util'

/**
 * 默认字符串工具
 */
export class StringUtils {
  static stringToArrayBuffer(str: string): ArrayBuffer {
    let textEncoder = new util.TextEncoder("utf-8");
    return textEncoder.encodeInto(str).buffer;
  }

  static arrayBufferToString(buffer: ArrayBuffer): string {
    let textDecoder = util.TextDecoder.create('utf-8')
    return textDecoder.decodeToString(new Uint8Array(buffer))
  }

  static isNotEmpty(str: string): boolean {
    return str.length>0 && str!=undefined
  }

  static isEmpty(str: string): boolean {
    return (!str) || str.length == 0;
  }
}