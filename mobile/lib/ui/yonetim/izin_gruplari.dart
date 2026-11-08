/// What a group of the Asistan's permissions allows as a whole.
enum IzinSeviyesi {
  kapali('Kapalı'),
  okur('Okur'),
  // "Yazar" includes reading (the screen says so); the short word keeps the three choices the same size on a phone.
  okurYazar('Yazar'),

  /// Set by hand to a mix of the above: never chosen from the screen, only shown.
  ozel('Özel');

  const IzinSeviyesi(this.ad);

  final String ad;
}

/// One card of the management screen: the permissions behind "Okur" and the ones added by "Yazar".
/// The same table is defined in the web panel (backend/Yonetim/IzinGruplari.cs): change both together.
class IzinGrubu {
  const IzinGrubu({required this.id, required this.ad, required this.aciklama, required this.okur, required this.yazar});

  final String id;
  final String ad;
  final String aciklama;
  final List<String> okur;
  final List<String> yazar;

  List<String> get tumu => [...okur, ...yazar];

  /// The level the open permissions [acik] amount to.
  IzinSeviyesi seviye(Set<String> acik) {
    final okurAcik = okur.every(acik.contains);
    final yazarAcik = yazar.every(acik.contains);
    final herhangiYazar = yazar.any(acik.contains);
    if (!okur.any(acik.contains) && !herhangiYazar) return IzinSeviyesi.kapali;
    if (okurAcik && !herhangiYazar) return IzinSeviyesi.okur;
    if (okurAcik && yazarAcik) return IzinSeviyesi.okurYazar;
    return IzinSeviyesi.ozel;
  }

  /// Which permission must be open (true) or closed (false) for [seviye].
  Map<String, bool> hedef(IzinSeviyesi seviye) => {
        for (final i in okur) i: seviye == IzinSeviyesi.okur || seviye == IzinSeviyesi.okurYazar,
        for (final i in yazar) i: seviye == IzinSeviyesi.okurYazar,
      };
}

/// The permission behind the "Asistan can call Claude" switch; it is in no group.
const asistanKullanIzni = 'asistan.kullan';

const izinGruplari = [
  IzinGrubu(
    id: 'aliskanlik',
    ad: 'Alışkanlıklar',
    aciklama: 'Alışkanlıkları ve kayıtlarını görür; yazarsa ekler, değiştirir, siler.',
    okur: ['aliskanlik.oku'],
    yazar: ['aliskanlik.yaz'],
  ),
  IzinGrubu(
    id: 'hatirlatici',
    ad: 'Hatırlatıcılar',
    aciklama: 'Hatırlatıcıları görür; yazarsa ekler, değiştirir, yaptım ve ertele işaretler.',
    okur: ['hatirlatici.oku'],
    yazar: ['hatirlatici.yaz'],
  ),
  IzinGrubu(
    id: 'gelen',
    ad: 'Gelen ve yakalamalar',
    aciklama: 'Yakalamaları ve gelen kartlarını görür; yazarsa ekler, yeniden öneri ister, kartı yerleştirir.',
    okur: ['yakalama.oku', 'gelen.oku'],
    yazar: ['yakalama.yaz', 'gelen.yaz'],
  ),
  IzinGrubu(
    id: 'beyin',
    ad: 'Beyin ve plan',
    aciklama: 'Projeleri, gün planını ve notları görür; yazarsa plana ve görevlere ekler, işaretler.',
    okur: ['beyin.oku'],
    yazar: ['plan.yaz', 'gorev.yaz'],
  ),
  IzinGrubu(
    id: 'takvim',
    ad: 'Takvim ve brifing',
    aciklama: 'Zaman çizelgesini ve sabah brifingini görür; yazarsa takvime etkinlik ekler (onaydan geçerek).',
    okur: ['takvim.oku', 'brifing.oku'],
    yazar: ['takvim.yaz'],
  ),
  IzinGrubu(
    id: 'eylem',
    ad: 'Onay kuyruğu',
    aciklama: 'Bekleyen önerileri görür; yazarsa onaylar, reddeder, geri alır.',
    okur: ['eylem.oku'],
    yazar: ['eylem.onayla'],
  ),
];
