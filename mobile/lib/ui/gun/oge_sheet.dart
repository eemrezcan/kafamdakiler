import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../data/models/gun_gorunum.dart';
import 'gun_view_model.dart';
import 'hatirlatici_alanlari.dart';
import 'yapilacak_satiri.dart';

/// The sheet of one row (K-0024): add or change its reminder, carry it to tomorrow, split it over days, add a note, see its
/// estimate. [yazabilir] false (the Asistan account) leaves only the information.
///
/// Every action is kept on the phone at once ([GunViewModel]) and the sheet closes.
Future<void> ogeAc(BuildContext context, {required GunViewModel viewModel, required Yapilacak oge, required bool yazabilir}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _OgeSayfasi(viewModel: viewModel, oge: oge, yazabilir: yazabilir, kok: context),
  );
}

class _OgeSayfasi extends StatefulWidget {
  const _OgeSayfasi({required this.viewModel, required this.oge, required this.yazabilir, required this.kok});

  final GunViewModel viewModel;
  final Yapilacak oge;
  final bool yazabilir;
  final BuildContext kok;

  @override
  State<_OgeSayfasi> createState() => _OgeSayfasiState();
}

class _OgeSayfasiState extends State<_OgeSayfasi> {
  late bool _hatirlaticiAcik = widget.oge.hatirlatici != null;
  late HatirlaticiTaslagi _taslak = HatirlaticiTaslagi.ozetten(widget.oge.hatirlatici);
  final _bolum = GlobalKey();

  Yapilacak get _oge => widget.oge;
  GunViewModel get _vm => widget.viewModel;

  /// A row with a bag-less reminder is edited in the reminder's own form; a plan item or task carries its reminder here.
  bool get _bagsizHatirlatici => _oge.tur == YapilacakTuru.hatirlatici;
  bool get _hatirlaticiKurulabilir => widget.yazabilir && !_oge.yerel && _oge.tur != YapilacakTuru.etkinlik && !_bagsizHatirlatici;
  bool get _devredilebilir => widget.yazabilir && !_oge.yerel && _oge.tur != YapilacakTuru.etkinlik && !_oge.yapildi;
  bool get _bolunebilir => widget.yazabilir && !_oge.yerel && _oge.gorevKimligi != null && !_oge.yapildi;
  bool get _notEklenebilir => widget.yazabilir && !_oge.yerel && _oge.tur == YapilacakTuru.plan && _oge.maddeId != null;

  Future<void> _kaydet() async {
    final nav = Navigator.of(context);
    if (_hatirlaticiAcik) {
      await _vm.hatirlaticiYaz(_oge, _taslak.govde());
    } else if (_oge.hatirlatici != null) {
      await _vm.hatirlaticiSil(_oge);
    }
    nav.pop();
  }

  Future<void> _devret() async {
    final nav = Navigator.of(context);
    await _vm.yarinaDevret([_oge]);
    nav.pop();
  }

