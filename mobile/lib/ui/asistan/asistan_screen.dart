import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/asistan.dart';
import '../../data/models/yakala_girdisi.dart';
import '../../routing/router.dart';
import '../../utils/hatirlatici_hesap.dart';
import '../core/widgets.dart';
import '../shell/ust_sag.dart';
import '../yakalama/ses_view_model.dart';
import 'akis_ogeleri.dart';
import 'asistan_view_model.dart';

/// The Asistan tab (K-0024): the one feed (what was said, what was done and can be undone, questions, approvals, work cards,
/// the briefing, notes) with the filters on top and the one input at the bottom: text, voice, a photo. Share, the home screen
/// widget and the shortcut land here too ([baslangic]).
class AsistanScreen extends StatefulWidget {
  const AsistanScreen({
    super.key,
    required this.viewModel,
    this.ses,
    this.fotografSecici,
    this.baslangic,
    this.yazabilir = true,
    this.islerOkuyabilir = false,
    this.sahip = false,
    this.simdi,
  });

  final AsistanViewModel viewModel;

  /// Dictation behind the microphone button; without it the button is not shown.
  final SesViewModel? ses;

  /// Replaces the system picker in tests.
  final Future<String?> Function(ImageSource kaynak)? fotografSecici;

  /// What the screen starts with when it was opened from outside (the share menu, the widget, the shortcut); an empty one
  /// just puts the cursor in the input.
  final YakalaGirdisi? baslangic;

  /// False hides the input and the buttons that write (an account without the assistant permission).
  final bool yazabilir;

  /// The work card board is in the menu.
  final bool islerOkuyabilir;

  /// "Projeye yakala" (the old capture screen with its project picker) is in the menu.
  final bool sahip;

  /// The clock the day headings count from; tests give a fixed one.
  final DateTime Function()? simdi;

  @override
  State<AsistanScreen> createState() => _AsistanScreenState();
}

class _AsistanScreenState extends State<AsistanScreen> {
  static const _metinSiniri = AsistanGirdisi.enUzunMetin;

  final _metin = TextEditingController();
  final _odak = FocusNode();
  String? _foto;
  var _kaynak = AsistanKaynagi.yazi;
  YakalaGirdisi? _islenenBaslangic;

  AsistanViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _metin.addListener(() => setState(() {}));
    _baslangicIsle();
  }

  @override
  void didUpdateWidget(AsistanScreen eski) {
    super.didUpdateWidget(eski);
    _baslangicIsle();
  }

  /// Fills the input from a share, or just focuses it (widget, shortcut). Each starting state is taken once.
  void _baslangicIsle() {
    final b = widget.baslangic;
    if (b == null || identical(b, _islenenBaslangic)) return;
    _islenenBaslangic = b;
    if (b.metin != null) _metin.text = b.metin!;
    if (b.fotografYolu != null) _foto = b.fotografYolu;
    _kaynak = b.bos ? AsistanKaynagi.widget : AsistanKaynagi.paylas;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _odak.requestFocus();
    });
  }

  @override
  void dispose() {
    unawaited(widget.ses?.dikteDurdur());
    _metin.dispose();
    _odak.dispose();
    super.dispose();
  }

  bool get _gonderilebilir => (_metin.text.trim().isNotEmpty || _foto != null) && _metin.text.length <= _metinSiniri;

  Future<void> _fotografSec(ImageSource kaynak) async {
    try {
      final yol = widget.fotografSecici != null
          ? await widget.fotografSecici!(kaynak)
          : (await ImagePicker().pickImage(source: kaynak, maxWidth: 1600, imageQuality: 85))?.path;
      if (yol != null && mounted) setState(() => _foto = yol);
    } on Object {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf alınamadı.')));
    }
  }

  Future<void> _fotografMenusu() async {
    final kaynak = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('foto-kamera'),
              minTileHeight: 56,
              leading: const Icon(LucideIcons.camera),
              title: const Text('Fotoğraf çek'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              key: const ValueKey('foto-galeri'),
              minTileHeight: 56,
              leading: const Icon(LucideIcons.image),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (kaynak != null) await _fotografSec(kaynak);
  }

  void _dikteMetni(String metin) {
    _kaynak = AsistanKaynagi.ses;
    _metin.value = TextEditingValue(text: metin, selection: TextSelection.collapsed(offset: metin.length));
  }

  Future<void> _dikteyiDegistir() async {
    final ses = widget.ses!;
    if (ses.dinliyor) {
      await ses.dikteDurdur();
    } else {
      await ses.dikteBaslat(temel: _metin.text, metinDegisti: _dikteMetni);
    }
  }

  Future<void> _gonder() async {
    await widget.ses?.dikteDurdur();
    if (!_gonderilebilir) return;
    final metin = _metin.text;
    final foto = _foto;
    final kaynak = _kaynak;
    setState(() {
      _metin.clear();
      _foto = null;
      _kaynak = AsistanKaynagi.yazi;
    });
    await _vm.gonder(metin: metin, fotografKaynagi: foto, kaynak: kaynak);
  }

  void _mesajiGoster() {
    final m = _vm.mesajiAl();
    if (m != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yakala, sor, onayla', style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            const Text('Asistan'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey('asistan-menu'),
            tooltip: 'Daha fazla',
            icon: const Icon(LucideIcons.ellipsisVertical),
            onSelected: (rota) => context.push(rota),
            itemBuilder: (context) => [
              const PopupMenuItem(value: Rotalar.gelen, child: Text('Gelen kutusu')),
              const PopupMenuItem(value: Rotalar.eylemler, child: Text('Onay kuyruğu')),
              if (widget.islerOkuyabilir) const PopupMenuItem(value: Rotalar.isler, child: Text('İş kartları')),
              if (widget.sahip) const PopupMenuItem(value: Rotalar.yakala, child: Text('Projeye yakala')),
            ],
          ),
          const UstSagDugmeleri(),
        ],
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          _mesajiGoster();
          return Column(
            children: [
              _Suzgecler(viewModel: _vm),
              Expanded(child: _Akis(viewModel: _vm, yazabilir: widget.yazabilir, simdi: widget.simdi ?? DateTime.now)),
              if (widget.yazabilir) _giris(context),
            ],
          );
        },
      ),
    );
  }

  Widget _giris(BuildContext context) {
    final tema = Theme.of(context);
    final ses = widget.ses;
    return Material(
      color: tema.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: tema.colorScheme.outlineVariant))),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_foto != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: File(_foto!).existsSync() ? Image.file(File(_foto!), fit: BoxFit.cover) : const ColoredBox(color: Colors.black12),
                          ),
                        ),
                        Positioned(
                          right: -12,
                          top: -12,
                          child: IconButton(
                            key: const ValueKey('asistan-foto-kaldir'),
                            tooltip: 'Fotoğrafı kaldır',
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            icon: const Icon(LucideIcons.circleX, size: 20),
                            onPressed: () => setState(() => _foto = null),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (ses?.dikteMesaji != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Align(alignment: Alignment.centerLeft, child: Text(ses!.dikteMesaji!, style: TextStyle(color: tema.colorScheme.error))),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    key: const ValueKey('asistan-foto'),
                    tooltip: 'Fotoğraf ekle',
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(LucideIcons.camera),
                    onPressed: _fotografMenusu,
                  ),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('asistan-metin'),
                      controller: _metin,
                      focusNode: _odak,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Söyle ya da yaz…',
                        isDense: true,
                        errorText: _metin.text.length > _metinSiniri ? 'En çok $_metinSiniri karakter.' : null,
                      ),
                    ),
                  ),
                  if (ses != null)
                    ListenableBuilder(
                      listenable: ses,
                      builder: (context, _) => IconButton(
                        key: const ValueKey('asistan-dikte'),
                        tooltip: ses.dinliyor ? 'Dinlemeyi durdur' : 'Sesle yaz',
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        isSelected: ses.dinliyor,
                        icon: const Icon(LucideIcons.mic),
                        selectedIcon: Icon(LucideIcons.micOff, color: tema.colorScheme.error),
                        onPressed: _dikteyiDegistir,
                      ),
                    ),
                  IconButton.filled(
                    key: const ValueKey('asistan-gonder'),
                    tooltip: 'Gönder',
                    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                    icon: const Icon(LucideIcons.send),
                    onPressed: _gonderilebilir ? _gonder : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Hepsi", "Bekleyen 2", "İşler 2", "Notlar": the filters of the feed, with how many there are.
class _Suzgecler extends StatelessWidget {
  const _Suzgecler({required this.viewModel});

  final AsistanViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    String sayili(String ad, int n) => n > 0 ? '$ad $n' : ad;
    final secenekler = [
      (AkisSuzgeci.hepsi, 'Hepsi'),
      (AkisSuzgeci.bekleyen, sayili('Bekleyen', vm.bekleyenSayisi)),
      (AkisSuzgeci.isler, sayili('İşler', vm.islerSayisi)),
      (AkisSuzgeci.notlar, 'Notlar'),
    ];
    // Wrapped, not scrolled: at 360 dp the chips go on a second line, and the last one ("Notlar") is never out of sight.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Wrap(
        spacing: 8,
        children: [
          for (final (anahtar, etiket) in secenekler)
            ChoiceChip(
              key: ValueKey('suzgec-$anahtar'),
              label: Text(etiket),
              selected: vm.suzgec == anahtar,
              onSelected: (_) => vm.suzgecDegistir(anahtar),
            ),
        ],
      ),
    );
  }
}

/// The feed: oldest at the top, newest at the bottom next to the input (a reversed list, so it stays anchored at the bottom).
class _Akis extends StatelessWidget {
  const _Akis({required this.viewModel, required this.yazabilir, required this.simdi});

