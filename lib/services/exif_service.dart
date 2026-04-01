import 'dart:typed_data';
import 'package:exif/exif.dart' as exif_pkg;
import '../models/verification_result.dart';

class ExifService {
  static Future<ExifMetadata> extractMetadata(Uint8List imageBytes) async {
    try {
      final data = await exif_pkg.readExifFromBytes(imageBytes);

      if (data.isEmpty) {
        return const ExifMetadata(hasFullExif: false);
      }

      double? lat;
      double? lng;
      DateTime? captureTime;
      String? deviceMake;
      String? deviceModel;

      final gpsLat = data['GPS GPSLatitude'];
      final gpsLatRef = data['GPS GPSLatitudeRef'];
      final gpsLng = data['GPS GPSLongitude'];
      final gpsLngRef = data['GPS GPSLongitudeRef'];

      if (gpsLat != null && gpsLng != null) {
        lat = _convertGps(gpsLat.values as List, gpsLatRef?.printable);
        lng = _convertGps(gpsLng.values as List, gpsLngRef?.printable);
      }

      final dateTime = data['EXIF DateTimeOriginal'];
      if (dateTime != null) {
        captureTime = _parseExifDate(dateTime.printable);
      }

      deviceMake = data['Image Make']?.printable;
      deviceModel = data['Image Model']?.printable;

      return ExifMetadata(
        latitude: lat,
        longitude: lng,
        captureTime: captureTime,
        deviceMake: deviceMake,
        deviceModel: deviceModel,
        hasFullExif: lat != null && lng != null && captureTime != null,
      );
    } catch (e) {
      return const ExifMetadata(hasFullExif: false);
    }
  }

  static double? _convertGps(List values, String? ref) {
    if (values.length < 3) return null;

    final degrees = _ratioToDouble(values[0]);
    final minutes = _ratioToDouble(values[1]);
    final seconds = _ratioToDouble(values[2]);

    double result = degrees + (minutes / 60) + (seconds / 3600);

    if (ref == 'S' || ref == 'W') {
      result = -result;
    }

    return result;
  }

  static double _ratioToDouble(dynamic value) {
    if (value is exif_pkg.Ratio) {
      return value.numerator / value.denominator;
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _parseExifDate(String dateStr) {
    try {
      final parts = dateStr.split(' ');
      if (parts.length != 2) return null;

      final dateParts = parts[0].split(':');
      final timeParts = parts[1].split(':');

      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        int.parse(timeParts[2]),
      );
    } catch (e) {
      return null;
    }
  }
}
