import 'package:dio/dio.dart';

/// A Turkish message for a failed API call that says what to do next.
String hataMetni(Object hata, {String islem = 'İşlem tamamlanamadı'}) {
  if (hata is! DioException) return '$islem. Biraz sonra tekrar dene.';
  final kod = hata.response?.statusCode;
  if (kod == null) {
    return 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol edip tekrar dene.';
  }
  switch (kod) {
    case 400:
      final alanlar = _dogrulamaMesajlari(hata.response?.data);
      return alanlar.isEmpty ? '$islem: gönderilen bilgiler geçersiz.' : alanlar.join('\n');
    case 401:
      return 'Oturumun sona erdi. Yeniden giriş yap.';
    case 403:
      return 'Bu işlem için yetkin yok.';
    case 404:
      return 'Kayıt bulunamadı; silinmiş olabilir. Listeyi yenile.';
    case 409:
      return 'İşlem mevcut kayıtlarla çakışıyor (örneğin yalnız son oturum değiştirilebilir). Ekranı yenileyip tekrar dene.';
    default:
      return 'Sunucu hata verdi ($kod). Biraz sonra tekrar dene.';
  }
}

/// For a password change. It cannot wait in the offline queue (the new password must be known to the server before
/// anything else), so without a connection the text says nothing was sent.
String sifreHataMetni(Object hata) => cevrimdisiHata(hata)
    ? 'Çevrimdışısın: şifre gönderilmedi. Bağlantın gelince tekrar dene.'
    : hataMetni(hata, islem: 'Şifre değiştirilemedi');

/// `ValidationProblem`:`{ "errors": { "alan": ["mesaj"] } }`.
List<String> _dogrulamaMesajlari(Object? veri) {
  if (veri is! Map || veri['errors'] is! Map) return const [];
  return [
    for (final mesajlar in (veri['errors'] as Map).values)
      if (mesajlar is List) ...mesajlar.map((m) => m.toString()),
  ];
}

/// True when no server answer arrived (offline, timeout).
bool cevrimdisiHata(Object hata) => hata is DioException && hata.response == null;
