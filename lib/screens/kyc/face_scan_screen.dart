import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

enum _Phase { scanning, faceFound, blinkConfirmed, capturing }

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  static Future<File?> open(BuildContext context) => Navigator.push<File?>(
        context,
        MaterialPageRoute(builder: (_) => const FaceScanScreen()),
      );

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  CameraController? _cam;
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  _Phase _phase    = _Phase.scanning;
  bool   _busy     = false;
  bool   _eyeClosed = false;
  int    _countdown = 3;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cam?.dispose();
    _detector.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera found on this device.');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cam = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await _cam!.initialize();
      if (!mounted) return;
      setState(() {});
      _cam!.startImageStream(_onFrame);
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera could not be opened.');
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _phase == _Phase.capturing) return;
    _busy = true;
    try {
      final input = _toInput(image);
      if (input == null) return;

      final faces = await _detector.processImage(input);
      if (!mounted) return;

      if (faces.isEmpty) {
        if (_phase != _Phase.scanning) setState(() { _phase = _Phase.scanning; _eyeClosed = false; });
        return;
      }

      final face      = faces.first;
      final sizeRatio = face.boundingBox.width / image.width;

      // Reject if face is too far (< 18%) or too close (> 82%)
      if (sizeRatio < 0.18 || sizeRatio > 0.82) {
        if (_phase != _Phase.scanning) setState(() { _phase = _Phase.scanning; _eyeClosed = false; });
        return;
      }

      if (_phase == _Phase.blinkConfirmed) return;

      final leftOpen  = face.leftEyeOpenProbability  ?? 1.0;
      final rightOpen = face.rightEyeOpenProbability ?? 1.0;

      // Track blink: eyes close then open.
      // NOTE: this blink/liveness check is UX-level guidance ONLY — it is not a
      // security control and must never be trusted server-side. Selfie integrity
      // is enforced on the server via the single-use capture-challenge nonce
      // (see ApiService.getSelfieChallenge / kyc/selfie/challenge) plus EXIF
      // inspection and re-encode at ingest. A determined client can bypass this
      // on-device check, so the server treats every selfie as a Pending review item.
      if (leftOpen < 0.25 && rightOpen < 0.25) _eyeClosed = true;
      if (_eyeClosed && leftOpen > 0.65 && rightOpen > 0.65) {
        setState(() => _phase = _Phase.blinkConfirmed);
        _startCountdown();
        return;
      }

      if (_phase == _Phase.scanning) setState(() => _phase = _Phase.faceFound);
    } finally {
      _busy = false;
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        _capture();
      }
    });
  }

  Future<void> _capture() async {
    setState(() => _phase = _Phase.capturing);
    try {
      await _cam!.stopImageStream();
      final xFile = await _cam!.takePicture();
      if (mounted) Navigator.pop(context, File(xFile.path));
    } catch (_) {
      if (mounted) Navigator.pop(context, null);
    }
  }

  InputImage? _toInput(CameraImage image) {
    if (_cam == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) return null;

    final rotation = Platform.isIOS
        ? (InputImageRotationValue.fromRawValue(_cam!.description.sensorOrientation)
            ?? InputImageRotation.rotation0deg)
        : InputImageRotation.rotation270deg;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(UniconsLine.video_slash, color: Colors.white54, size: 56),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Go Back', style: TextStyle(color: AppColors.emeraldDeep)),
          ),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _cam?.value.isInitialized == true
          ? _buildCamera()
          : const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep)),
    );
  }

  Widget _buildCamera() {
    final size = MediaQuery.of(context).size;
    final top  = MediaQuery.of(context).padding.top;

    final ovalColor = switch (_phase) {
      _Phase.scanning       => Colors.white54,
      _Phase.faceFound      => const Color(0xFFF59E0B),
      _Phase.blinkConfirmed => AppColors.emeraldDeep,
      _Phase.capturing      => AppColors.emeraldMid,
    };

    final instruction = switch (_phase) {
      _Phase.scanning       => 'Position your face\nin the oval',
      _Phase.faceFound      => 'Blink once to verify\nyou\'re a real person',
      _Phase.blinkConfirmed => 'Hold still...',
      _Phase.capturing      => 'Capturing...',
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen camera preview
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width:  _cam!.value.previewSize!.height,
              height: _cam!.value.previewSize!.width,
              child: CameraPreview(_cam!),
            ),
          ),
        ),

        // Dark overlay with oval cutout
        CustomPaint(painter: _OvalOverlay(color: ovalColor)),

        // Back button
        Positioned(
          top: top + 12, left: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context, null),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black54,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(UniconsLine.arrow_left, color: Colors.white, size: 22),
            ),
          ),
        ),

        // Screen title
        Positioned(
          top: top + 14, left: 0, right: 0,
          child: const Text('Facial Scan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800,
                shadows: [Shadow(blurRadius: 8, color: Colors.black)],
              )),
        ),

        // Instruction (above oval)
        Positioned(
          top: size.height * 0.13,
          left: 28, right: 28,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(instruction,
                key: ValueKey(_phase),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700,
                  height: 1.45,
                  shadows: [Shadow(blurRadius: 12, color: Colors.black87)],
                )),
          ),
        ),

        // Countdown number (centred inside oval)
        if (_phase == _Phase.blinkConfirmed)
          Positioned.fill(
            child: Center(
              child: Transform.translate(
                offset: Offset(0, size.height * 0.02),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text('$_countdown',
                      key: ValueKey(_countdown),
                      style: const TextStyle(
                        color: Colors.white, fontSize: 88, fontWeight: FontWeight.w900,
                        shadows: [Shadow(blurRadius: 24, color: Colors.black)],
                      )),
                ),
              ),
            ),
          ),

        // Bottom progress + tips
        Positioned(
          bottom: 36, left: 20, right: 20,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _ProgressRow(phase: _phase),
            const SizedBox(height: 18),
            if (_phase == _Phase.scanning) ...[
              _tip(UniconsLine.sun,     'Ensure your face is well lit'),
              _tip(UniconsLine.eye,'Look directly at the camera'),
              _tip(UniconsLine.smile,          'Remove glasses, hats, or scarves'),
            ] else if (_phase == _Phase.faceFound)
              _tip(UniconsLine.info_circle, 'Perform a natural, deliberate blink'),
          ]),
        ),
      ],
    );
  }

  Widget _tip(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: Colors.white60, size: 15),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13)),
    ]),
  );
}

