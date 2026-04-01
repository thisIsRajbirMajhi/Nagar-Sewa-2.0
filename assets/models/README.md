# ML Models Directory

This directory should contain the trained ML models for the verification layer.

## Required Models

### 1. efficientnet_lite_fake_detector.tflite
- **Purpose**: Image authenticity classification (real vs AI-generated/edited)
- **Input**: 224x224 RGB image
- **Output**: Float value 0.0-1.0 (probability of being real)
- **Size**: ~5MB
- **Status**: Placeholder (fallback heuristics used until model is trained)

## Training Instructions

1. Collect dataset of real vs fake/AI-generated images
2. Train EfficientNet-Lite model on the dataset
3. Export to TensorFlow Lite format
4. Place the `.tflite` file in this directory
5. Update `ai_authenticity_service.dart` to use the model

## Placeholder Behavior

Until the model is trained and placed here, the system uses basic heuristics:
- File size analysis
- Image distribution analysis
- EXIF metadata presence
