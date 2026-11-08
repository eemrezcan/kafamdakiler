import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/brifing.dart';
import '../../routing/router.dart';
import '../yakalama/is_onizleme_sheet.dart';
import '../yakalama/ses_view_model.dart';
import 'brifing_view_model.dart';

/// The icon of a kind of card.
IconData brifingTurIkonu(String tur) => switch (tur) {
      BrifingTuru.plan => LucideIcons.calendarCheck,
      BrifingTuru.kalan => LucideIcons.history,
      BrifingTuru.hatirlatici => LucideIcons.bell,
      BrifingTuru.onay => LucideIcons.listChecks,
      BrifingTuru.takvim => LucideIcons.calendarClock,
      BrifingTuru.kapasite => LucideIcons.gauge,
      _ => LucideIcons.sun,
    };

/// Where a card leads: the screen about what it talks about. Null for cards with nowhere to go (the plan card is on Bugün
/// already; calendar, capacity, empty day).
String? brifingKartRotasi(String tur) => switch (tur) {
      BrifingTuru.hatirlatici => Rotalar.hatirlaticilar,
      BrifingTuru.onay => Rotalar.eylemler,
      _ => null,
    };

/// "7 Kasım Cumartesi" for a `yyyy-MM-dd` value; the value itself when it does not parse.
String brifingGunMetni(String gun) {
  final tarih = DateTime.tryParse(gun);
  return tarih == null ? gun : DateFormat('d MMMM EEEE', 'tr').format(tarih);
}

/// The cards the strip shows: the leftovers card is left out, because Bugün lists what is left from yesterday itself.
List<BrifingKarti> brifingSeridiKartlari(Brifing brifing) => [
      for (final k in brifing.kartlar)
        if (k.tur != BrifingTuru.kalan) k,
    ];

/// The morning briefing (K2.7) as a strip at the top of Bugün: the day's cards with a thumb on each, a way into the screen a
/// card is about, and (while the assistant is connected) a box to write a correction that goes through the same preview as
/// "İşe çevir". Hidden until there is a briefing to show: loading, "not ready yet" and failures leave no gap on Bugün.
class BrifingSeridi extends StatefulWidget {
  const BrifingSeridi({super.key, required this.viewModel, required this.sesViewModel});

  final BrifingViewModel viewModel;

  /// Made with `kaynak: 'brifing'`, so what the box adds is labelled as coming from the briefing.
  final SesViewModel sesViewModel;

  @override
  State<BrifingSeridi> createState() => _BrifingSeridiState();
}

class _BrifingSeridiState extends State<BrifingSeridi> {
  final _metin = TextEditingController();

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  void _mesajiGoster() {
    final mesaj = widget.viewModel.mesajiAl();
    if (mesaj == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
    });
  }

  Future<void> _duzeltmeyiGonder() async {
    final ses = widget.sesViewModel;
    await ses.isCikar(_metin.text);
    if (!mounted) return;
    if (ses.akis != IsAkisi.onizleme) {
      final hata = ses.hata;
      if (hata != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hata)));
      return;
    }
    await isOnizlemesiniGoster(context, ses);
    if (!mounted) return;
    // Cleared only when the person went through with it; a closed preview keeps the text for another try.
    if (ses.eklendi) _metin.clear();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    return ListenableBuilder(
      listenable: Listenable.merge([vm, widget.sesViewModel, _metin]),
      builder: (context, _) {
        _mesajiGoster();
        final brifing = vm.brifing;
        if (brifing == null) return const SizedBox.shrink();
        final kartlar = brifingSeridiKartlari(brifing);
        // Nothing left to show once the leftovers card is out: no empty box with only a title.
        if (kartlar.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            key: const ValueKey('brifing-seridi'),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Baslik(
                  brifing: brifing,
                  guncel: vm.guncel,
                  yenileyebilir: vm.yenileyebilir,
                  onYenile: vm.mesgul || vm.yukleniyor ? null : vm.yenile,
                ),
                for (final kart in kartlar)
                  _KartSatiri(kart: kart, mesgul: vm.mesgul, onOy: (oy) => vm.oyVer(kart.sira, oy)),
                // The box is the "İşe çevir" entry: it needs Claude, so it is hidden while the assistant is not connected.
                if (widget.sesViewModel.asistanBagli)
                  _YazmaKutusu(metin: _metin, ses: widget.sesViewModel, onGonder: _duzeltmeyiGonder),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik({required this.brifing, required this.guncel, required this.yenileyebilir, required this.onYenile});

  final Brifing brifing;
  final bool guncel;

  /// The Sahip may ask for a new briefing (three a day); for anyone else the button is not there.
  final bool yenileyebilir;

  /// Null while something is on its way.
  final VoidCallback? onYenile;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final yontem = brifing.yontem == Brifing.hesapYontemi ? 'Sabit kurallarla hazırlandı' : 'Asistan hazırladı';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.sun, size: 22, color: tema.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sabah brifingi', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text('${brifingGunMetni(brifing.gun)} · $yontem', style: tema.textTheme.bodySmall?.copyWith(color: soluk)),
                  if (!guncel)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        key: const ValueKey('brifing-eski'),
                        children: [
                          Icon(LucideIcons.wifiOff, size: 16, color: soluk),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bugünün brifingi alınamadı; telefondaki son brifing gösteriliyor.',
                              style: tema.textTheme.bodySmall?.copyWith(color: soluk),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (yenileyebilir)
            IconButton(
              tooltip: 'Yeniden hazırla',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: onYenile,
            ),
        ],
      ),
    );
  }
}

