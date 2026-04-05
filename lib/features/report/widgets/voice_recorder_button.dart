// lib/features/report/widgets/voice_recorder_button.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class VoiceRecorderButton extends StatefulWidget {
  final void Function(Uint8List? audioBytes) onRecordingComplete;

  const VoiceRecorderButton({super.key, required this.onRecordingComplete});

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton> {
  bool _isRecording = false;
  bool _hasRecording = false;
  // ignore: unused_field
  Duration _recordingDuration = Duration.zero;

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });
    // TODO: Integrate with record package for actual recording
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
      _hasRecording = true;
    });
    widget.onRecordingComplete(null);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleRecording,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: _isRecording
              ? AppColors.urgentRed
              : _hasRecording
              ? AppColors.greenAccent
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isRecording ? AppColors.urgentRed : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRecording
                  ? Icons.stop_rounded
                  : _hasRecording
                  ? Icons.check_circle
                  : Icons.mic_rounded,
              color: _isRecording || _hasRecording
                  ? Colors.white
                  : AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 6),
            Text(
              _isRecording
                  ? 'Stop'
                  : _hasRecording
                  ? 'Recorded'
                  : 'Voice Note',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _isRecording || _hasRecording
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