// ── Oval overlay ──────────────────────────────────────────────────────────────

class _OvalOverlay extends CustomPainter {
  final Color color;
  const _OvalOverlay({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.44),
      width:  size.width  * 0.72,
      height: size.height * 0.44,
    );

    // Dark overlay with oval cutout
    final cutout = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(cutout, Paint()..color = Colors.black.withAlpha(175));

    // Oval border
    canvas.drawOval(ovalRect, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5);

    // Arc guides at 4 cardinal points to help user centre face
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    const span = 0.40;
    for (final start in [-3.14159, -1.5708, 0.0, 1.5708]) {
      canvas.drawArc(ovalRect, start - span / 2, span, false, arc);
    }
  }

  @override
  bool shouldRepaint(_OvalOverlay old) => old.color != color;
}

// ── Progress row ──────────────────────────────────────────────────────────────

class _ProgressRow extends StatelessWidget {
  final _Phase phase;
  const _ProgressRow({required this.phase});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _Dot(label: 'Face found',
          done: phase != _Phase.scanning),
      _Connector(filled: phase == _Phase.blinkConfirmed || phase == _Phase.capturing),
      _Dot(label: 'Blink',
          done: phase == _Phase.blinkConfirmed || phase == _Phase.capturing),
      _Connector(filled: phase == _Phase.capturing),
      _Dot(label: 'Capture',
          done: phase == _Phase.capturing),
    ],
  );
}

class _Dot extends StatelessWidget {
  final String label;
  final bool done;
  const _Dot({required this.label, required this.done});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: 22, height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:  done ? AppColors.emeraldMid : Colors.white24,
        border: Border.all(
            color: done ? AppColors.emeraldMid : Colors.white38, width: 2),
      ),
      child: done
          ? const Icon(UniconsLine.check, color: Colors.white, size: 13)
          : null,
    ),
    const SizedBox(height: 5),
    Text(label,
        style: const TextStyle(color: Colors.white60, fontSize: 10,
            fontWeight: FontWeight.w500)),
  ]);
}

class _Connector extends StatelessWidget {
  final bool filled;
  const _Connector({required this.filled});

  @override
  Widget build(BuildContext context) => Container(
    width: 44, height: 2,
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: filled ? AppColors.emeraldMid : Colors.white24,
      borderRadius: BorderRadius.circular(1),
    ),
  );
}