class _KartSatiri extends StatelessWidget {
  const _KartSatiri({required this.kart, required this.mesgul, required this.onOy});

  final BrifingKarti kart;
  final bool mesgul;
  final void Function(int oy) onOy;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rota = brifingKartRotasi(kart.tur);
    return Column(
      key: ValueKey('brifing-kart-${kart.sira}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        InkWell(
          onTap: rota == null ? null : () => rotayaGit(context, rota),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(brifingTurIkonu(kart.tur), size: 20, color: tema.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kart.baslik, style: tema.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(kart.metin, style: tema.textTheme.bodyMedium),
                    ],
                  ),
                ),
                if (rota != null) Icon(LucideIcons.chevronRight, color: tema.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _OyDugmesi(
              key: ValueKey('brifing-oy-yukari-${kart.sira}'),
              ikon: LucideIcons.thumbsUp,
              ipucu: 'Beğendim',
              secili: kart.oy == 1,
              onPressed: mesgul ? null : () => onOy(1),
            ),
            _OyDugmesi(
              key: ValueKey('brifing-oy-asagi-${kart.sira}'),
              ikon: LucideIcons.thumbsDown,
              ipucu: 'Beğenmedim',
              secili: kart.oy == -1,
              onPressed: mesgul ? null : () => onOy(-1),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ],
    );
  }
}

class _OyDugmesi extends StatelessWidget {
  const _OyDugmesi({super.key, required this.ikon, required this.ipucu, required this.secili, required this.onPressed});

  final IconData ikon;
  final String ipucu;
  final bool secili;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: ipucu,
        isSelected: secili,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(ikon),
        selectedIcon: Icon(ikon, color: Theme.of(context).colorScheme.primary),
        onPressed: onPressed,
      );
}

class _YazmaKutusu extends StatelessWidget {
  const _YazmaKutusu({required this.metin, required this.ses, required this.onGonder});

  final TextEditingController metin;
  final SesViewModel ses;
  final VoidCallback onGonder;

  @override
  Widget build(BuildContext context) {
    final soluk = Theme.of(context).colorScheme.onSurfaceVariant;
    final calisiyor = ses.akis == IsAkisi.yukleniyor;
    final gonderebilir = ses.cevrimici && metin.text.trim().isNotEmpty && !calisiyor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('brifing-metin'),
                  controller: metin,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Brifinge yaz',
                    helperText: ses.cevrimici ? 'Bir şey ekle ya da düzelt: «cuma 10\'da diş randevusu»' : 'Çevrimdışısın: yazılanı Asistan işleyemez.',
                    helperMaxLines: 2,
                    helperStyle: TextStyle(color: soluk),
                  ),
                ),
              ),
              calisiyor
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      key: const ValueKey('brifing-gonder'),
                      tooltip: 'İşe çevir',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(LucideIcons.send),
                      onPressed: gonderebilir ? onGonder : null,
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