  final AsistanViewModel viewModel;
  final bool yazabilir;
  final DateTime Function() simdi;

  @override
  Widget build(BuildContext context) {
    final liste = viewModel.liste;
    if (liste == null) {
      if (viewModel.yukleniyor) return const YuklemeIskeleti(yukseklik: 64);
      return BosDurum(metin: viewModel.hata ?? 'Asistan akışı alınamadı.', dugme: 'Tekrar dene', onPressed: viewModel.yukle);
    }
    final tema = Theme.of(context);
    final ekler = (viewModel.cevrimdisi ? 1 : 0) + (viewModel.dahaVar ? 1 : 0);
    return RefreshIndicator(
      onRefresh: viewModel.yukle,
      child: OrtaGenislik(
        child: liste.isEmpty
            ? ListView(
                children: [
                  if (viewModel.cevrimdisi) _CevrimdisiNotu(renk: tema.colorScheme.onSurfaceVariant),
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      viewModel.suzgec == AkisSuzgeci.hepsi
                          ? 'Henüz bir şey yok. Aşağıdan söyle ya da yaz; asistan işi yapar.'
                          : 'Bu süzgeçte bir şey yok.',
                      key: const ValueKey('akis-bos'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                key: const ValueKey('akis-liste'),
                reverse: true,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                itemCount: liste.length + ekler,
                itemBuilder: (context, i) {
                  if (i >= liste.length) {
                    // Past the oldest item (the top of the screen): the offline note, then "older".
                    final ek = i - liste.length;
                    final cevrimdisiNotu = viewModel.cevrimdisi && ek == 0;
                    if (cevrimdisiNotu) return _CevrimdisiNotu(renk: tema.colorScheme.onSurfaceVariant);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Center(
                        child: viewModel.dahaYukleniyor
                            ? const CircularProgressIndicator()
                            : OutlinedButton(
                                key: const ValueKey('akis-daha'),
                                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                                onPressed: viewModel.dahaYukle,
                                child: const Text('Daha eski kayıtlar'),
                              ),
                      ),
                    );
                  }
                  final o = liste[i];
                  final yeniGun = i == liste.length - 1 || _gunAnahtari(liste[i + 1].zaman) != _gunAnahtari(o.zaman);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (yeniGun) _GunBasligi(zaman: o.zaman, simdi: simdi()),
                        _oge(o),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _oge(AkisOgesi o) => switch (o.tur) {
        AkisTuru.kullanici => KullaniciBalonu(
            key: ValueKey('akis-${o.id}'),
            oge: o,
            onSil: o.gonderilemedi != null ? () => viewModel.girdiyiSil(o) : null,
          ),
        AkisTuru.sonuc => SonucKarti(key: ValueKey('akis-${o.id}'), oge: o, viewModel: viewModel),
        AkisTuru.soru when o.soru != null => SoruKarti(key: ValueKey('akis-${o.id}'), oge: o, viewModel: viewModel, yazabilir: yazabilir),
        AkisTuru.onay when o.eylem != null => OnayKarti(key: ValueKey('akis-${o.id}'), oge: o, viewModel: viewModel, yazabilir: yazabilir),
        AkisTuru.isKarti when o.isKarti != null => IsKartiOgesi(key: ValueKey('akis-${o.id}'), oge: o),
        AkisTuru.brifing => BrifingOgesi(key: ValueKey('akis-${o.id}'), oge: o, viewModel: viewModel, yazabilir: yazabilir),
        AkisTuru.not when o.yakalama != null => NotKarti(key: ValueKey('akis-${o.id}'), oge: o, viewModel: viewModel, yazabilir: yazabilir),
        // A kind this version does not know: not shown.
        _ => const SizedBox.shrink(),
      };

  static DateTime _gunAnahtari(DateTime zaman) => istanbulGunu(zaman);
}

class _CevrimdisiNotu extends StatelessWidget {
  const _CevrimdisiNotu({required this.renk});

  final Color renk;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          'Çevrimdışısın; son okunan akış gösteriliyor. Yazdıkların bağlantı gelince gönderilecek.',
          key: const ValueKey('akis-cevrimdisi'),
          textAlign: TextAlign.center,
          style: TextStyle(color: renk),
        ),
      );
}

/// "Bugün", "Dün" or "6 Kasım": the day line above the first item of each day.
class _GunBasligi extends StatelessWidget {
  const _GunBasligi({required this.zaman, required this.simdi});

  final DateTime zaman;
  final DateTime simdi;

  @override
  Widget build(BuildContext context) {
    final gun = istanbulGunu(zaman);
    final bugun = istanbulGunu(simdi);
    final fark = bugun.difference(gun).inDays;
    final metin = fark <= 0 ? 'Bugün' : (fark == 1 ? 'Dün' : DateFormat('d MMMM', 'tr').format(gun));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: Text(metin, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}
