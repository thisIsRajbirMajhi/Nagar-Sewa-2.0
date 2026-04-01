import 'dart:typed_data';
import '../models/verification_result.dart';

/// Video metadata extraction service.
///
/// Extracts creation time and GPS coordinates from MP4/MOV video files
/// by parsing the moov/mvhd and udta atoms.
class VideoMetadataService {
  static Future<ExifMetadata> extractMetadata(Uint8List videoBytes) async {
    try {
      if (videoBytes.length < 1024) {
        return const ExifMetadata(hasFullExif: false);
      }

      final header = videoBytes.sublist(0, 1024);
      final moovOffset = _findAtomOffset(header, 'moov');

      DateTime? captureTime;
      double? lat;
      double? lng;

      if (moovOffset != null) {
        final moovData = videoBytes.sublist(
          moovOffset,
          (moovOffset + 2048).clamp(0, videoBytes.length),
        );

        captureTime = _extractCreationTime(moovData);
        final gpsData = _extractGpsFromMoov(moovData);
        if (gpsData != null) {
          lat = gpsData['lat'];
          lng = gpsData['lng'];
        }
      }

      return ExifMetadata(
        latitude: lat,
        longitude: lng,
        captureTime: captureTime,
        hasFullExif: captureTime != null,
      );
    } catch (e) {
      return const ExifMetadata(hasFullExif: false);
    }
  }

  static int? _findAtomOffset(Uint8List data, String atom) {
    final atomBytes = atom.codeUnits;
    for (int i = 0; i < data.length - 8; i++) {
      bool match = true;
      for (int j = 0; j < atomBytes.length; j++) {
        if (data[i + j] != atomBytes[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return null;
  }

  static DateTime? _extractCreationTime(Uint8List data) {
    try {
      int mvhdOffset = -1;
      for (int i = 0; i < data.length - 8; i++) {
        if (data[i] == 0x6D &&
            data[i + 1] == 0x76 &&
            data[i + 2] == 0x68 &&
            data[i + 3] == 0x64) {
          mvhdOffset = i;
          break;
        }
      }

      if (mvhdOffset < 0) return null;

      final version = data[mvhdOffset + 4];
      int timeOffset;

      if (version == 0) {
        timeOffset = mvhdOffset + 16;
      } else {
        timeOffset = mvhdOffset + 24;
      }

      if (timeOffset + 4 > data.length) return null;

      final seconds = _readUInt32BE(data, timeOffset);
      final dateTime = DateTime.fromMillisecondsSinceEpoch(
        (seconds - 2082844800) * 1000,
        isUtc: true,
      );

      if (dateTime.year < 1990 || dateTime.year > 2100) return null;
      return dateTime;
    } catch (_) {
      return null;
    }
  }

  static int _readUInt32BE(Uint8List data, int offset) {
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  static Map<String, double>? _extractGpsFromMoov(Uint8List data) {
    try {
      final udtaOffsetNullable = _findAtomOffset(data, 'udta');
      if (udtaOffsetNullable == null) return null;
      final udtaOffset = udtaOffsetNullable;

      final udtaEnd = (udtaOffset + _readAtomSize(data, udtaOffset)).clamp(
        0,
        data.length,
      );

      int subOffset = udtaOffset + 8;
      while (subOffset < udtaEnd - 8) {
        final size = _readAtomSize(data, subOffset);
        final atomType = String.fromCharCodes(
          data.sublist(subOffset + 4, subOffset + 8),
        );

        if (atomType == 'com.apple.quicktime.location.' || atomType == '©xyz') {
          final atomData = data.sublist(
            subOffset + 8,
            (subOffset + size).clamp(0, data.length),
          );
          return _parseLocationAtom(atomData);
        }

        subOffset += size;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static int _readAtomSize(Uint8List data, int offset) {
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  static Map<String, double>? _parseLocationAtom(Uint8List data) {
    if (data.length < 3) return null;

    int nullIndex = 0;
    while (nullIndex < data.length && data[nullIndex] != 0) {
      nullIndex++;
    }

    if (nullIndex >= data.length) return null;

    final latString = String.fromCharCodes(data.sublist(0, nullIndex));
    final lat = double.tryParse(latString);
    if (lat == null) return null;

    int lngStart = nullIndex + 1;
    int lngIndex = lngStart;
    while (lngIndex < data.length && data[lngIndex] != 0) {
      lngIndex++;
    }

    if (lngIndex >= data.length) return null;

    final lngString = String.fromCharCodes(data.sublist(lngStart, lngIndex));
    final lng = double.tryParse(lngString);

    if (lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

    return {'lat': lat, 'lng': lng};
  }
}
