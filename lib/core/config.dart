/// App-wide settings. Change values here, not inside screens.
class AppConfig {
  static const appName = 'Nexa Tap';

  static const supabaseUrl = 'https://apohamvfvyajrphlvgzo.supabase.co';
  static const supabaseKey = 'sb_publishable_V96aBetmLfRP6jweI8rtPQ_JYNsiOqI';

  /// Public profile page (GitHub Pages). People land here when they tap
  /// the card or scan the QR code.
  static const publicBaseUrl = 'https://albertrajm.github.io/nexa-tap/';

  /// Price per physical NFC card, in rupees.
  static const cardPrice = 499;

  /// Extra charge per card for premium finishes.
  static const premiumExtra = 200;
  static const referralDiscountPercent = 15;

  /// Google login: the "Web application" client ID from Google Cloud
  /// (ends with .apps.googleusercontent.com). Not a secret.
  static const googleWebClientId = '882577910808-ml1hqc0kpjfcs7ao39kbvc4aohjer9rk.apps.googleusercontent.com';
  static bool get googleReady => googleWebClientId.endsWith('.apps.googleusercontent.com');

  static const supportEmail = 'support@nexatap.in';

  static String profileLink(String username, {String? type}) {
    final t = type == null ? '' : '&c=$type';
    return '${publicBaseUrl}?u=$username$t';
  }
}
