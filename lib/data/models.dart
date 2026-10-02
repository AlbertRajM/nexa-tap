import 'package:flutter/material.dart';

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
  String get label => this == CardType.business ? 'Business' : 'Personal';
  IconData get icon => this == CardType.business ? Icons.work_outline_rounded : Icons.person_outline_rounded;
  String get blurb => this == CardType.business
      ? 'Company, role, work contacts and office address'
      : 'Personal contacts, bio and social profiles';
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
        'placed' => 'Order placed',
        'confirmed' => 'Confirmed',
        'printing' => 'Printing & encoding',
        'quality_check' => 'Quality check',
        'shipped' => 'Shipped',
        'delivered' => 'Delivered',
        'cancelled' => 'Cancelled',
        _ => s,
      };

  static String detail(String s) => switch (s) {
        'placed' => 'We have received your order.',
        'confirmed' => 'Our team has confirmed the details and payment.',
        'printing' => 'Your card is being printed and the NFC chip programmed.',
        'quality_check' => 'Every card is tap-tested before it leaves.',
        'shipped' => 'Your card is on the way.',
        'delivered' => 'Delivered. Tap it on any phone to share your profile.',
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

/// Physical card finishes. Solid colours only — they mimic real card stock.
class CardDesign {
  final String id;
  final String name;
  final String finish;
  final Color bg;
  final Color fg;
  final Color line;
  const CardDesign(this.id, this.name, this.finish, this.bg, this.fg, this.line);

  static const all = <CardDesign>[
    CardDesign('graphite', 'Graphite', 'Matte black PVC', Color(0xFF1B1C1F), Color(0xFFF3F3F3), Color(0xFF6E737B)),
    CardDesign('ivory', 'Ivory', 'Soft-touch white', Color(0xFFF2EEE6), Color(0xFF1A1A1A), Color(0xFFB9B2A4)),
    CardDesign('navy', 'Navy', 'Matte navy PVC', Color(0xFF142139), Color(0xFFF1F2F4), Color(0xFFB59A5A)),
    CardDesign('forest', 'Forest', 'Matte green PVC', Color(0xFF1E3A2E), Color(0xFFEDEDE6), Color(0xFF8DA595)),
    CardDesign('sand', 'Sand', 'Textured beige', Color(0xFFD9C6A8), Color(0xFF2A2118), Color(0xFF9C8667)),
    CardDesign('steel', 'Steel', 'Brushed metal look', Color(0xFFA7ACB1), Color(0xFF15171A), Color(0xFF6C7177)),
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
