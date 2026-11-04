import 'dart:io';

/// Gerçek kanal listesi: depoda değildir (geliştiricinin bilgisayarında,
/// `~/.redox/kaynak/tr.m3u`). Yoksa bu dosyayı kullanan testler atlanır.
File get realChannelList {
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
  return File('$home/.redox/kaynak/tr.m3u');
}

/// Liste yoksa testin atlanması için.
bool get noRealChannelList => !realChannelList.existsSync();
