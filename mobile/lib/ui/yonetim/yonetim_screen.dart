import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/yakalama.dart';
import '../../data/models/yonetim.dart';
import '../core/widgets.dart';
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
                  _Baslik('Asistan\'ın izinleri', ipucu: 'Kapatılan izin, Asistan\'ın bir sonraki isteğinde etkili olur.'),
                  Card(
                    child: Column(
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
                      ],
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
