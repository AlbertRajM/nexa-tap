import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/icons.dart';

class Profile {
  final String id;
  final String fullName;
  final String email;
  final String username;
  final String referralCode;
  final String defaultCard;
  final bool active;
  final int views;

  Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.username,
    required this.referralCode,
    required this.defaultCard,
    required this.active,
    required this.views,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        fullName: (m['full_name'] ?? '') as String,
        email: (m['email'] ?? '') as String,
        username: (m['username'] ?? '') as String,
        referralCode: (m['referral_code'] ?? '') as String,
        defaultCard: (m['default_card'] ?? 'business') as String,
        active: (m['active'] ?? true) as bool,
        views: (m['views'] ?? 0) as int,
      );

  String get firstName {
    final parts = fullName.trim().split(' ');
    return parts.isEmpty || parts.first.isEmpty ? 'there' : parts.first;
  }
}

enum CardType { business, personal }

extension CardTypeX on CardType {
  String get label => this == CardType.business ? t('Business') : t('Personal');
  IconData get icon => this == CardType.business ? Ic.briefcase : Ic.user;
  String get blurb => this == CardType.business
      ? t('Company, role, work contacts and office address')
      : t('Personal contacts, bio and social profiles');
  static CardType parse(String s) => s == 'personal' ? CardType.personal : CardType.business;
}

class CardProfile {
  final String id;
  final CardType type;
  final bool enabled;
  final String design;
  final Map<String, dynamic> data;

  CardProfile({required this.id, required this.type, required this.enabled, required this.design, required this.data});

  factory CardProfile.fromMap(Map<String, dynamic> m) => CardProfile(
        id: m['id'] as String,
        type: CardTypeX.parse(m['type'] as String),
        enabled: (m['enabled'] ?? false) as bool,
        design: (m['design'] ?? 'graphite') as String,
        data: Map<String, dynamic>.from((m['data'] ?? {}) as Map),
      );

  String str(String key) => (data[key] ?? '').toString();

  CardProfile copyWith({bool? enabled, String? design, Map<String, dynamic>? data}) => CardProfile(
        id: id,
        type: type,
        enabled: enabled ?? this.enabled,
        design: design ?? this.design,
        data: data ?? this.data,
      );

  /// How complete the profile is, 0..1 (shown as a progress bar).
  double get completeness {
    final keys = type == CardType.business
        ? ['name', 'title', 'company', 'phone', 'email', 'website', 'address', 'avatar']
        : ['name', 'title', 'bio', 'phone', 'email', 'whatsapp', 'location', 'avatar'];
    final filled = keys.where((k) => str(k).trim().isNotEmpty).length;
    return filled / keys.length;
  }
}

class OrderStatus {
  static const steps = ['placed', 'confirmed', 'printing', 'quality_check', 'shipped', 'delivered'];

  static String label(String s) => switch (s) {
        'placed' => t('Order placed'),
        'confirmed' => t('Confirmed'),
        'printing' => t('Printing & encoding'),
        'quality_check' => t('Quality check'),
        'shipped' => t('Shipped'),
        'delivered' => t('Delivered'),
        'cancelled' => t('Cancelled'),
        _ => s,
      };

  static String detail(String s) => switch (s) {
        'placed' => t('We have received your order.'),
        'confirmed' => t('Our team has confirmed the details and payment.'),
        'printing' => t('Your card is being printed and the NFC chip programmed.'),
        'quality_check' => t('Every card is tap-tested before it leaves.'),
        'shipped' => t('Your card is on the way.'),
        'delivered' => t('Delivered. Tap it on any phone to share your profile.'),
        _ => '',
      };

  static int index(String s) => steps.indexOf(s);
}

class Order {
  final String id;
  final String orderNo;
  final String cardType;
  final String design;
  final String nameOnCard;
  final int quantity;
  final String phone;
  final String address;
  final String city;
  final String pincode;
  final int amount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.orderNo,
    required this.cardType,
    required this.design,
    required this.nameOnCard,
    required this.quantity,
    required this.phone,
    required this.address,
    required this.city,
    required this.pincode,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromMap(Map<String, dynamic> m) => Order(
        id: m['id'] as String,
        orderNo: (m['order_no'] ?? '') as String,
        cardType: (m['card_type'] ?? 'business') as String,
        design: (m['design'] ?? 'graphite') as String,
        nameOnCard: (m['name_on_card'] ?? '') as String,
        quantity: (m['quantity'] ?? 1) as int,
        phone: (m['phone'] ?? '') as String,
        address: (m['address'] ?? '') as String,
        city: (m['city'] ?? '') as String,
        pincode: (m['pincode'] ?? '') as String,
        amount: (m['amount'] ?? 0) as int,
        status: (m['status'] ?? 'placed') as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse((m['updated_at'] ?? m['created_at']) as String).toLocal(),
      );
}

enum CardPattern { none, lines, carbon, dots, waves, marble, grid }

/// Physical card finishes. Premium finishes cost a little extra when ordered.
class CardDesign {
  final String id;
  final String name;
  final String finish;
  final Color bg;
  final Color fg;
  final Color line;
  final List<Color>? gradient;
  final CardPattern pattern;
  final bool premium;
  const CardDesign(this.id, this.name, this.finish, this.bg, this.fg, this.line,
      {this.gradient, this.pattern = CardPattern.none, this.premium = false});

