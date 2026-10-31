/// Habit day rules (K-0014 + the 05:00 addendum in the plan).
///
/// Europe/Istanbul is a fixed UTC+3 (no daylight saving), and the habit day
/// starts at 05:00 local time. So a day boundary is 02:00 UTC.
const istanbulFarki = Duration(hours: 3);
const gunDonumu = Duration(hours: 5);

/// The habit day (date-only, UTC midnight) that [an] belongs to:
/// 04:59 Istanbul time is still yesterday, 05:00 is today.
DateTime aliskanlikGunu(DateTime an) {
  final kaydirilmis = an.toUtc().add(istanbulFarki).subtract(gunDonumu);
  return DateTime.utc(kaydirilmis.year, kaydirilmis.month, kaydirilmis.day);
}

/// "2026-10-31" for a date-only value.
String tarihMetni(DateTime tarih) {
  String iki(int n) => n.toString().padLeft(2, '0');
  return '${tarih.year.toString().padLeft(4, '0')}-${iki(tarih.month)}-${iki(tarih.day)}';
}

/// Parses "2026-10-31" into a date-only UTC [DateTime].
DateTime tarihCoz(String metin) {
  final parcalar = metin.split('-');
  return DateTime.utc(
    int.parse(parcalar[0]),
    int.parse(parcalar[1]),
    int.parse(parcalar[2]),
  );
}
