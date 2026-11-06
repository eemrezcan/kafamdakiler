import '../data/models/hatirlatici.dart';
import 'hatirlatici_hesap.dart';

// The write rules of reminders on the phone, a port of backend/Hatirlaticilar/HatirlaticiIslemleri.cs. They lay a
// queued write over the server's copy at once (optimistic update); the server then applies the same rule.

/// Builds the reminder a [HatirlaticiYaz] describes (editing keeps [mevcut]'s id and creation time). The next moment
/// is computed from the rule; editing the rule clears a snooze.
Hatirlatici hatirlaticiYazdan(HatirlaticiYaz yaz, DateTime simdi, {Hatirlatici? mevcut}) {
  String? bosYap(String? m) {
    final t = m?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  final saat = yaz.saat ?? varsayilanHatirlaticiSaati;
  return Hatirlatici(
    id: mevcut?.id ?? yaz.id!,
    baslik: yaz.baslik.trim(),
    not: bosYap(yaz.not),
    tur: yaz.tur,
    kime: yaz.tur == HatirlaticiTuru.soz ? bosYap(yaz.kime) : null,
    gun: yaz.gun,
    saat: yaz.saat,
    tekrar: yaz.tekrar,
    onceGun: yaz.onceGun,
    durum: yaz.durum,
    sonrakiAn: sonrakiHatirlaticiAni(yaz.tekrar, yaz.gun, saat, simdi),
    createdAt: mevcut?.createdAt ?? simdi,
  );
}

/// Done: a repeating reminder moves to its next turn (after the current one, even if marked early), a one-off is
/// closed. A reminder that is not open stays as it is (the server would refuse).
Hatirlatici hatirlaticiYaptim(Hatirlatici h, DateTime simdi) {
  if (h.durum != HatirlaticiDurumu.acik) return h;
  if (h.tekrar == Tekrar.yok) {
    return h.copyWith(durum: HatirlaticiDurumu.tamam, erteleAnTemizle: true);
  }
  final sonra = simdi.isAfter(h.sonrakiAn) ? simdi : h.sonrakiAn;
  return h.copyWith(
    sonrakiAn: sonrakiHatirlaticiAni(h.tekrar, h.gun, h.kuralSaati, sonra),
    erteleAnTemizle: true,
  );
}

/// Snooze: only the moment changes, the rule stays.
Hatirlatici hatirlaticiErtele(Hatirlatici h, String sure, DateTime simdi) {
  if (h.durum != HatirlaticiDurumu.acik) return h;
  final an = hatirlaticiErteleAni(sure, simdi, h.kuralSaati);
  return an == null ? h : h.copyWith(erteleAn: an);
}
