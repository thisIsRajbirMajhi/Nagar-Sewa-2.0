import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../core/constants/app_constants.dart';

class ImageCompressionService {
  static Future<Uint8List> compressImage(Uint8List bytes) async {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    var resized = image;
    if (image.width > ImageConstants.maxImageWidth ||
        image.height > ImageConstants.maxImageHeight) {
      resized = img.copyResize(
        image,
        width: min(ImageConstants.maxImageWidth, image.width),
        height: min(ImageConstants.maxImageHeight, image.height),
        interpolation: img.Interpolation.linear,
      );
    }

    final compressed = img.encodeJpg(
      resized,
      quality: ImageConstants.imageQuality,
    );
    return Uint8List.fromList(compressed);
  }

  static Future<Uint8List> compressIfNeeded(Uint8List bytes) async {
    if (bytes.length <= ImageConstants.maxImageSizeBytes) return bytes;
    return compressImage(bytes);
  }
}
