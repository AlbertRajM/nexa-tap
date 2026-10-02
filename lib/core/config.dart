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
  static const referralDiscountPercent = 15;

  static const supportEmail = 'support@nexatap.in';

  static String profileLink(String username, {String? type}) {
    final t = type == null ? '' : '&c=$type';
    return '${publicBaseUrl}?u=$username$t';
  }
}
