import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import 'models.dart';

/// Every call to the backend lives here, so screens stay simple.
class Repo {
  Repo._();
  static final instance = Repo._();

  SupabaseClient get _db => Supabase.instance.client;
  String get uid => _db.auth.currentUser!.id;
  User? get user => _db.auth.currentUser;

  // ---------- Auth ----------
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String? referral,
  }) async {
    await _db.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': name.trim(),
        if (referral != null && referral.trim().isNotEmpty) 'referred_by': referral.trim().toUpperCase(),
      },
    );
  }

  Future<void> signIn(String email, String password) =>
      _db.auth.signInWithPassword(email: email.trim(), password: password);

  Future<void> resetPassword(String email) => _db.auth.resetPasswordForEmail(email.trim());

  Future<void> signOut() => _db.auth.signOut();

  // ---------- Profile ----------
  Future<Profile> profile() async {
    // The profile row is created by a database trigger right after sign-up.
    // Retry briefly in case it is not there yet.
    for (var i = 0; i < 4; i++) {
      final row = await _db.from('profiles').select().eq('id', uid).maybeSingle();
      if (row != null) return Profile.fromMap(row);
      await Future.delayed(const Duration(milliseconds: 600));
    }
    throw Exception('Profile not found. Please run the database setup in Supabase.');
  }

  Future<void> updateProfile(Map<String, dynamic> values) =>
      _db.from('profiles').update(values).eq('id', uid);

  // ---------- Cards ----------
  Future<List<CardProfile>> cards() async {
    final rows = await _db.from('cards').select().eq('user_id', uid);
    final list = rows.map((r) => CardProfile.fromMap(r)).toList();
    list.sort((a, b) => a.type.index.compareTo(b.type.index));
    return list;
  }

  Future<void> saveCard(CardProfile c) => _db.from('cards').update({
        'data': c.data,
        'design': c.design,
        'enabled': c.enabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', c.id);

  Future<void> setCardEnabled(CardProfile c, bool enabled) =>
      _db.from('cards').update({'enabled': enabled}).eq('id', c.id);

  Future<String> uploadImage(Uint8List bytes, String kind) async {
    final path = '$uid/$kind.jpg';
    await _db.storage.from('media').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    final url = _db.storage.from('media').getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  // ---------- Orders ----------
  Future<List<Order>> orders() async {
    final rows = await _db.from('orders').select().eq('user_id', uid).order('created_at', ascending: false);
    return rows.map((r) => Order.fromMap(r)).toList();
  }

  Future<Order> placeOrder({
    required String cardType,
    required String design,
    required String nameOnCard,
    required int quantity,
    required String phone,
    required String address,
    required String city,
    required String pincode,
    required int amount,
  }) async {
    final row = await _db
        .from('orders')
        .insert({
          'user_id': uid,
          'card_type': cardType,
          'design': design,
          'name_on_card': nameOnCard,
          'quantity': quantity,
          'phone': phone,
          'address': address,
          'city': city,
          'pincode': pincode,
          'amount': amount,
        })
        .select()
        .single();
    return Order.fromMap(row);
  }

  // ---------- Referrals ----------
  Future<Map<String, dynamic>> referralStats() async {
    final res = await _db.rpc('referral_stats');
    if (res is Map) return Map<String, dynamic>.from(res);
    return {'joined': 0, 'ordered': 0, 'list': []};
  }

  String link(Profile p, {CardType? type}) => AppConfig.profileLink(p.username, type: type?.name);
}
