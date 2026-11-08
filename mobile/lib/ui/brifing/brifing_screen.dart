import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/brifing.dart';
import '../../routing/router.dart';
import '../core/widgets.dart';
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

/// Where a card leads: the screen about what it talks about. Null for cards with nowhere to go (calendar, capacity, empty day).
String? brifingKartRotasi(String tur) => switch (tur) {
      BrifingTuru.plan || BrifingTuru.kalan => Rotalar.bugun,
      BrifingTuru.hatirlatici => Rotalar.hatirlaticilar,
      BrifingTuru.onay => Rotalar.eylemler,
      _ => null,
    };

/// "7 Kasım Cumartesi" for a `yyyy-MM-dd` value; the value itself when it does not parse.
String brifingGunMetni(String gun) {
  final tarih = DateTime.tryParse(gun);
  return tarih == null ? gun : DateFormat('d MMMM EEEE', 'tr').format(tarih);
}

/// The morning briefing (K2.7): the day's cards with a thumb on each, a way into the screen a card is about, and a box at the
/// bottom to write a correction that goes through the same preview as "İşe çevir".
class BrifingScreen extends StatefulWidget {
  const BrifingScreen({super.key, required this.viewModel, required this.sesViewModel});

  final BrifingViewModel viewModel;

  /// Made with `kaynak: 'brifing'`, so what the box adds is labelled as coming from the briefing.
  final SesViewModel sesViewModel;

  @override
  State<BrifingScreen> createState() => _BrifingScreenState();
}

class _BrifingScreenState extends State<BrifingScreen> {
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
        return Scaffold(
          appBar: AppBar(
            title: const Text('Sabah brifingi'),
            actions: [
              if (vm.yenileyebilir)
                IconButton(
                  tooltip: 'Yeniden hazırla',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(LucideIcons.refreshCw),
                  onPressed: vm.mesgul || vm.yukleniyor ? null : vm.yenile,
                ),
            ],
          ),
          body: OrtaGenislik(child: _govde(context, vm)),
        );
      },
    );
  }

  Widget _govde(BuildContext context, BrifingViewModel vm) {
    final brifing = vm.brifing;
    if (vm.yukleniyor && brifing == null) return const Center(child: CircularProgressIndicator());
    if (brifing == null) {
      return BosDurum(
        ikon: LucideIcons.sun,
        metin: vm.hata ?? 'Brifing yok.',
        dugme: 'Tekrar dene',
        onPressed: vm.yukle,
      );
    }
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: vm.yukle,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                _Baslik(brifing: brifing, guncel: vm.guncel),
                const SizedBox(height: 8),
                for (final kart in brifing.kartlar)
                  _KartSatiri(
                    kart: kart,
                    mesgul: vm.mesgul,
                    onOy: (oy) => vm.oyVer(kart.sira, oy),
                  ),
              ],
            ),
          ),
        ),
        // The box is the "İşe çevir" entry: it needs Claude, so it is hidden while the assistant is not connected.
        if (widget.sesViewModel.asistanBagli)
          _YazmaKutusu(metin: _metin, ses: widget.sesViewModel, onGonder: _duzeltmeyiGonder),
      ],
    );
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik({required this.brifing, required this.guncel});

  final Brifing brifing;
  final bool guncel;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final yontem = brifing.yontem == Brifing.hesapYontemi ? 'Sabit kurallarla hazırlandı' : 'Asistan hazırladı';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(brifingGunMetni(brifing.gun), style: tema.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(yontem, style: tema.textTheme.bodySmall?.copyWith(color: soluk)),
        if (!guncel)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              key: const ValueKey('brifing-eski'),
              children: [
                Icon(LucideIcons.wifiOff, size: 18, color: soluk),
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
    return Card(
      key: ValueKey('brifing-kart-${kart.sira}'),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: rota == null ? null : () => rota == Rotalar.bugun ? context.go(rota) : context.push(rota),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(brifingTurIkonu(kart.tur), size: 22, color: tema.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kart.baslik, style: tema.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(kart.metin),
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
      ),
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
    final tema = Theme.of(context);
    final calisiyor = ses.akis == IsAkisi.yukleniyor;
    final gonderebilir = ses.cevrimici && metin.text.trim().isNotEmpty && !calisiyor;
    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 8, 8 + MediaQuery.viewInsetsOf(context).bottom),
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
                    helperStyle: TextStyle(color: tema.colorScheme.onSurfaceVariant),
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
      ),
    );
  }
}
