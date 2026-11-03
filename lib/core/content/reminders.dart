import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'epg_program.dart';
import 'live_channel.dart';

/// Yayın akışındaki bir programın hatırlatıcısı: kanal, program adı ve
/// başlangıç anı.
@immutable
class Reminder {
  const Reminder({required this.channel, required this.channelName, required this.title, required this.start});

  /// Kanalın sonraki programı ("22:30 Maç Özetleri"); saat okunamazsa null.
  /// Saat şimdiden önceyse ertesi gündür (gece yarısını geçen akış).
  static Reminder? nextOf(LiveChannel c, DateTime now) {
    final next = c.next;
    final minute = next == null ? null : EpgProgram.parseClock(next);
    if (next == null || minute == null) return null;
    var start = DateTime(now.year, now.month, now.day, minute ~/ 60, minute % 60);
    if (start.isBefore(now.subtract(const Duration(minutes: 1)))) start = start.add(const Duration(days: 1));
    final title = next.replaceFirst(RegExp(r'^\s*\d{1,2}:\d{2}\s*'), '').trim();
    return Reminder(channel: c.number, channelName: c.name, title: title.isEmpty ? next : title, start: start);
  }

  static Reminder? fromJson(Object? j) => switch (j) {
    {'kanal': final int channel, 'ad': final String name, 'program': final String title, 'baslangic': final int at} =>
      Reminder(channel: channel, channelName: name, title: title, start: DateTime.fromMillisecondsSinceEpoch(at)),
    _ => null,
  };

  /// Kanal numarası (TV kanalları).
  final int channel;
  final String channelName;
  final String title;
  final DateTime start;

  Map<String, Object?> toJson() => {
    'kanal': channel,
    'ad': channelName,
    'program': title,
    'baslangic': start.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) => other is Reminder && other.channel == channel && other.start == start;

  @override
  int get hashCode => Object.hash(channel, start);
}

/// Program hatırlatıcıları (cihazda saklanır). Vakti gelen hatırlatıcıyı
/// kabuk [takeDue] ile alır ve gösterir; geçmişte kalanlar silinir.
class Reminders extends ChangeNotifier {
  Reminders({List<Reminder> items = const [], this.onSave}) : _items = List.of(items);

  /// Uygulamanın hatırlatıcıları (main'de cihazdan yüklenir; testlerde boş).
  static Reminders instance = Reminders();

  final List<Reminder> _items;
  final Future<void> Function(List<Reminder>)? onSave;

  static const _key = 'hatirlatici';

  /// Program başlamadan bu kadar önce hatırlatılır.
  static const lead = Duration(minutes: 1);

  static Future<Reminders> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key) ?? const <String>[];
    return Reminders(
      items: [for (final s in saved) ?_decode(s)],
      onSave: (items) => prefs.setStringList(_key, [for (final r in items) jsonEncode(r.toJson())]),
    );
  }

  static Reminder? _decode(String s) {
    try {
      return Reminder.fromJson(jsonDecode(s));
    } on FormatException {
      return null;
    }
  }

  List<Reminder> get items => List.unmodifiable(_items);

  bool has(Reminder r) => _items.contains(r);

  /// Ekler ya da kaldırır; eklendiyse true.
  bool toggle(Reminder r) {
    final added = !_items.remove(r);
    if (added) _items.add(r);
    _changed();
    return added;
  }

  /// Vakti gelenleri ([lead] önce) listeden çıkarıp verir; başlamasının
  /// üstünden 10 dk geçmiş olanlar (uygulama kapalıyken kaçanlar) sessizce
  /// silinir.
  List<Reminder> takeDue(DateTime now) {
    final due = [
      for (final r in _items)
        if (!r.start.subtract(lead).isAfter(now) && now.difference(r.start) < const Duration(minutes: 10)) r,
    ];
    final before = _items.length;
    _items.removeWhere((r) => !r.start.subtract(lead).isAfter(now));
    if (_items.length != before) _changed();
    return due;
  }

  void _changed() {
    notifyListeners();
    unawaited(onSave?.call(_items));
  }
}
