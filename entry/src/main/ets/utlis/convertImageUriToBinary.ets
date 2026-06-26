import { image } from '@kit.ImageKit';
import { buffer } from '@kit.ArkTS';
import fs from '@ohos.file.fs';
export async function convertImageUriToBinary(imageUri: string): Promise<string> {
  console.log('开始转换图片为二进制，图片 URI：', imageUri);
  let imageSource: image.ImageSource | null = null;
  let pixelMap: image.PixelMap | null = null;
  let fd: number | null = null;
  try {
    // 2. 使用 fileIo 打开图片文件，获取文件描述符 (fd)
    try {
      const imgFile = fs.openSync(imageUri, fs.OpenMode.READ_ONLY);
      fd = imgFile.fd;
      console.log('成功打开图片文件，文件描述符：', fd);
    } catch (error) {
      console.error('打开图片文件失败', error);
      throw new Error(`打开图片文件失败: ${error}`);
    }
    // 3. 使用 image.createImageSource(fd) 创建 ImageSource 对象
    try {
      imageSource = image.createImageSource(fd);
      console.log('ImageSource 创建成功');
    } catch (error) {
      console.error('ImageSource 创建失败', error);
      throw new Error(`ImageSource 创建失败: ${error}`);
    }
    // 4. 使用 imageSource.createPixelMap() 创建 PixelMap 对象
    try {
      pixelMap = await imageSource.createPixelMap();
      console.log('PixelMap 创建成功');
    } catch (error) {
      console.error('PixelMap 创建失败', error);
      throw new Error(`PixelMap 创建失败: ${error}`);
    }
    // 5. 将 PixelMap 转换为 Base64 字符串
    const base64String = await pixelMapToBase64(pixelMap);
    console.log('Base64 编码成功，Base64 字符串长度：', base64String.length);
    console.log(base64String)
    return base64String;
  } catch (error) {
    console.error('转换图片失败', error);
    throw new Error(`图片转换失败: ${error}`);
  } finally {
    // 6. 释放资源
    if (pixelMap) {
      pixelMap.release();
    }
    if (imageSource) {
      imageSource.release();
    }
    if (fd) {
      try {
        fs.closeSync(fd);
        console.log('成功关闭文件');
      } catch (error) {
        console.error('关闭文件失败', error);
      }
    }
  }
}
async function pixelMapToBase64(pixelMap: image.PixelMap): Promise<string> {
  return new Promise((resolve, reject) => {
    const imagePackerApi = image.createImagePacker();
    const packOpts: image.PackingOption = { format: "image/jpeg", quality: 98 }; // 可根据需要调整 format 和 quality

    imagePackerApi.packing(pixelMap, packOpts)
      .then((data: ArrayBuffer) => {
        const base64Str = buffer.from(data).toString('base64');
        const resultBase64Str = `data:${packOpts.format};base64,${base64Str}`; // 使用 packOpts.format
        resolve(resultBase64Str);
      })
      .catch((error: Error) => {
        console.error('Failed to pack the image. And the error is: ' + error);
        reject(error);
      });
  });
}