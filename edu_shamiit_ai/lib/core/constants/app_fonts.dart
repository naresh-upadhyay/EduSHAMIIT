import 'package:google_fonts/google_fonts.dart';

class AppFonts {
  // Font families (will be loaded via GoogleFonts in the theme)
  static const String outfit = 'Outfit';
  static const String dmSans = 'DM Sans';

  // Recommended usage
  static const String heading = outfit;
  static const String body = dmSans;
  static const String mono = 'RobotoMono'; // fallback


  // Font weight constants for convenience
  static const int thin = 100;
  static const int extraLight = 200;
  static const int light = 300;
  static const int regular = 400;
  static const int medium = 500;
  static const int semiBold = 600;
  static const int bold = 700;
  static const int extraBold = 800;
  static const int black = 900;
}
