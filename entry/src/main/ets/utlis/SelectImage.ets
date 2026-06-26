import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { BusinessError } from "@kit.BasicServicesKit";

/**
 * 使用 PhotoViewPicker 选择图片，直接返回图片 URI（不进行 Base64 转换）
 * @param num 最大选择数量
 * @returns CoverData 包含图片 URI 数组
 */
async function getAlbum(num: number): Promise<CoverData> {
  const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
  photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  photoSelectOptions.maxSelectNumber = num;
  
  let coverData: CoverData = {
    imageUrl: [],
    errorMessage: ''
  };
  
  const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
  
  try {
    const photoSelectResult: photoAccessHelper.PhotoSelectResult = await photoViewPicker.select(photoSelectOptions);
    const uris = photoSelectResult.photoUris;

    if (uris && uris.length > 0) {
      // 直接使用 URI，不进行 Base64 转换
      coverData.imageUrl = uris;
      console.info(`选择图片成功，共 ${uris.length} 张，URI: ${uris.join(', ')}`);
    } else {
      console.warn('未选择图片');
      coverData.imageUrl = [];
    }
  } catch (err) {
    const error = err as BusinessError;
    console.error(`Invoke photoViewPicker.select failed, code is ${error.code}, message is ${error.message}`);
    coverData.errorMessage = '选择图片失败';
    coverData.imageUrl = [];
  }
  
  return coverData;
}

interface CoverData {
  imageUrl: string[],
  errorMessage: string
}

export {
  getAlbum,
  CoverData
}
