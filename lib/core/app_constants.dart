class AppConstants {
  AppConstants._();

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // Padding
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  // Font Sizes
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeTitle = 18.0;
  static const double fontSizeHeadline = 24.0;

  // Animation Durations
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 300);

  // Naver Map Style
  static const String naverMapStyleId = 'e0aa762a-75d3-4e45-a38e-dd8385fefb73';

  // Firebase Collections
  static const String colUsers = 'users';
  static const String colPosts = 'community_posts';
  static const String colNotices = 'notices';
  static const String colInquiries = 'inquiries';
  static const String colReports = 'reports';
  static const String colAppConfig = 'app_config';
}