  Future<void> _bol() async {
    final gun = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Kaç güne bölünsün?'),
        children: [
          for (final n in const [2, 3, 4, 5, 7])
            SimpleDialogOption(
              key: ValueKey('bol-$n'),
              onPressed: () => Navigator.pop(context, n),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('$n gün')),
            ),
        ],
      ),
    );
    if (gun == null || !mounted) return;
    final nav = Navigator.of(context);
    await _vm.gunlereBol(_oge, gun);
    nav.pop();
  }

  Future<void> _notEkle() async {
    final metin = await showDialog<String>(context: context, builder: (_) => const _NotDialogu());
    if (metin == null || metin.trim().isEmpty || !mounted) return;
    final nav = Navigator.of(context);
    await _vm.notEkle(_oge, metin);
    nav.pop();
  }

  void _hatirlaticiDuzenle() {
    final router = GoRouter.of(widget.kok);
    final id = _oge.hatirlaticiId;
    Navigator.pop(context);
    if (id != null) router.push('/hatirlatici/$id/duzenle');
  }

  void _hatirlaticiBolumuneGit() {
    setState(() => _hatirlaticiAcik = true);
    final c = _bolum.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final alt = [
      DateFormat('d MMMM', 'tr').format(_vm.tarih),
      if (_oge.tahminDk != null) 'tahmin ${sureMetni(_oge.tahminDk!)}',
      if (_oge.proje != null) _oge.proje!,
    ].join(' · ');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_oge.baslik, style: tema.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(alt, style: tema.textTheme.bodyMedium?.copyWith(color: soluk)),
            if (yapilacakAltMetni(_oge).isNotEmpty) Text(yapilacakAltMetni(_oge), style: tema.textTheme.bodySmall?.copyWith(color: soluk)),
            if (_oge.tur == YapilacakTuru.etkinlik)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Takvim etkinliği: buradan yalnız görülür.', style: tema.textTheme.bodyMedium?.copyWith(color: soluk)),
              ),
            if (_oge.yerel)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Henüz gönderilmedi; bağlantı gelince gönderilecek.', style: tema.textTheme.bodyMedium?.copyWith(color: soluk)),
              ),
            const SizedBox(height: 12),
            if (_hatirlaticiKurulabilir || _devredilebilir || _bolunebilir || _notEklenebilir)
              Row(
                children: [
                  if (_hatirlaticiKurulabilir) Expanded(child: _Eylem(anahtar: 'oge-hatirlatici', ikon: LucideIcons.bell, ad: 'Hatırlatıcı', onTap: _hatirlaticiBolumuneGit)),
                  if (_devredilebilir) Expanded(child: _Eylem(anahtar: 'oge-devret', ikon: LucideIcons.arrowRight, ad: 'Yarına devret', onTap: _devret)),
                  if (_bolunebilir) Expanded(child: _Eylem(anahtar: 'oge-bol', ikon: LucideIcons.scissors, ad: 'Günlere böl', onTap: _bol)),
                  if (_notEklenebilir) Expanded(child: _Eylem(anahtar: 'oge-not-ekle', ikon: LucideIcons.pencil, ad: 'Not ekle', onTap: _notEkle)),
                ],
              ),
            if (_bagsizHatirlatici && widget.yazabilir && _oge.hatirlaticiId != null)
              OutlinedButton.icon(
                key: const ValueKey('oge-hatirlatici-duzenle'),
                onPressed: _hatirlaticiDuzenle,
                icon: const Icon(LucideIcons.pencil),
                label: const Text('Hatırlatıcıyı düzenle'),
              ),
            if (_hatirlaticiKurulabilir) ...[
              const Divider(),
              SwitchListTile(
                key: _bolum,
                contentPadding: EdgeInsets.zero,
                title: const Text('Hatırlatıcı'),
                value: _hatirlaticiAcik,
                onChanged: (v) => setState(() => _hatirlaticiAcik = v),
              ),
              if (_hatirlaticiAcik)
                HatirlaticiAlanlari(taslak: _taslak, varsayilanSaat: _oge.saat, onDegisti: (t) => setState(() => _taslak = t)),
              const SizedBox(height: 12),
              FilledButton(key: const ValueKey('oge-kaydet'), onPressed: _kaydet, child: const Text('Kaydet')),
            ],
          ],
        ),
      ),
    );
  }
}

class _Eylem extends StatelessWidget {
  const _Eylem({required this.anahtar, required this.ikon, required this.ad, required this.onTap});

  final String anahtar;
  final IconData ikon;
  final String ad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return InkWell(
      key: ValueKey(anahtar),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: tema.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(ikon, size: 20, color: tema.colorScheme.primary),
              ),
              const SizedBox(height: 4),
              Text(ad, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: tema.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// The note box: the dialog owns its controller, so it is not used after the closing animation has begun.
class _NotDialogu extends StatefulWidget {
  const _NotDialogu();

  @override
  State<_NotDialogu> createState() => _NotDialoguState();
}

class _NotDialoguState extends State<_NotDialogu> {
  final _denetleyici = TextEditingController();

  @override
  void dispose() {
    _denetleyici.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Not ekle'),
      content: TextField(
        key: const ValueKey('oge-not'),
        controller: _denetleyici,
        autofocus: true,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, _denetleyici.text), child: const Text('Kaydet')),
      ],
    );
  }
}