  static const all = <CardDesign>[
    // Standard
    CardDesign('graphite', 'Graphite', 'Matte black', Color(0xFF16171C), Color(0xFFF3F3F3), Color(0xFFC8FF4D),
        pattern: CardPattern.lines),
    CardDesign('volt', 'Volt', 'Electric lime matte', Color(0xFFC8FF4D), Color(0xFF0B0D1A), Color(0xFF0B0D1A),
        pattern: CardPattern.dots),
    CardDesign('navy', 'Midnight', 'Deep navy', Color(0xFF101A33), Color(0xFFF1F2F4), Color(0xFFB59A5A),
        gradient: [Color(0xFF0B1226), Color(0xFF1C2B55)]),
    CardDesign('ivory', 'Ivory', 'Soft-touch white', Color(0xFFF2EEE6), Color(0xFF1A1A1A), Color(0xFFB9B2A4)),
    CardDesign('forest', 'Forest', 'Matte green', Color(0xFF1E3A2E), Color(0xFFEDEDE6), Color(0xFF8DA595),
        pattern: CardPattern.waves),
    CardDesign('sand', 'Sand', 'Textured beige', Color(0xFFD9C6A8), Color(0xFF2A2118), Color(0xFF9C8667),
        pattern: CardPattern.dots),
    // Premium
    CardDesign('aurum', 'Aurum', 'Black with gold foil', Color(0xFF0E0D0B), Color(0xFFE9D9A6), Color(0xFFD4AF37),
        gradient: [Color(0xFF15130F), Color(0xFF0A0907)], pattern: CardPattern.lines, premium: true),
    CardDesign('carbon', 'Carbon', 'Carbon fibre weave', Color(0xFF141518), Color(0xFFF2F2F2), Color(0xFFFF5C7A),
        pattern: CardPattern.carbon, premium: true),
    CardDesign('marble', 'Marble', 'White marble', Color(0xFFF4F3F1), Color(0xFF1C1C1C), Color(0xFFB08D57),
        pattern: CardPattern.marble, premium: true),
    CardDesign('rosegold', 'Rose Gold', 'Brushed rose metal', Color(0xFFD9A3A0), Color(0xFF2B1416), Color(0xFF2B1416),
        gradient: [Color(0xFFB76E79), Color(0xFFE8B4B8), Color(0xFFC98C8F)], premium: true),
    CardDesign('ultraviolet', 'Ultraviolet', 'Violet gradient', Color(0xFF5B4BDB), Color(0xFFFFFFFF), Color(0xFFC8FF4D),
        gradient: [Color(0xFF3A2DB8), Color(0xFF8B7CFF)], pattern: CardPattern.waves, premium: true),
    CardDesign('holo', 'Holo', 'Iridescent foil', Color(0xFFD9ECFF), Color(0xFF0B0D1A), Color(0xFF5B4BDB),
        gradient: [Color(0xFFB8F3FF), Color(0xFFE6C8FF), Color(0xFFFFE9B0), Color(0xFFC8FFE0)], premium: true),
    CardDesign('oceanic', 'Oceanic', 'Deep teal gradient', Color(0xFF0B4F5C), Color(0xFFEFFBFB), Color(0xFF7FF5E0),
        gradient: [Color(0xFF062E3A), Color(0xFF0E6E7A)], pattern: CardPattern.waves, premium: true),
    CardDesign('sunset', 'Sunset', 'Warm gradient', Color(0xFFFF7A59), Color(0xFFFFFFFF), Color(0xFFFFE9B0),
        gradient: [Color(0xFFFF5F6D), Color(0xFFFFC371)], premium: true),
    CardDesign('neon', 'Neon Grid', 'Black with lime grid', Color(0xFF07080F), Color(0xFFF4F5FA), Color(0xFFC8FF4D),
        pattern: CardPattern.grid, premium: true),
    CardDesign('steel', 'Steel', 'Brushed metal look', Color(0xFFA7ACB1), Color(0xFF15171A), Color(0xFF6C7177),
        gradient: [Color(0xFF8E949A), Color(0xFFD3D7DB), Color(0xFF9DA3A9)], pattern: CardPattern.lines, premium: true),
  ];

  static CardDesign byId(String id) => all.firstWhere((d) => d.id == id, orElse: () => all.first);
}

String formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String formatRupees(int v) {
  final s = v.toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}

class AppNotification {
  final String id;
  final String kind;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        kind: (m['kind'] ?? 'info') as String,
        title: (m['title'] ?? '') as String,
        body: (m['body'] ?? '') as String,
        read: (m['read'] ?? false) as bool,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

/// Someone who shared their contact from your public profile.
class Lead {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String note;
  final DateTime createdAt;

  Lead({required this.id, required this.name, required this.phone, required this.email, required this.note, required this.createdAt});

  factory Lead.fromMap(Map<String, dynamic> m) => Lead(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        email: (m['email'] ?? '') as String,
        note: (m['note'] ?? '') as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

/// "2 min ago", "3 h ago", "Yesterday", or a date.
String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  if (diff.inDays == 1) return '1 d';
  if (diff.inDays < 7) return '${diff.inDays} d';
  return formatDate(d);
}
