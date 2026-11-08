import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/eylem.dart';
import '../../data/models/yakalama.dart';
import '../../utils/eylem_gorunum.dart';
import '../../data/models/yonetim.dart';
import '../../data/models/zaman_cizelgesi.dart';
import '../core/widgets.dart';
import 'asistan_sifre_dialog.dart';
import 'izin_gruplari.dart';
import 'yonetim_view_model.dart';

/// The Sahip's management screen (M07): the Asistan's permissions (with their
/// keys), the brain status, and the queue of captures going to the brain with
/// a "send again" button for the failed and stuck ones.
class YonetimScreen extends StatelessWidget {
  const YonetimScreen({super.key, required this.viewModel});

  final YonetimViewModel viewModel;

  /// Rows of the queue shown besides the ones that need a look.
  static const _digerGorunen = 20;

  // Takes the messenger before the call is awaited, so no BuildContext crosses the wait.
  void _bildir(ScaffoldMessengerState messenger, String? mesaj) {
    if (mesaj == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mesaj)));
  }

  Future<void> _asistanSifresi(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final yenilendi = await showDialog<bool>(
      context: context,
      builder: (context) => AsistanSifreDialog(gonder: viewModel.asistanSifresiniYenile),
    );
    if (yenilendi == true) _bildir(messenger, 'Asistan\'ın şifresi değişti, oturumları kapatıldı.');
  }

  Future<void> _yenidenDene(BuildContext context, Gonderim g) async {
    final messenger = ScaffoldMessenger.of(context);
    // A stuck send may already be a card: ask before risking a second one.
    if (g.gonderim == GonderimDurumu.takili) {
      final onay = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Yeniden gönderilsin mi?'),
          content: const Text(
            'Bu gönderimin sonucu belirsiz: kart beyinde olabilir. Önce beynin gelen kutusuna bak; '
            'yine de gönderirsen aynı kart iki kez oluşabilir.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yine de gönder')),
          ],
        ),
      );
      if (onay != true || !context.mounted) return;
    }
    _bildir(messenger, await viewModel.yenidenDene(g));
  }

  /// One line for the modes of all kinds of action, e.g. "5 eylem türü: 4 Sor, 1 Yasak".
  static String _kipOzeti(List<EylemKipDurumu> kipler) {
    if (kipler.isEmpty) return 'Tanımlı eylem türü yok';
    final parcalar = [
      for (final kip in EylemKipi.values)
        if (kipler.any((k) => k.kip == kip)) '${kipler.where((k) => k.kip == kip).length} ${eylemKipAdi(kip)}',
    ];
    return '${kipler.length} eylem türü: ${parcalar.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yönetim')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          if (viewModel.beyin == null) {
            if (viewModel.hata != null) {
              return BosDurum(
                ikon: LucideIcons.triangleAlert,
                metin: viewModel.hata!,
                dugme: 'Tekrar dene',
                onPressed: viewModel.yukle,
              );
            }
            return const YuklemeIskeleti(yukseklik: 72);
          }
          return RefreshIndicator(
            onRefresh: viewModel.yukle,
            child: OrtaGenislik(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                // Room for the floating "Yakala" button under the last row.
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _Baslik('Asistan\'ın izinleri', ipucu: 'Yazar, okumayı da kapsar. Değişiklik Asistan\'ın bir sonraki isteğinde geçerli olur.'),
                  for (final grup in izinGruplari)
                    _IzinKarti(
                      grup: grup,
                      seviye: viewModel.seviye(grup),
                      mesgul: viewModel.grupMesgulMu(grup),
                      onSec: (seviye) async {
                        final messenger = ScaffoldMessenger.of(context);
                        _bildir(messenger, await viewModel.grupAyarla(grup, seviye));
                      },
                    ),
                  Card(
                    child: SwitchListTile(
                      key: const ValueKey('anahtar-$asistanKullanIzni'),
                      title: const Text('Asistan Claude\'u çağırabilsin'),
                      subtitle: const Text('Metinden iş çıkarma, özetleme ve maddeleme için. Kendi başına bir şey kaydetmez.'),
                      value: viewModel.acikIzinler.contains(asistanKullanIzni),
                      onChanged: viewModel.izinMesgulMu(asistanKullanIzni)
                          ? null
                          : (acik) async {
                              final messenger = ScaffoldMessenger.of(context);
                              final izin = viewModel.izinler.where((i) => i.izin == asistanKullanIzni).firstOrNull;
                              if (izin != null) _bildir(messenger, await viewModel.izinDegistir(izin, acik));
                            },
                    ),
                  ),
                  const _Baslik('Google Takvim'),
                  _GoogleKarti(
                    viewModel: viewModel,
                    onEsitle: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      _bildir(messenger, await viewModel.simdiEsitle());
                    },
                  ),
                  const _Baslik('Eylem kipleri'),
                  Card(
                    child: ListTile(
                      leading: const Icon(LucideIcons.listChecks),
                      title: Text(_kipOzeti(viewModel.eylemKipleri)),
                      subtitle: const Text('Ayrıntılar aşağıdaki "Gelişmiş" bölümünde.'),
                    ),
                  ),
                  Card(
                    child: ExpansionTile(
                      key: const ValueKey('gelismis'),
                      title: const Text('Gelişmiş'),
                      subtitle: const Text('Tek tek izinler ve eylem kipleri'),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      children: [
                        for (final izin in viewModel.izinler)
                          SwitchListTile(
                            key: ValueKey('izin-${izin.izin}'),
                            title: Text(izin.izin),
                            subtitle: Text(izin.aciklama),
                            value: izin.acik,
                            onChanged: viewModel.izinMesgulMu(izin.izin)
                                ? null
                                : (acik) async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    _bildir(messenger, await viewModel.izinDegistir(izin, acik));
                                  },
                          ),
                        const _Baslik(
                          'Asistan\'ın eylem kipleri',
                          ipucu: 'Kendin yap seçilse bile başkasının yazdığı metinden çıkan öneriler onay bekler.',
                        ),
                        if (viewModel.eylemKipleri.isEmpty)
                          const Padding(padding: EdgeInsets.all(8), child: Text('Tanımlı eylem türü yok.')),
                        for (final k in viewModel.eylemKipleri)
                          _KipKarti(
                            kayit: k,
                            mesgul: viewModel.kipMesgulMu(k.tur),
                            onSec: (kip) async {
                              final messenger = ScaffoldMessenger.of(context);
                              _bildir(messenger, await viewModel.kipDegistir(k, kip));
                            },
                          ),
                      ],
                    ),
                  ),
                  const _Baslik('Asistan\'ın şifresi'),
                  Card(
                    child: ListTile(
                      minTileHeight: 56,
                      leading: const Icon(LucideIcons.keyRound),
                      title: const Text('Asistan\'ın şifresini yenile'),
                      subtitle: const Text('Oturumları da kapanır'),
                      trailing: const Icon(LucideIcons.chevronRight),
                      onTap: () => _asistanSifresi(context),
                    ),
                  ),
                  const _Baslik('Beyin'),
                  _BeyinKarti(durum: viewModel.beyin!),
                  const _Baslik('Gönderim kuyruğu'),
                  ..._kuyruk(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _kuyruk(BuildContext context) {
    final kuyruk = viewModel.kuyruk;
    if (kuyruk.isEmpty) {
      return const [Padding(padding: EdgeInsets.all(8), child: Text('Henüz yakalama yok.'))];
    }
    // The server sends the ones that need a look first; the rest is cut short.
    final ilgi = kuyruk.where((g) => g.yenidenDenenebilir).toList();
    final digerleri = kuyruk.where((g) => !g.yenidenDenenebilir).toList();
    return [
      if (ilgi.isEmpty) const Padding(padding: EdgeInsets.fromLTRB(8, 0, 8, 8), child: Text('Takılı ya da hatalı gönderim yok.')),
      for (final g in ilgi) _GonderimKarti(gonderim: g, viewModel: viewModel, onYenidenDene: () => _yenidenDene(context, g)),
      for (final g in digerleri.take(_digerGorunen))
        _GonderimKarti(gonderim: g, viewModel: viewModel, onYenidenDene: () => _yenidenDene(context, g)),
      if (digerleri.length > _digerGorunen)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text('… ve ${digerleri.length - _digerGorunen} yakalama daha.'),
        ),
    ];
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik(this.metin, {this.ipucu});

  final String metin;
  final String? ipucu;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metin, style: tema.textTheme.titleMedium),
          if (ipucu != null) Text(ipucu!, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// "8 Kasım 14:30" in the phone's time.
String tarihSaatMetni(DateTime an) => DateFormat('d MMMM HH:mm', 'tr').format(an.toLocal());

/// One area of the Asistan's permissions as a single choice: closed, reads, or reads and writes.
class _IzinKarti extends StatelessWidget {
  const _IzinKarti({required this.grup, required this.seviye, required this.mesgul, required this.onSec});

  final IzinGrubu grup;
  final IzinSeviyesi seviye;
  final bool mesgul;
  final Future<void> Function(IzinSeviyesi) onSec;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      key: ValueKey('grup-${grup.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(grup.ad, style: tema.textTheme.titleSmall)),
                if (seviye == IzinSeviyesi.ozel) Chip(label: Text(IzinSeviyesi.ozel.ad), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<IzinSeviyesi>(
              showSelectedIcon: false,
              emptySelectionAllowed: true,
              segments: [
                for (final s in [IzinSeviyesi.kapali, IzinSeviyesi.okur, IzinSeviyesi.okurYazar])
                  ButtonSegment(value: s, label: Text(s.ad)),
              ],
              selected: seviye == IzinSeviyesi.ozel ? const {} : {seviye},
              onSelectionChanged: mesgul
                  ? null
                  : (s) {
                      if (s.isNotEmpty) onSec(s.first);
                    },
            ),
            const SizedBox(height: 6),
            Text(grup.aciklama, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// The Google Calendar link. Connecting happens on the web; here the state and a "sync now" button.
class _GoogleKarti extends StatelessWidget {
  const _GoogleKarti({required this.viewModel, required this.onEsitle});

  final YonetimViewModel viewModel;
  final VoidCallback onEsitle;

  @override
  Widget build(BuildContext context) {
    final google = viewModel.google;
    final Widget satir;
    if (google == null) {
      satir = ListTile(
        leading: const Icon(LucideIcons.calendarX),
        title: Text(viewModel.googleOkunamadi ? 'Google Takvim durumu okunamadı' : 'Google Takvim durumu okunuyor'),
        subtitle: const Text('Ekranı aşağı çekip yenile.'),
      );
    } else if (google.bagli) {
      final son = google.sonEsitleme;
      satir = ListTile(
        leading: const Icon(LucideIcons.calendarCheck),
        title: const Text('Google Takvim bağlı'),
        subtitle: Text(son == null ? 'Henüz eşitlenmedi' : 'Son eşitleme: ${tarihSaatMetni(son)}'),
        trailing: TextButton.icon(
          onPressed: viewModel.esitleniyor ? null : onEsitle,
          icon: viewModel.esitleniyor
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(LucideIcons.refreshCw),
          label: const Text('Şimdi eşitle'),
        ),
      );
    } else if (google.durum == GoogleDurumu.kapali) {
      satir = const ListTile(
        leading: Icon(LucideIcons.calendarX),
        title: Text('Google Takvim ayarlanmamış'),
        subtitle: Text('Sunucuda Google ayarları yapılınca burada görünür.'),
      );
    } else {
      satir = ListTile(
        leading: const Icon(LucideIcons.calendarX),
        title: Text(google.durum == GoogleDurumu.yenidenBaglan ? 'Google Takvim yeniden bağlanmalı' : 'Google Takvim bağlı değil'),
        subtitle: const Text('Bağlamak için web\'deki Yönetim sayfasını aç.'),
      );
    }
    return Card(child: satir);
  }
}

/// One kind of action with its three modes as a segmented choice, and what the chosen mode means.
class _KipKarti extends StatelessWidget {
  const _KipKarti({required this.kayit, required this.mesgul, required this.onSec});

  final EylemKipDurumu kayit;
  final bool mesgul;
  final Future<void> Function(EylemKipi) onSec;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      key: ValueKey('kip-${kayit.tur}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kayit.turAdi, style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<EylemKipi>(
              showSelectedIcon: false,
              segments: [
                for (final kip in EylemKipi.values) ButtonSegment(value: kip, label: Text(eylemKipAdi(kip))),
              ],
              selected: {kayit.kip},
              onSelectionChanged: mesgul ? null : (s) => onSec(s.first),
            ),
            const SizedBox(height: 6),
            Text(eylemKipAciklamasi(kayit.kip), style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _BeyinKarti extends StatelessWidget {
  const _BeyinKarti({required this.durum});

  final YonetimBeyinDurumu durum;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(durum.bagli ? LucideIcons.brain : LucideIcons.cloudOff),
            title: Text(durum.bagli ? 'Beyin bağlı' : 'Beyin bağlı değil'),
            subtitle: Text(durum.vault ?? 'Sunucuda beyin ayarlı değil'),
          ),
          ListTile(
            leading: const Icon(LucideIcons.inbox),
            title: Text('${durum.bekleyenYakalama} yakalama bekliyor'),
            subtitle: Text(durum.hataliYakalama == 0
                ? 'Takılı ya da hatalı gönderim yok'
                : '${durum.hataliYakalama} gönderim takılı ya da hatalı'),
          ),
        ],
      ),
    );
  }
}

class _GonderimKarti extends StatelessWidget {
  const _GonderimKarti({required this.gonderim, required this.viewModel, required this.onYenidenDene});

  final Gonderim gonderim;
  final YonetimViewModel viewModel;
  final VoidCallback onYenidenDene;

  String get _durumMetni => switch (gonderim.gonderim) {
        GonderimDurumu.bekliyor => 'Bekliyor',
        GonderimDurumu.gonderiliyor => 'Gönderiliyor',
        GonderimDurumu.hatali => 'Hatalı',
        GonderimDurumu.takili => 'Takılı',
        GonderimDurumu.tamam => gonderim.durum == YakalamaDurumu.islendi ? 'İşlendi' : 'Beyne gitti',
      };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final sorunlu = gonderim.yenidenDenenebilir;
    final metin = (gonderim.metin ?? '').trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metin.isEmpty ? 'Fotoğraf' : metin,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: metin.isEmpty ? TextStyle(color: tema.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic) : null,
            ),
            const SizedBox(height: 4),
            Text(
              [_durumMetni, if (gonderim.denemeSayisi > 0) '${gonderim.denemeSayisi} deneme'].join(' · '),
              style: tema.textTheme.bodySmall?.copyWith(color: sorunlu ? tema.colorScheme.error : tema.colorScheme.onSurfaceVariant),
            ),
            if (gonderim.sonHata != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(gonderim.sonHata!, maxLines: 4, overflow: TextOverflow.ellipsis, style: tema.textTheme.bodySmall),
              ),
            if (sorunlu)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: viewModel.yenidenGonderiliyorMu(gonderim.id) ? null : onYenidenDene,
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('Yeniden gönder'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
