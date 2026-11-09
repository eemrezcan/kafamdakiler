import 'package:dio/dio.dart';

import '../core/hata_metni.dart';

/// The words for a failed write on a card. The server's refusals carry a sentence for the person in the ProblemDetails `detail`
/// ("Karar aşamasından çıkmadan önce bütün soruları cevapla."); that is shown as it is. Without one (no answer, an error page)
/// the usual text of [hataMetni] says what to do next.
String isHataMetni(Object hata) {
  if (hata is DioException && hata.response?.data is Map) {
    final veri = hata.response!.data as Map;
    final ayrinti = veri['detail'];
    if (ayrinti is String && ayrinti.trim().isNotEmpty) return ayrinti.trim();
  }
  if (hata is DioException && hata.response == null) {
    return 'Çevrimdışısın: işlem gönderilemedi. Bağlantın gelince tekrar dene.';
  }
  return hataMetni(hata, islem: 'İşlem yapılamadı');
}
