import 'package:dio/dio.dart';

import '../core/hata_metni.dart';

/// The words for a failed write on a card. The server's refusals carry a sentence for the person in the ProblemDetails `detail`
/// ("Karar aşamasından çıkmadan önce bütün soruları cevapla."); that is shown as it is. Without one (no answer, an error page)
/// the usual text of [hataMetni] says what to do next.
///
/// A refusal of a field (`errors`: `{ "not-gerekli": ["Revizyon için kısa bir not yaz."] }`, as the revision without a note is
/// answered) is shown by its sentences: the key names the rule, the sentence is for the person.
String isHataMetni(Object hata) {
  if (hata is DioException && hata.response?.data is Map) {
    final veri = hata.response!.data as Map;
    final ayrinti = veri['detail'];
    if (ayrinti is String && ayrinti.trim().isNotEmpty) return ayrinti.trim();
    final alanlar = veri['errors'];
    if (alanlar is Map) {
      final cumleler = [
        for (final m in alanlar.values)
          if (m is List) ...m.map((x) => x.toString().trim()).where((x) => x.isNotEmpty) else if (m is String && m.trim().isNotEmpty) m.trim(),
      ];
      if (cumleler.isNotEmpty) return cumleler.join(' ');
    }
  }
  if (hata is DioException && hata.response == null) {
    return 'Çevrimdışısın: işlem gönderilemedi. Bağlantın gelince tekrar dene.';
  }
  return hataMetni(hata, islem: 'İşlem yapılamadı');
}
