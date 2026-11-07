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

/// Reminder: how many days before the heads-up comes (0 means none).
String? onceGunDogrula(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return null;
  final n = int.tryParse(t);
  if (n == null || n < 0 || n > 60) return 'Kaç gün önce uyarılacağı 0 ile 60 arasında olmalı.';
  return null;
}

String? mevcutSifreDogrula(String? v) => (v ?? '').isEmpty ? 'Mevcut şifre gerekli.' : null;

/// Identity's default password rules, in the order the user fixes them (never trimmed: spaces count).
String? yeniSifreDogrula(String? v) {
  final s = v ?? '';
  if (s.isEmpty) return 'Yeni şifre gerekli.';
  if (s.length < 6) return 'Şifre en az 6 karakter olmalı.';
  if (!RegExp(r'[0-9]').hasMatch(s)) return 'Şifre en az bir rakam içermeli (0-9).';
  if (!RegExp(r'\p{Ll}', unicode: true).hasMatch(s)) return 'Şifre en az bir küçük harf içermeli (a-z).';
  if (!RegExp(r'\p{Lu}', unicode: true).hasMatch(s)) return 'Şifre en az bir büyük harf içermeli (A-Z).';
  if (!RegExp(r'[^\p{L}\p{Nd}]', unicode: true).hasMatch(s)) {
    return 'Şifre en az bir harf ve rakam olmayan karakter içermeli (örneğin !).';
  }
  return null;
}

String? sifreTekrarDogrula(String? v, String yeni) {
  if ((v ?? '').isEmpty) return 'Şifreyi tekrar yaz.';
  return v == yeni ? null : 'Şifreler aynı değil.';
}

String? kimeDogrula(String? v) => (v?.trim().length ?? 0) > 100 ? 'Kime en çok 100 karakter olabilir.' : null;
