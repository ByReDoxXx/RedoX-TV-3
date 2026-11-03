import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/reminders.dart';

LiveChannel _channel(String? next) => LiveChannel(name: 'ULUSAL 1 HD', number: 1, category: 'Ulusal', next: next);

void main() {
  final now = DateTime(2026, 11, 3, 21, 10);

  test('sonraki programdan hatırlatıcı: saat ve ad ayrılır; geçmiş saat ertesi gün', () {
    final r = Reminder.nextOf(_channel('22:30 Gece Haberleri'), now)!;
    expect(r.title, 'Gece Haberleri');
    expect(r.start, DateTime(2026, 11, 3, 22, 30));
    expect(r.channel, 1);

    final late = Reminder.nextOf(_channel('00:15 Gece Sineması'), DateTime(2026, 11, 3, 23, 50))!;
    expect(late.start, DateTime(2026, 11, 4, 0, 15));

    expect(Reminder.nextOf(_channel(null), now), isNull);
    expect(Reminder.nextOf(_channel('Yakında'), now), isNull);
  });

  test('ekle/kaldır; vakti gelen bir dakika önce alınır, kaçırılan sessizce silinir', () {
    final saved = <List<Reminder>>[];
    final reminders = Reminders(onSave: (items) async => saved.add(List.of(items)));
    final r = Reminder.nextOf(_channel('22:30 Gece Haberleri'), now)!;
    expect(reminders.toggle(r), isTrue);
    expect(reminders.has(r), isTrue);
    expect(reminders.toggle(r), isFalse);
    expect(reminders.items, isEmpty);
    reminders.toggle(r);

    expect(reminders.takeDue(DateTime(2026, 11, 3, 22, 28)), isEmpty);
    expect(reminders.takeDue(DateTime(2026, 11, 3, 22, 29)), [r]);
    expect(reminders.items, isEmpty);
    expect(saved.last, isEmpty);

    reminders.toggle(r);
    expect(reminders.takeDue(DateTime(2026, 11, 3, 23, 0)), isEmpty);
    expect(reminders.items, isEmpty);
  });

  test('JSON gidiş-dönüş', () {
    final r = Reminder.nextOf(_channel('22:30 Gece Haberleri'), now)!;
    final back = Reminder.fromJson(r.toJson())!;
    expect(back, r);
    expect(back.title, r.title);
    expect(back.channelName, 'ULUSAL 1 HD');
    expect(Reminder.fromJson({'kanal': 'x'}), isNull);
  });
}
