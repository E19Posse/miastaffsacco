import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Corner-radius scale (Ivy-inspired: generous, consistent) ─────────────────
class AppRadius {
  static const double sm = 12;   // chips, small controls
  static const double md = 16;   // inputs, buttons (non-pill)
  static const double lg = 20;   // cards
  static const double xl = 28;   // hero cards / sheets
  static const double pill = 999; // stadium
}

// ── Brand colours (same in every theme) ──────────────────────────────────────
// MIA Staff SACCO design-system palette (per the "Complete Design Prompt" spec):
// deep emerald primary, amber gold accent, literal credit/debit greens/reds.
// NOTE: tinted/pastel backgrounds (solidTint below) are NOT an approved
// pattern for new UI — the no-tinted-colors rule in UI_DESIGN_STYLE.md
// applies here too. Use solid brand colors + onColor() for new work.
class AppColors {
  static const cream      = Color(0xFFF5F0E0); // --color-cream (page bg)
  static const creamSoft  = Color(0xFFFAF6EA); // --color-cream-soft
  static const emeraldDeep= Color(0xFF064E3B); // --color-emerald-deep (primary)
  static const primaryDark= Color(0xFF043D2F);
  static const primaryLight=Color(0xFFD1FAE5);
  static const emeraldMid = Color(0xFF0D7A5F); // --color-emerald-mid
  static const gold       = Color(0xFFC9A84C); // --color-gold
  static const danger     = Color(0xFFB91C1C); // --color-danger
  /// Standard (non-gold-tier) verification badge colour — deliberately distinct
  /// from [gold] so members below the gold credit-score threshold don't show
  /// the same badge colour as gold-tier members. NOT the same as [blue] below,
  /// which is a back-compat alias onto gold used throughout the rest of the UI.
  static const verifiedBlue = Color(0xFF2F6FED);
  static const onDark     = Colors.white;       // text/icon on emerald-deep surfaces

  // Back-compat aliases (kept so existing call sites don't all need renaming
  // in one pass): primary/primaryDk/blue/error map onto the new brand roles.
  static const primary   = emeraldDeep;
  static const primaryDk = primaryDark;
  static const blue      = gold;
  static const blueSoft  = gold;
  static const success   = emeraldMid; // credit
  static const warning   = gold;
  static const error     = danger;     // debit
  static const purple    = emeraldMid;

  /// Alpha-blended tint backgrounds, used directly for badges/icon tiles/chips.
  static final emeraldTint = emeraldMid.withValues(alpha: 0.15);
  static final goldTint    = gold.withValues(alpha: 0.15);

  /// Returns a fully opaque tinted background for icon containers.
  /// Equivalent to painting [brand] at 20% over the theme surface.
  static Color solidTint(Color brand, bool isDark) => Color.alphaBlend(
    brand.withAlpha(isDark ? 56 : 46),
    isDark ? const Color(0xFF1E1E1E) : Colors.white,
  );

  /// Suitable text/icon colour on top of [bg]. Always fully opaque —
  /// Colors.black87 is only 87% opaque and reads as a transparent color.
  static Color onColor(Color bg) =>
      bg.computeLuminance() > 0.35 ? Colors.black : Colors.white;
}

// ── Theme-sensitive colour scheme (dark / light) ──────────────────────────────
@immutable
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  const AppColorScheme({
    required this.bg,
    required this.surface,
    required this.card,
    required this.cardAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.border,
    required this.borderActive,
  });

  final Color bg;
  final Color surface;
  final Color card;
  final Color cardAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color border;
  final Color borderActive;

  static const dark = AppColorScheme(
    bg:           Color(0xFF121212),
    surface:      Color(0xFF1E1E1E),
    card:         Color(0xFF252525),
    cardAlt:      Color(0xFF2C2C2C),
    textPrimary:  Color(0xFFFFFFFF),
    textSecondary:Color(0xFF9E9E9E),
    textHint:     Color(0xFF616161),
    border:       Color(0xFF333333),
    borderActive: Color(0xFF0D7A5F), // emerald-mid
  );

  // Matches styles.css :root exactly: --background/--foreground/--card/--border.
  static const light = AppColorScheme(
    bg:           Color(0xFFF5F0E0), // --background (cream)
    surface:      Color(0xFFFFFFFF), // --card
    card:         Color(0xFFFFFFFF),
    cardAlt:      Color(0xFFFAF6EA), // cream-soft
    textPrimary:  Color(0xFF064E3B), // --foreground (emerald-deep)
    textSecondary:Color(0x99064E3B), // --muted-foreground (emerald-deep @ 60%)
    textHint:     Color(0x66064E3B), // emerald-deep @ 40%
    border:       Color(0x1A064E3B), // --border (emerald-deep @ 10%)
    borderActive: Color(0xFF064E3B),
  );

  @override
  AppColorScheme copyWith({
    Color? bg, Color? surface, Color? card, Color? cardAlt,
    Color? textPrimary, Color? textSecondary, Color? textHint,
    Color? border, Color? borderActive,
  }) => AppColorScheme(
    bg:           bg           ?? this.bg,
    surface:      surface      ?? this.surface,
    card:         card         ?? this.card,
    cardAlt:      cardAlt      ?? this.cardAlt,
    textPrimary:  textPrimary  ?? this.textPrimary,
    textSecondary:textSecondary?? this.textSecondary,
    textHint:     textHint     ?? this.textHint,
    border:       border       ?? this.border,
    borderActive: borderActive ?? this.borderActive,
  );

  @override
  AppColorScheme lerp(AppColorScheme? other, double t) {
    if (other is! AppColorScheme) return this;
    return AppColorScheme(
      bg:           Color.lerp(bg,           other.bg,           t)!,
      surface:      Color.lerp(surface,      other.surface,      t)!,
      card:         Color.lerp(card,         other.card,         t)!,
      cardAlt:      Color.lerp(cardAlt,      other.cardAlt,      t)!,
      textPrimary:  Color.lerp(textPrimary,  other.textPrimary,  t)!,
      textSecondary:Color.lerp(textSecondary,other.textSecondary,t)!,
      textHint:     Color.lerp(textHint,     other.textHint,     t)!,
      border:       Color.lerp(border,       other.border,       t)!,
      borderActive: Color.lerp(borderActive, other.borderActive, t)!,
    );
  }
}

