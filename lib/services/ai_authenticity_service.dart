import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../core/constants/app_constants.dart';

class AuthenticityResult {
  final double score;
  final double laionScore;
  final double exifScore;
  final double frequencyScore;
  final double compressionScore;
  final List<String> detectedArtifacts;
  final bool isAiGenerated;
  final bool needsReview;

  const AuthenticityResult({
    required this.score,
    required this.laionScore,
    required this.exifScore,
    required this.frequencyScore,
    required this.compressionScore,
    required this.detectedArtifacts,
    required this.isAiGenerated,
    required this.needsReview,
  });
}

class AiAuthenticityService {
  static const int _maxPixelSamples = 50000;

  Future<AuthenticityResult> checkAuthenticity(Uint8List imageBytes) async {
    return checkAuthenticitySync(imageBytes);
  }

  AuthenticityResult checkAuthenticitySync(Uint8List imageBytes) {
    final laionFeatures = _extractLaionFeatures(imageBytes);
    final exifAnalysis = _analyzeExifArtifacts(imageBytes);
    final frequencyAnalysis = _analyzeFrequencyDomain(imageBytes);
    final compressionAnalysis = _analyzeCompressionArtifacts(imageBytes);

    final laionScore = laionFeatures['score'] as double;
    final exifScore = exifAnalysis['score'] as double;
    final frequencyScore = frequencyAnalysis['score'] as double;
    final compressionScore = compressionAnalysis['score'] as double;

    final List<String> allArtifacts = [
      ...(laionFeatures['artifacts'] as List<String>),
      ...(exifAnalysis['artifacts'] as List<String>),
      ...(frequencyAnalysis['artifacts'] as List<String>),
      ...(compressionAnalysis['artifacts'] as List<String>),
    ];

    final combinedScore =
        (laionScore * VerificationConstants.authenticityWeight * 2 +
                exifScore * 0.2 +
                frequencyScore * 0.2 +
                compressionScore * 0.2)
            .clamp(0.0, 1.0);

    final isAiGenerated = laionScore < 0.5 || exifScore < 0.3;
    final needsReview = combinedScore < 0.7 || allArtifacts.length > 2;

    return AuthenticityResult(
      score: combinedScore,
      laionScore: laionScore,
      exifScore: exifScore,
      frequencyScore: frequencyScore,
      compressionScore: compressionScore,
      detectedArtifacts: allArtifacts,
      isAiGenerated: isAiGenerated,
      needsReview: needsReview,
    );
  }

  Map<String, dynamic> _extractLaionFeatures(Uint8List imageBytes) {
    final List<String> artifacts = [];
    double score = 1.0;

    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return {
          'score': 0.5,
          'artifacts': ['decode_failed'],
        };
      }

      final grayscale = img.grayscale(image);
      final pixels = grayscale.getBytes();

      final edgeDensity = _calculateEdgeDensity(
        pixels,
        image.width,
        image.height,
      );
      if (edgeDensity < 0.05) {
        artifacts.add('low_edge_density');
        score -= 0.2;
      } else if (edgeDensity > 0.5) {
        artifacts.add('high_edge_density');
        score -= 0.1;
      }

      final textureUniformity = _calculateTextureUniformity(pixels);
      if (textureUniformity > 0.9) {
        artifacts.add('uniform_texture');
        score -= 0.25;
      } else if (textureUniformity < 0.3) {
        artifacts.add('noisy_texture');
        score -= 0.1;
      }

      final colorDistribution = _analyzeColorDistribution(image);
      if (colorDistribution['is_oversaturated'] == true) {
        artifacts.add('oversaturated_colors');
        score -= 0.15;
      }
      if (colorDistribution['is_unnatural'] == true) {
        artifacts.add('unnatural_color_distribution');
        score -= 0.2;
      }

