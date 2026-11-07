// The write side of the second brain (`/api/beyin`, backend/Beyin/BeyinYazma.cs): what a send answers.

/// How the server answered a plan or task write that was accepted.
enum BeyinYazmaDurumu {
  /// 200: written.
  tamam,

  /// 207: a split over days stopped half way; the answer says which days were written.
  kismi,

  /// 202: the brain did not answer clearly after the command may have written. Never sent again by itself.
  belirsiz,
}

class BeyinYazmaSonucu {
  const BeyinYazmaSonucu({required this.durum, this.govde = const {}});

  factory BeyinYazmaSonucu.durumKodundan(int? kod, Object? govde) {
    final harita = govde is Map<String, dynamic> ? govde : const <String, dynamic>{};
    return BeyinYazmaSonucu(
      durum: switch (kod) {
        202 => BeyinYazmaDurumu.belirsiz,
        207 => BeyinYazmaDurumu.kismi,
        _ => BeyinYazmaDurumu.tamam,
      },
      govde: harita,
    );
  }

  final BeyinYazmaDurumu durum;
  final Map<String, dynamic> govde;

  /// What the user should read about this write, or null when it is simply done.
  /// The texts are the server's own (`ayrinti`, the days written and the day that stopped a split).
  String? get uyari {
    switch (durum) {
      case BeyinYazmaDurumu.tamam:
        return null;
      case BeyinYazmaDurumu.belirsiz:
        return (govde['ayrinti'] as String?) ?? 'Sonuç belli değil; yazılmış olabilir. Günün planına bak.';
      case BeyinYazmaDurumu.kismi:
        final yazilan = ((govde['yazilanlar'] as List?) ?? const []).whereType<Map<String, dynamic>>().map((g) => g['tarih']).join(', ');
        final hata = govde['hata'] as Map<String, dynamic>?;
        final nedeni = hata == null ? '' : ' ${hata['tarih']} günü yazılamadı: ${hata['ayrinti'] ?? hata['baslik'] ?? ''}'
            '${hata['yazilmisOlabilir'] == true ? ' (yazılmış olabilir, planı kontrol et)' : ''}';
        return 'Günlere bölme yarıda kaldı. Yazılan günler: ${yazilan.isEmpty ? '-' : yazilan}.$nedeni';
    }
  }
}