// Shorthand: context.colors.bg, context.colors.card, etc.
extension AppColorsExt on BuildContext {
  AppColorScheme get colors => Theme.of(this).extension<AppColorScheme>()!;
}

// ── Responsive sizing utilities ───────────────────────────────────────────────
// Design baseline is 390 dp (iPhone 14 / Pixel 7 size).
// Use context.rs(n) wherever you'd write a fixed pixel size.
extension ResponsiveExt on BuildContext {
  Size   get screenSize   => MediaQuery.sizeOf(this);
  double get screenWidth  => screenSize.width;
  double get screenHeight => screenSize.height;

  /// Scale [size] proportionally to screen width, clamped to ±15 % of the base.
  double rs(double size) =>
      (size * (screenWidth / 390.0)).clamp(size * 0.85, size * 1.15);

  /// Adaptive horizontal content padding (scales 17–23 dp across phone sizes).
  double get hPad => rs(20);

  /// Bottom inset height (home indicator / gesture bar) — use for last-item padding.
  double get bottomInset => MediaQuery.paddingOf(this).bottom;
}

// ── Themes ────────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColorScheme.light.bg,
      colorScheme: const ColorScheme.light(
        surface:   Color(0xFFFFFFFF),
        primary:   AppColors.emeraldDeep,
        secondary: AppColors.gold,
        error:     AppColors.danger,
        onPrimary: Colors.white,
        onSurface: Color(0xFF064E3B),
      ),
      // Sora for headings/display text, Manrope for body — matches the
      // reference's --font-display / --font-body.
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
        bodyColor:    const Color(0xFF064E3B),
        displayColor: const Color(0xFF064E3B),
      ).copyWith(
        displayLarge:  GoogleFonts.sora(fontWeight: FontWeight.w800),
        displayMedium: GoogleFonts.sora(fontWeight: FontWeight.w800),
        displaySmall:  GoogleFonts.sora(fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.sora(fontWeight: FontWeight.w800),
        headlineMedium:GoogleFonts.sora(fontWeight: FontWeight.w700),
        headlineSmall: GoogleFonts.sora(fontWeight: FontWeight.w700),
        titleLarge:    GoogleFonts.sora(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorScheme.light.bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.sora(
          fontSize: 20, fontWeight: FontWeight.w800,
          color: AppColorScheme.light.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColorScheme.light.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: GoogleFonts.manrope(color: AppColorScheme.light.textHint, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: AppColorScheme.light.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: AppColorScheme.light.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emeraldDeep,
          foregroundColor: AppColors.cream,
          minimumSize: const Size(double.infinity, 54),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.emeraldDeep,
        unselectedItemColor: Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: AppColorScheme.light.border, thickness: 1, space: 1,
      ),
      extensions: const [AppColorScheme.light],
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColorScheme.dark.bg,
      colorScheme: const ColorScheme.dark(
        surface:   Color(0xFF1E1E1E),
        primary:   AppColors.emeraldMid,
        secondary: AppColors.gold,
        error:     AppColors.danger,
        onPrimary: Colors.black,
        onSurface: Color(0xFFFFFFFF),
      ),
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
        bodyColor:    AppColorScheme.dark.textPrimary,
        displayColor: AppColorScheme.dark.textPrimary,
      ).copyWith(
        displayLarge:  GoogleFonts.sora(fontWeight: FontWeight.w800),
        displayMedium: GoogleFonts.sora(fontWeight: FontWeight.w800),
        displaySmall:  GoogleFonts.sora(fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.sora(fontWeight: FontWeight.w800),
        headlineMedium:GoogleFonts.sora(fontWeight: FontWeight.w700),
        headlineSmall: GoogleFonts.sora(fontWeight: FontWeight.w700),
        titleLarge:    GoogleFonts.sora(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorScheme.dark.bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.sora(
          fontSize: 20, fontWeight: FontWeight.w800,
          color: AppColorScheme.dark.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColorScheme.dark.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColorScheme.dark.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorScheme.dark.surface,
        hintStyle: GoogleFonts.manrope(color: AppColorScheme.dark.textHint, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: AppColorScheme.dark.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: AppColorScheme.dark.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emeraldMid,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 54),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColorScheme.dark.surface,
        selectedItemColor: AppColors.emeraldMid,
        unselectedItemColor: AppColorScheme.dark.textHint,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: AppColorScheme.dark.border, thickness: 1, space: 1,
      ),
      extensions: const [AppColorScheme.dark],
    );
  }
}
