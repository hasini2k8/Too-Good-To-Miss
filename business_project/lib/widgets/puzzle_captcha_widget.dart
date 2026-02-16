import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;

/// A custom puzzle CAPTCHA widget that requires users to slide a piece to complete a puzzle
class PuzzleCaptchaWidget extends StatefulWidget {
  final Function(bool) onVerified;
  final double width;
  final double height;

  const PuzzleCaptchaWidget({
    Key? key,
    required this.onVerified,
    this.width = 300,
    this.height = 150,
  }) : super(key: key);

  @override
  State<PuzzleCaptchaWidget> createState() => _PuzzleCaptchaWidgetState();
}

class _PuzzleCaptchaWidgetState extends State<PuzzleCaptchaWidget> {
  double _sliderValue = 0.0;
  double _targetPosition = 0.0;
  bool _isVerified = false;
  bool _isFailed = false;
  final Random _random = Random();
  
  // Puzzle piece dimensions
  final double _puzzlePieceSize = 50;
  final double _tolerance = 10; // Pixels of tolerance for correct placement

  @override
  void initState() {
    super.initState();
    _generateNewPuzzle();
  }

  void _generateNewPuzzle() {
    setState(() {
      // Generate random position for the puzzle gap (avoid edges)
      _targetPosition = _random.nextDouble() * 
          (widget.width - _puzzlePieceSize - 40) + 20;
      _sliderValue = 0.0;
      _isVerified = false;
      _isFailed = false;
    });
  }

  void _checkPosition() {
    final difference = (_sliderValue - _targetPosition).abs();
    
    if (difference <= _tolerance) {
      // Success!
      setState(() {
        _isVerified = true;
        _isFailed = false;
      });
      widget.onVerified(true);
    } else {
      // Failed - need to retry
      setState(() {
        _isFailed = true;
        _isVerified = false;
      });
      widget.onVerified(false);
      
      // Reset after a delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _generateNewPuzzle();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isVerified 
              ? Colors.green 
              : _isFailed 
                  ? Colors.red 
                  : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                _isVerified 
                    ? Icons.check_circle 
                    : _isFailed 
                        ? Icons.error 
                        : Icons.security,
                color: _isVerified 
                    ? Colors.green 
                    : _isFailed 
                        ? Colors.red 
                        : const Color(0xFF1565C0),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isVerified 
                      ? 'Verification Successful!' 
                      : _isFailed 
                          ? 'Please try again' 
                          : 'Slide to complete the puzzle',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isVerified 
                        ? Colors.green 
                        : _isFailed 
                            ? Colors.red 
                            : Colors.grey.shade700,
                  ),
                ),
              ),
              if (!_isVerified)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _generateNewPuzzle,
                  tooltip: 'Generate new puzzle',
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Puzzle area
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1565C0).withOpacity(0.1),
                  const Color(0xFF0D47A1).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              children: [
                // Background pattern
                CustomPaint(
                  size: Size(widget.width, widget.height),
                  painter: BackgroundPatternPainter(),
                ),
                
                // Target gap position indicator (subtle)
                Positioned(
                  left: _targetPosition,
                  top: (widget.height - _puzzlePieceSize) / 2,
                  child: Container(
                    width: _puzzlePieceSize,
                    height: _puzzlePieceSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.crop_square,
                        color: Colors.grey.shade400,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                
                // Moving puzzle piece
                if (!_isVerified)
                  Positioned(
                    left: _sliderValue,
                    top: (widget.height - _puzzlePieceSize) / 2,
                    child: Container(
                      width: _puzzlePieceSize,
                      height: _puzzlePieceSize,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.drag_indicator,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                
                // Success checkmark
                if (_isVerified)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Slider control
          if (!_isVerified)
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 40,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 20,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 30,
                      ),
                      activeTrackColor: const Color(0xFF1565C0),
                      inactiveTrackColor: Colors.grey.shade300,
                      thumbColor: Colors.white,
                      overlayColor: const Color(0xFF1565C0).withOpacity(0.2),
                    ),
                    child: Slider(
                      value: _sliderValue,
                      min: 0,
                      max: widget.width - _puzzlePieceSize,
                      onChanged: (value) {
                        setState(() {
                          _sliderValue = value;
                        });
                      },
                      onChangeEnd: (value) {
                        _checkPosition();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Background pattern painter for visual appeal
class BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw grid pattern
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }
    
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}