import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/aliskanlik.dart';
import '../../data/models/gun_gorunum.dart';
import '../../data/repositories/bildirim_izni.dart';
import '../../routing/router.dart';
import '../../utils/metin.dart';
import '../core/widgets.dart';
import '../gun/gun_view_model.dart';
import '../oturum/okuma_kaydi_sheet.dart';
import '../gun/oge_sheet.dart';
import '../gun/yapilacak_satiri.dart';
import '../shell/ust_sag.dart';
import 'aliskanlik_seridi.dart';
import 'bildirim_kapali_uyarisi.dart';
import 'bugun_view_model.dart';
import 'devret_sheet.dart';
import 'dunden_bandi.dart';
import 'gun_ozeti_karti.dart';
import 'sayi_giris_dialog.dart';

/// The Bugün tab (K-0024): the assistant's summary with the day's load, what yesterday left, today's habits as rings and the
/// one list of things to do (plan items, tasks, reminders and events), each with its own "yaptım".
class BugunScreen extends StatelessWidget {
  const BugunScreen({super.key, required this.viewModel, required this.gun, this.bildirimIzni, this.yazabilir = true});

  /// The habit strip's data and writes.
  final BugunViewModel viewModel;

  /// The day view: the summary, the load, the left-overs and the list.
  final GunViewModel gun;

  /// The "Bildirimler kapalı" warning near the top; without it (tests) there is no warning.
  final BildirimIzni? bildirimIzni;

  /// False (the Asistan account) hides the write buttons.
  final bool yazabilir;

  Future<void> _tik(BuildContext context, Aliskanlik a) async {
    final mesaj = ScaffoldMessenger.of(context);
    final onceki = await viewModel.tikDegistir(a);
    mesaj
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(onceki >= 1 ? '${a.ad}: işaret kaldırıldı' : '${a.ad}: yapıldı'),
        action: SnackBarAction(label: 'Geri al', onPressed: () => viewModel.miktarYaz(a, onceki)),
      ));
  }

  Future<void> _sayiGir(BuildContext context, Aliskanlik a) async {
    final yeni = await sayiGirisDialogu(context, baslik: a.ad, mevcut: a.bugun?.miktar ?? 0, birim: a.birim);
    if (yeni != null) await viewModel.miktarYaz(a, yeni);
  }

  Future<void> _yaptim(BuildContext context, Yapilacak oge) async {
    final mesaj = ScaffoldMessenger.of(context);
    final geriAlinabilir = oge.tur != YapilacakTuru.gorev;
    final yapiliyordu = oge.yapildi;
    if (!await gun.yaptim(oge)) return;
    mesaj
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(yapiliyordu ? '${oge.baslik}: işaret kaldırıldı' : '${oge.baslik}: yapıldı'),
        // A finished task cannot be reopened from here (the server answers 409 "gorev-geri-alinamaz").
        action: yapiliyordu || !geriAlinabilir
            ? null
            : SnackBarAction(label: 'Geri al', onPressed: () => gun.yaptim(oge.copyWith(durum: 'yapildi'))),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final bugun = gun.tarih;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trBuyuk(DateFormat('EEEE, d MMMM', 'tr').format(bugun)),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.8),
            ),
            const Text('Bugün'),
          ],
        ),
        actions: const [UstSagDugmeleri()],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([viewModel, gun]),
        builder: (context, _) {
          final g = gun.gun;
          if (g == null) {
            if (gun.yukleniyor) return const YuklemeIskeleti();
            return BosDurum(metin: gun.hata ?? 'Gün alınamadı.', dugme: 'Tekrar dene', onPressed: gun.yukle);
          }
          return RefreshIndicator(
            onRefresh: () => Future.wait([gun.yukle(), viewModel.yukle()]),
            child: OrtaGenislik(child: _liste(context, g)),
          );
        },
      ),
    );
  }

  Widget _liste(BuildContext context, GunGorunum g) {
    final tema = Theme.of(context);
    final planli = viewModel.planli;
    final devretAday = devredilecekler(g);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (gun.cevrimdisi || viewModel.cevrimdisi)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Çevrimdışısın; kaydettiklerin telefona yazılıyor, bağlantı gelince gönderilecek.',
              style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
        if (bildirimIzni != null) BildirimKapaliUyarisi(izin: bildirimIzni!),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GunOzetiKarti(
            gun: g,
            onDevret: yazabilir && devretAday.isNotEmpty ? () => devretAc(context, viewModel: gun) : null,
            onYarinaBak: () => context.go(Rotalar.takvim),
          ),
        ),
        for (final d in g.dundenKalanlar)
          DundenBandi(
            dunden: d,
            onAl: yazabilir ? () => gun.bugunAl(d) : null,
            onBirak: yazabilir ? () => gun.dundenBirak(d) : null,
          ),
        if (planli.isNotEmpty) ...[
          _Baslik('Alışkanlıklar', eylem: 'Tümü', onEylem: () => context.go(Rotalar.aliskanliklar)),
          AliskanlikSeridi(
            aliskanliklar: planli,
            yazabilir: yazabilir,
            onTik: (a) => _tik(context, a),
            onArti: (a) => viewModel.miktarYaz(a, (a.bugun?.miktar ?? 0) + 1),
            onSayiGir: (a) => _sayiGir(context, a),
            onRafAc: (a) => okumaKaydiAc(context, aliskanlik: a),
          ),
        ],
        _Baslik('Yapılacaklar · ${g.acikSayi}', eylem: 'Takvim', onEylem: () => context.go(Rotalar.takvim)),
        if (g.ogeler.isEmpty)
          const BosKart(key: ValueKey('gun-bos'), metin: 'Bugün için yapılacak yok.')
        else ...[
          YapilacakListesi(
            ogeler: g.ogeler,
            onAc: (o) => ogeAc(context, viewModel: gun, oge: o, yazabilir: yazabilir),
            onYaptim: yazabilir ? (o) => _yaptim(context, o) : null,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Bir işe dokun: hatırlatıcı, devret, böl, not',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik(this.metin, {this.eylem, this.onEylem});

  final String metin;
  final String? eylem;
  final VoidCallback? onEylem;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            trBuyuk(metin),
            style: tema.textTheme.labelMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w600),
          ),
          if (eylem != null) TextButton(onPressed: onEylem, style: TextButton.styleFrom(minimumSize: const Size(48, 48)), child: Text(eylem!)),
        ],
      ),
    );
  }
}
