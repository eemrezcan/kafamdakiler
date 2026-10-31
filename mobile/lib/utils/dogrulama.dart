import 'package:intl/intl.dart';

import '../data/models/enums.dart';

// Form validators. They repeat the API rules (docs/planlar/aliskanlik-takibi.md)
// so the user sees the message before a request is made (M05); the server
// still validates and its messages are shown when it disagrees.

/// Parses "12", "12,5" or "12.5"; null when empty or not a number.
double? sayiCoz(String? metin) {
  final t = metin?.trim().replaceAll(',', '.') ?? '';
  return t.isEmpty ? null : double.tryParse(t);
}

/// "35" for whole numbers, "12,5" otherwise (Turkish decimal comma).
String sayiMetni(double? sayi) {
  if (sayi == null) return '';
  if (sayi == sayi.roundToDouble()) return sayi.round().toString();
  return NumberFormat('0.##', 'tr').format(sayi);
}

String? zorunluMetin(String? v, String alan, {int max = 200}) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return '$alan gerekli.';
  if (t.length > max) return '$alan en çok $max karakter olabilir.';
  return null;
}

/// Daily target: required for counters; EnAz needs > 0, EnCok needs >= 0.
String? hedefDogrula(String? v, HedefYonu yon) {
  final s = sayiCoz(v);
  if (s == null) return 'Günlük hedef gerekli (sayı yaz).';
  if (yon == HedefYonu.enAz && s <= 0) return 'Hedef 0\'dan büyük olmalı.';
  if (yon == HedefYonu.enCok && s < 0) return 'Hedef 0 ya da daha büyük olmalı.';
  return null;
}

String? haftalikSayiDogrula(String? v) {
  final s = int.tryParse(v?.trim() ?? '');
  if (s == null || s < 1 || s > 6) return 'Haftada kaç gün: 1 ile 6 arasında bir sayı yaz.';
  return null;
}

/// "Nereye kadar geldin?": a number above the start position, and not above
/// the total when the item has one.
String? konumDogrula(String? v, {required double baslangic, double? toplam}) {
  final s = sayiCoz(v);
  if (s == null) return 'Nereye kadar geldiğini sayı olarak yaz.';
  if (s <= baslangic) return '${sayiMetni(baslangic)} değerinden büyük olmalı.';
  if (toplam != null && s > toplam) return 'Toplamdan (${sayiMetni(toplam)}) büyük olamaz.';
  return null;
}

/// Optional minutes: empty or a whole number >= 0.
String? dakikaDogrula(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return null;
  final d = int.tryParse(t);
  if (d == null || d < 0) return 'Dakika için 0 ya da daha büyük bir tam sayı yaz.';
  return null;
}

String? ogeBaslangicDogrula(String? v) {
  final s = sayiCoz(v);
  if (s == null) return 'Başlangıç konumu gerekli (0 olabilir).';
  if (s < 0) return 'Başlangıç konumu 0\'dan küçük olamaz.';
  return null;
}

/// Optional total; when given it must be above the start position.
String? ogeToplamDogrula(String? v, double baslangic) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return null;
  final s = sayiCoz(t);
  if (s == null) return 'Toplam için sayı yaz ya da boş bırak.';
  if (s <= baslangic) return 'Toplam, başlangıç konumundan büyük olmalı.';
  return null;
}

String? puanDogrula(int? puan) => puan != null && (puan < 1 || puan > 5) ? 'Puan 1 ile 5 arasında olmalı.' : null;

String? notDogrula(String? v) => (v?.length ?? 0) > 2000 ? 'Not en çok 2000 karakter olabilir.' : null;