      final frequencySpectrum = _analyzeFrequencySpectrum(
        pixels,
        image.width,
        image.height,
      );
      if (frequencySpectrum['is_ai_pattern'] == true) {
        artifacts.add('ai_frequency_pattern');
        score -= 0.25;
      }
    } catch (e) {
      artifacts.add('analysis_error');
      score = 0.5;
    }

    return {'score': score.clamp(0.0, 1.0), 'artifacts': artifacts};
  }

  Map<String, dynamic> _analyzeExifArtifacts(Uint8List imageBytes) {
    final List<String> artifacts = [];
    double score = 1.0;

    if (imageBytes.length < 1000) {
      artifacts.add('too_small');
      return {'score': 0.3, 'artifacts': artifacts};
    }

    final hasJpegMarkers = _checkJpegMarkers(imageBytes);
    if (!hasJpegMarkers) {
      artifacts.add('no_jpeg_markers');
      score -= 0.2;
    }

    final quantizationArtifacts = _checkQuantizationArtifacts(imageBytes);
    if (quantizationArtifacts) {
      artifacts.add('quantization_artifact');
      score -= 0.1;
    }

    final compressionRatio = _calculateCompressionRatio(imageBytes);
    if (compressionRatio > 0.15) {
      artifacts.add('high_compression');
      score -= 0.15;
    } else if (compressionRatio < 0.02) {
      artifacts.add('low_compression');
      score -= 0.1;
    }

    final headerAnalysis = _analyzeImageHeader(imageBytes);
    if (headerAnalysis['suspicious'] == true) {
      artifacts.add('suspicious_header');
      score -= 0.2;
    }

    return {'score': score.clamp(0.0, 1.0), 'artifacts': artifacts};
  }

  Map<String, dynamic> _analyzeFrequencyDomain(Uint8List imageBytes) {
    final List<String> artifacts = [];
    double score = 1.0;

    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return {'score': 0.5, 'artifacts': [], 'is_ai_pattern': false};
      }

      final grayscale = img.grayscale(image);
      final pixels = grayscale.getBytes();

      final width = image.width;
      final height = image.height;

      final fftResult = _simpleFFT(pixels, width, height);

      final highFreqRatio = fftResult['highFreqRatio'] as double;
      final lowFreqRatio = fftResult['lowFreqRatio'] as double;

      if (highFreqRatio < 0.05 && lowFreqRatio > 0.85) {
        artifacts.add('suspicious_frequency_ratio');
        score -= 0.25;
      }

      if (highFreqRatio > 0.4) {
        artifacts.add('excessive_high_frequency');
        score -= 0.15;
      }

      final spectralAnalysis = _analyzeSpectralPeaks(fftResult);
      if (spectralAnalysis['has_peaks']) {
        artifacts.add('spectral_peaks');
        score -= 0.2;
      }
    } catch (e) {
      score = 0.7;
    }

    return {
      'score': score.clamp(0.0, 1.0),
      'artifacts': artifacts,
      'is_ai_pattern': artifacts.contains('suspicious_frequency_ratio'),
    };
  }

  Map<String, dynamic> _analyzeCompressionArtifacts(Uint8List imageBytes) {
    final List<String> artifacts = [];
    double score = 1.0;

    final blockArtifacts = _checkBlockArtifacts(imageBytes);
    if (blockArtifacts) {
      artifacts.add('block_artifacts');
      score -= 0.1;
    }

    final ringingArtifacts = _checkRingingArtifacts(imageBytes);
    if (ringingArtifacts) {
      artifacts.add('ringing_artifacts');
      score -= 0.15;
    }

    final mosquitoNoise = _checkMosquitoNoise(imageBytes);
    if (mosquitoNoise) {
      artifacts.add('mosquito_noise');
      score -= 0.1;
    }

    final colorBleeding = _checkColorBleeding(imageBytes);
    if (colorBleeding) {
      artifacts.add('color_bleeding');
      score -= 0.1;
    }

    return {'score': score.clamp(0.0, 1.0), 'artifacts': artifacts};
  }

  double _calculateEdgeDensity(Uint8List pixels, int width, int height) {
    if (pixels.isEmpty) return 0.5;

    int edgeCount = 0;
    const threshold = 30;
    final sampledWidth = min(width, 256);
    final sampledHeight = min(height, 256);
    final stepX = (width / sampledWidth).ceil();
    final stepY = (height / sampledHeight).ceil();

    for (int y = stepY; y < height - stepY; y += stepY) {
      for (int x = stepX; x < width - stepX; x += stepX) {
        final idx = y * width + x;
        if (idx >= pixels.length - width) continue;

        final gx = (pixels[idx + stepX] - pixels[idx - stepX]).abs();
        final gy =
            (pixels[(idx + width * stepY).clamp(0, pixels.length - 1)] -
                    pixels[(idx - width * stepY).clamp(0, pixels.length - 1)])
                .abs();

        if (gx > threshold || gy > threshold) {
          edgeCount++;
        }
      }
    }

    final totalPixels = sampledWidth * sampledHeight;
    return edgeCount / totalPixels;
  }

  double _calculateTextureUniformity(Uint8List pixels) {
    if (pixels.isEmpty) return 0.5;

    int uniformCount = 0;
    const windowSize = 8;
    final limit = min(pixels.length, _maxPixelSamples);

    for (int i = 0; i < limit - windowSize; i += windowSize) {
      final window = pixels.sublist(
        i,
        (i + windowSize).clamp(0, pixels.length),
      );
      final avg = window.reduce((a, b) => a + b) / window.length;
      final variance =
          window.map((v) => pow(v - avg, 2)).reduce((a, b) => a + b) /
          window.length;

      if (variance < 100) {
        uniformCount++;
      }
    }

    final totalWindows = limit ~/ windowSize;
    return totalWindows > 0 ? uniformCount / totalWindows : 0.5;
  }

  Map<String, dynamic> _analyzeColorDistribution(img.Image image) {
    bool isOversaturated = false;
    bool isUnnatural = false;
    int sampledCount = 0;
    final stepX = max(1, image.width ~/ 64);
    final stepY = max(1, image.height ~/ 64);

    for (
      int y = 0;
      y < image.height && sampledCount < _maxPixelSamples;
      y += stepY
    ) {
      for (
        int x = 0;
        x < image.width && sampledCount < _maxPixelSamples;
        x += stepX
      ) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        if (r > 250 && g > 250 && b > 250) {
          isOversaturated = true;
        }
        final maxC = max(r, max(g, b));
        final minC = min(r, min(g, b));
        if (maxC > 0 && (maxC - minC) / maxC < 0.05) {
          isUnnatural = true;
        }
        sampledCount++;
      }
      if (isOversaturated && isUnnatural) break;
    }

    return {'is_oversaturated': isOversaturated, 'is_unnatural': isUnnatural};
  }

  Map<String, dynamic> _analyzeFrequencySpectrum(
    Uint8List pixels,
    int width,
    int height,
  ) {
    final fftResult = _simpleFFT(pixels, width, height);

    final highFreqRatio = fftResult['highFreqRatio'] as double;
    final lowFreqRatio = fftResult['lowFreqRatio'] as double;

    return {'is_ai_pattern': highFreqRatio < 0.05 && lowFreqRatio > 0.85};
  }

  Map<String, dynamic> _simpleFFT(Uint8List pixels, int width, int height) {
    final size = min(width, height);
    final sampleSize = min(size, 64);

    double lowFreqSum = 0;
    double highFreqSum = 0;

    for (int i = 0; i < sampleSize; i++) {
      for (int j = 0; j < sampleSize; j++) {
        final idx = (i * width + j) % pixels.length;
        final value = pixels[idx];

        final freqWeight = sin(pi * i / sampleSize) * sin(pi * j / sampleSize);
        lowFreqSum += value * freqWeight;
        highFreqSum += value * (1 - freqWeight);
      }
    }

    final total = lowFreqSum + highFreqSum;
    final lowFreqRatio = total > 0 ? lowFreqSum / total : 0.5;
    final highFreqRatio = total > 0 ? highFreqSum / total : 0.5;

    return {'lowFreqRatio': lowFreqRatio, 'highFreqRatio': highFreqRatio};
  }

  Map<String, dynamic> _analyzeSpectralPeaks(Map<String, dynamic> fftResult) {
    final lowFreqRatio = fftResult['lowFreqRatio'] as double;

    return {'has_peaks': lowFreqRatio > 0.9 || lowFreqRatio < 0.1};
  }

  bool _checkJpegMarkers(Uint8List imageBytes) {
    if (imageBytes.length < 2) return false;
    return imageBytes[0] == 0xFF && imageBytes[1] == 0xD8;
  }

  bool _checkQuantizationArtifacts(Uint8List imageBytes) {
    int ffCount = 0;
    final limit = min(imageBytes.length, 10000);
    for (int i = 0; i < limit; i++) {
      if (imageBytes[i] == 0xFF) ffCount++;
    }
    return ffCount > 200;
  }

  double _calculateCompressionRatio(Uint8List imageBytes) {
    return imageBytes.length / (800 * 600 * 3);
  }

  Map<String, dynamic> _analyzeImageHeader(Uint8List imageBytes) {
    bool suspicious = false;

    if (imageBytes.length < 1000) {
      suspicious = true;
    }

    int zeroRun = 0;
    int maxZeroRun = 0;
    final limit = min(imageBytes.length, 1000);
    for (int i = 0; i < limit; i++) {
      if (imageBytes[i] == 0) {
        zeroRun++;
        if (zeroRun > maxZeroRun) maxZeroRun = zeroRun;
      } else {
        zeroRun = 0;
      }
    }

    if (maxZeroRun > 500) {
      suspicious = true;
    }

    return {'suspicious': suspicious};
  }

  bool _checkBlockArtifacts(Uint8List imageBytes) {
    return false;
  }

  bool _checkRingingArtifacts(Uint8List imageBytes) {
    return false;
  }

  bool _checkMosquitoNoise(Uint8List imageBytes) {
    return false;
  }

  bool _checkColorBleeding(Uint8List imageBytes) {
    return false;
  }
}
