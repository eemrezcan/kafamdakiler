import '../data/models/is_karti.dart';

// Words and grouping for the work cards: pure functions, shared by the Bugün card, the board and the detail.

/// The three gates. A card at one of them waits for the person's approval.
const isKapilari = ['kod-onayi', 'push-onayi', 'deploy-onayi'];

/// Push and deploy are approved on the screen only, after the plan and the history have been seen: no notification button.
const isEkrandanOnaylananKapilar = ['push-onayi', 'deploy-onayi'];

String asamaEtiketi(String asama) => switch (asama) {
      'talep' => 'Talep',
      'plan' => 'Plan',
      'karar' => 'Karar',
      'kod-onayi' => 'Kod onayı',
      'yapim' => 'Yapım',
      'push-onayi' => 'Push onayı',
      'deploy-onayi' => 'Deploy onayı',
      'bitti' => 'Bitti',
      'iptal' => 'İptal',
      _ => asama,
    };

String sahipEtiketi(String sahip) => switch (sahip) {
      'kullanici' => 'Sende',
      'vps' => "VPS'te",
      'laptop' => "Laptop'ta",
      _ => sahip,
    };

/// The stage a gate leads to when approved; null for any other stage.
String? kapidanSonraki(String asama) => switch (asama) {
      'kod-onayi' => 'yapim',
      'push-onayi' => 'deploy-onayi',
      'deploy-onayi' => 'bitti',
      _ => null,
    };

/// What the approve button says at a gate.
String onayEtiketi(String asama) => switch (asama) {
      'kod-onayi' => 'Kodu onayla',
      'push-onayi' => "Push'u onayla",
      'deploy-onayi' => "Deploy'u onayla",
      _ => 'Onayla',
    };

/// The board in the groups the screen shows. An open card is in exactly one: a gate first (it waits for an approval whoever
/// holds it), then the build, then by who holds it. A finished card is in [biten] (cancelled cards are not on the board).
class IsPanosu {
  const IsPanosu({
    this.sende = const [],
    this.vps = const [],
    this.laptop = const [],
    this.yapim = const [],
    this.kapilar = const [],
    this.biten = const [],
  });

  /// Held by the person: a decision to take, or anything else that waits on them.
  final List<IsKarti> sende;
  final List<IsKarti> vps;
  final List<IsKarti> laptop;
  final List<IsKarti> yapim;
  final List<IsKarti> kapilar;
  final List<IsKarti> biten;

  factory IsPanosu.grupla(List<IsKarti> kartlar) {
    final sende = <IsKarti>[], vps = <IsKarti>[], laptop = <IsKarti>[], yapim = <IsKarti>[], kapilar = <IsKarti>[], biten = <IsKarti>[];
    for (final k in kartlar) {
      if (!k.acik) {
        if (k.asama == 'bitti') biten.add(k);
      } else if (isKapilari.contains(k.asama)) {
        kapilar.add(k);
      } else if (k.asama == 'yapim') {
        yapim.add(k);
      } else if (k.sahip == 'kullanici') {
        sende.add(k);
      } else if (k.sahip == 'laptop') {
        laptop.add(k);
      } else {
        vps.add(k);
      }
    }
    return IsPanosu(sende: sende, vps: vps, laptop: laptop, yapim: yapim, kapilar: kapilar, biten: biten);
  }

  /// Waiting on the person: the cards they hold and the gates.
  List<IsKarti> get sendeBekleyen => [...kapilar, ...sende];

  /// Being worked on by the VPS: what it holds, and a build it holds.
  int get vpstekiSayi => vps.length + yapim.where((k) => k.sahip == 'vps').length;

  bool get bos => sende.isEmpty && vps.isEmpty && laptop.isEmpty && yapim.isEmpty && kapilar.isEmpty && biten.isEmpty;
}

/// The card to open for a stage: whether the person may press "Onayla" there and where it leads.
bool kapidaMi(IsKarti k) => k.acik && isKapilari.contains(k.asama);
