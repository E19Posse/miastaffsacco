import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';

// Shown before FaceScanScreen so the front camera never opens without warning.
// Tapping "Start Scan" is the only thing that triggers the camera.
class SelfieIntroScreen extends StatelessWidget {
  const SelfieIntroScreen({super.key});

  static Future<bool> show(BuildContext context) async {
    final started = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SelfieIntroScreen()),
    );
    return started ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(children: [
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: c.card, shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(UniconsLine.arrow_left, color: c.textPrimary, size: 18),
                ),
              ),
            ]),
            const Spacer(),

            Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(color: AppColors.emeraldDeep, shape: BoxShape.circle),
              child: const Icon(UniconsLine.camera, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text('Quick Facial Scan', textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary)),
            const SizedBox(height: 8),
            Text(
              "We'll open your front camera to confirm it's really you. "
              "You'll be asked to blink once, then a photo is captured automatically.",
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),

            _tip(c, UniconsLine.sun, 'Find a well-lit spot'),
            const SizedBox(height: 12),
            _tip(c, UniconsLine.smile, 'Remove glasses, hats, or scarves'),
            const SizedBox(height: 12),
            _tip(c, UniconsLine.eye, 'Look directly at the camera and blink once when asked'),

            const Spacer(),
            SizedBox(width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldDeep, foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: Text('Start Scan', style: GoogleFonts.sora(fontWeight: FontWeight.w800, fontSize: 16)),
              )),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Not now', style: TextStyle(color: c.textSecondary, fontSize: 14)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tip(AppColorScheme c, IconData icon, String text) => Row(children: [
    Icon(icon, color: AppColors.emeraldDeep, size: 18),
    const SizedBox(width: 10),
    Expanded(child: Text(text, style: TextStyle(color: c.textPrimary, fontSize: 13.5))),
  ]);
}
