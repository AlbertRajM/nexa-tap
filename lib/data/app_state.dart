import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'repo.dart';

/// Holds the signed-in user's data and notifies screens when it changes.
class AppState extends ChangeNotifier {
  AppState._();
  static final instance = AppState._();

  final _repo = Repo.instance;

  Profile? profile;
  List<CardProfile> cards = [];
  List<Order> orders = [];
  List<AppNotification> notifications = [];
  List<Lead> leads = [];
  Map<String, dynamic> stats = {};
  bool loading = true;
  StreamSubscription<List<AppNotification>>? _notifSub;

  int get unread => notifications.where((n) => !n.read).length;
  String? error;

  CardProfile? card(CardType t) {
    for (final c in cards) {
      if (c.type == t) return c;
    }
    return null;
  }

  /// The card shown by default when someone taps.
  CardProfile? get primaryCard {
    final def = profile == null ? CardType.business : CardTypeX.parse(profile!.defaultCard);
    final c = card(def);
    if (c != null && c.enabled) return c;
    for (final x in cards) {
      if (x.enabled) return x;
    }
    return c ?? (cards.isEmpty ? null : cards.first);
  }

  String get link => profile == null ? '' : _repo.link(profile!);

  Future<void> load() async {
    error = null;
    try {
      final results = await Future.wait([_repo.profile(), _repo.cards(), _repo.orders()]);
      profile = results[0] as Profile;
      cards = results[1] as List<CardProfile>;
      orders = results[2] as List<Order>;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
    if (error == null) _loadExtras();
  }

  /// Notifications, connections and stats load after the main screen is visible.
  /// They fail quietly if the database update has not been run yet.
  Future<void> _loadExtras() async {
    _notifSub?.cancel();
    try {
      _notifSub = _repo.notificationStream().listen((list) {
        notifications = list;
        notifyListeners();
      }, onError: (_) {});
    } catch (_) {}
    await Future.wait([refreshLeads(), refreshStats()]);
  }

  Future<void> refreshLeads() async {
    try {
      leads = await _repo.leads();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshStats() async {
    try {
      stats = await _repo.viewStats();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    notifications = [
      for (final n in notifications)
        AppNotification(id: n.id, kind: n.kind, title: n.title, body: n.body, read: true, createdAt: n.createdAt)
    ];
    notifyListeners();
    try {
      await _repo.markAllRead();
    } catch (_) {}
  }

  Future<void> deleteNotification(String id) async {
    notifications = notifications.where((n) => n.id != id).toList();
    notifyListeners();
    try {
      await _repo.deleteNotification(id);
    } catch (_) {}
  }

  Future<void> deleteLead(String id) async {
    leads = leads.where((l) => l.id != id).toList();
    notifyListeners();
    await _repo.deleteLead(id);
  }

  Future<void> refreshOrders() async {
    orders = await _repo.orders();
    notifyListeners();
  }

  Future<void> saveCard(CardProfile c) async {
    await _repo.saveCard(c);
    cards = [for (final x in cards) x.id == c.id ? c : x];
    notifyListeners();
  }

  Future<void> setEnabled(CardProfile c, bool v) async {
    // Update the screen first so the switch feels instant, then save.
    cards = [for (final x in cards) x.id == c.id ? x.copyWith(enabled: v) : x];
    notifyListeners();
    try {
      await _repo.setCardEnabled(c, v);
    } catch (e) {
      cards = [for (final x in cards) x.id == c.id ? x.copyWith(enabled: !v) : x];
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setDefault(CardType t) async {
    await _repo.updateProfile({'default_card': t.name});
    await _reloadProfile();
  }

  Future<void> setActive(bool v) async {
    await _repo.updateProfile({'active': v});
    await _reloadProfile();
  }

  Future<void> rename(String name) async {
    await _repo.updateProfile({'full_name': name});
    await _reloadProfile();
  }

  Future<void> _reloadProfile() async {
    profile = await _repo.profile();
    notifyListeners();
  }

  void addOrder(Order o) {
    orders = [o, ...orders];
    notifyListeners();
  }

  void clear() {
    _notifSub?.cancel();
    _notifSub = null;
    notifications = [];
    leads = [];
    stats = {};
    profile = null;
    cards = [];
    orders = [];
    loading = true;
    error = null;
    notifyListeners();
  }
}
