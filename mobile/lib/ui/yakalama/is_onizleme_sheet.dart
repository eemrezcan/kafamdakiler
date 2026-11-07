import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/ses.dart';
import '../../utils/aliskanlik_gunu.dart';
import 'ses_view_model.dart';

/// Opens the preview of "İşe çevir" (K2.4) over the capture screen and follows [viewModel] through the preview, the sending
/// and the results. Closing the sheet ends the flow. Nothing is saved before "Seçilenleri ekle".
Future<void> isOnizlemesiniGoster(BuildContext context, SesViewModel viewModel) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _OnizlemeSheet(viewModel: viewModel),
  );
  viewModel.akisiKapat();
}

class _TurBilgisi {
  const _TurBilgisi(this.ad, this.ikon);

  final String ad;
  final IconData ikon;

  static _TurBilgisi of(String tur) => switch (tur) {
        IsOnerisi.hatirlatici => const _TurBilgisi('Hatırlatıcı', LucideIcons.bell),
        IsOnerisi.plan => const _TurBilgisi('Gün planı', LucideIcons.calendarPlus),
        IsOnerisi.gorev => const _TurBilgisi('Görev', LucideIcons.squareCheck),
        _ => _TurBilgisi(tur, LucideIcons.circleDot),
      };
}

/// "13 Kasım Cuma" for a `yyyy-MM-dd` value; the value itself when it does not parse.
String _gunMetni(String gun) {
  final tarih = DateTime.tryParse(gun);
  return tarih == null ? gun : DateFormat('d MMMM EEEE', 'tr').format(tarih);
}

/// The second line of a suggestion: the date and time, the project, the estimate.
String _ayrinti(IsOnerisi o) {
  final parcalar = <String>[
    _TurBilgisi.of(o.tur).ad,
    if (o.gun != null) _gunMetni(o.gun!),
    if (o.saat != null) o.saat!,
    if (o.tekrar != null && o.tekrar != 'yok') 'tekrar: ${o.tekrar}',
    if (o.bolum != null) o.bolum!,
    if (o.tahminDk != null) '${o.tahminDk} dk',
    if (o.proje != null) o.proje!,
    if (o.alan != null) o.alan!,
    if (o.bitis != null) 'bitiş ${_gunMetni(o.bitis!)}',
  ];
  return parcalar.join(' · ');
}

class _OnizlemeSheet extends StatelessWidget {
  const _OnizlemeSheet({required this.viewModel});

  final SesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final mesgul = viewModel.akis == IsAkisi.uygulaniyor;
        return PopScope(
          // While the chosen ones are being sent the sheet stays: closing it would hide the results.
          canPop: !mesgul,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
                child: switch (viewModel.akis) {
                  IsAkisi.sonuc => _Sonuclar(viewModel: viewModel),
                  _ => _Onizleme(viewModel: viewModel),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Onizleme extends StatelessWidget {
  const _Onizleme({required this.viewModel});

  final SesViewModel viewModel;

  Future<void> _duzelt(BuildContext context, int i) async {
    final yeni = await showDialog<IsOnerisi>(
      context: context,
      builder: (_) => _DuzeltDialog(oneri: viewModel.oneriler[i]),
    );
    if (yeni != null) viewModel.duzelt(i, yeni);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gonderiliyor = viewModel.akis == IsAkisi.uygulaniyor;
    final oneriler = viewModel.oneriler;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('Metinden çıkanlar', style: tema.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Henüz hiçbir şey eklenmedi. İşaretlediklerin eklenir; bir satıra dokunup düzeltebilirsin.',
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              if (oneriler.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Bu metinden eklenecek bir iş çıkmadı.', style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
                ),
              for (var i = 0; i < oneriler.length; i++)
                CheckboxListTile(
                  key: ValueKey('onizleme-$i'),
                  controlAffinity: ListTileControlAffinity.leading,
                  secondary: IconButton(
                    tooltip: 'Düzelt',
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(LucideIcons.pencil),
                    onPressed: gonderiliyor ? null : () => _duzelt(context, i),
                  ),
                  value: viewModel.seciliMi(i),
                  onChanged: gonderiliyor ? null : (_) => viewModel.secimiDegistir(i),
                  title: Text(oneriler[i].baslik),
                  subtitle: Text([
                    _ayrinti(oneriler[i]),
                    if (oneriler[i].eminDegil) 'Emin değil · %${(oneriler[i].guven! * 100).round()}',
                  ].join('\n')),
                  isThreeLine: oneriler[i].eminDegil,
                ),
              if (viewModel.atlananlar.isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text('Atlananlar', style: tema.textTheme.labelLarge),
                ),
                for (final a in viewModel.atlananlar)
                  ListTile(
                    dense: true,
                    leading: const Icon(LucideIcons.circleSlash),
                    title: Text(a.baslik ?? a.kaynakParca ?? 'Öneri'),
                    subtitle: Text(a.neden),
                  ),
              ],
            ],
          ),
        ),
        if (viewModel.hata != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(viewModel.hata!, style: TextStyle(color: tema.colorScheme.error)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: gonderiliyor || viewModel.seciliSayisi == 0 ? null : viewModel.uygula,
            child: gonderiliyor
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(viewModel.seciliSayisi == 0 ? 'Seçilenleri ekle' : 'Seçilenleri ekle (${viewModel.seciliSayisi})'),
          ),
        ),
      ],
    );
  }
}

class _Sonuclar extends StatelessWidget {
  const _Sonuclar({required this.viewModel});

  final SesViewModel viewModel;

  static String _durumMetni(IsUygulaSonucu? s) {
    if (s == null) return 'Sonuç bilinmiyor';
    return switch (s.durum) {
      IsUygulaSonucu.uygulandiDurumu => 'Eklendi',
      'izinYok' => 'Bunu yapma iznin yok',
      'gecersiz' => 'Geçersiz, eklenmedi',
      _ => 'Eklenemedi',
    };
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final satirlar = viewModel.sonucSatirlari;
    final basarili = satirlar.where((s) => s.sonuc?.uygulandi ?? false).length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            viewModel.sonucBilinmiyor ? 'Sunucudan yanıt gelmedi' : '$basarili / ${satirlar.length} eklendi',
            style: tema.textTheme.titleMedium,
          ),
        ),
        if (viewModel.sonucBilinmiyor)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Bağlantı koptu; bazıları eklenmiş olabilir. Onay kuyruğundaki "Son uygulananlar" listesine bak, sonra gerekirse tekrar dene.',
              style: TextStyle(color: tema.colorScheme.error),
            ),
          ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (:oneri, :sonuc) in satirlar)
                ListTile(
                  leading: Icon(
                    sonuc == null ? LucideIcons.circleQuestionMark : (sonuc.uygulandi ? LucideIcons.circleCheck : LucideIcons.circleX),
                    color: sonuc == null || !sonuc.uygulandi ? tema.colorScheme.error : null,
                  ),
                  title: Text(oneri.baslik),
                  subtitle: Text([
                    _durumMetni(sonuc),
                    if (sonuc?.mesaj != null && !sonuc!.uygulandi) sonuc.mesaj!,
                  ].join(' · ')),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ),
      ],
    );
  }
}

/// Corrects one suggestion: the title, the day and time (reminder, plan) or the due date (task).
class _DuzeltDialog extends StatefulWidget {
  const _DuzeltDialog({required this.oneri});

  final IsOnerisi oneri;

  @override
  State<_DuzeltDialog> createState() => _DuzeltDialogState();
}

class _DuzeltDialogState extends State<_DuzeltDialog> {
  late final _baslik = TextEditingController(text: widget.oneri.baslik);
  late String? _gun = widget.oneri.gun;
  late String? _saat = widget.oneri.saat;
  late String? _bitis = widget.oneri.bitis;

  bool get _gorev => widget.oneri.tur == IsOnerisi.gorev;
  bool get _saatVar => widget.oneri.tur == IsOnerisi.hatirlatici;

  /// A reminder and a plan item must have a day; a task needs none.
  bool get _kaydedilebilir => _baslik.text.trim().isNotEmpty && (_gorev || _gun != null);

  @override
  void dispose() {
    _baslik.dispose();
    super.dispose();
  }

  Future<String?> _tarihSec(String? simdiki) async {
    final bugun = DateTime.now();
    final secilen = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(simdiki ?? '') ?? bugun,
      firstDate: DateTime(bugun.year - 1),
      lastDate: DateTime(bugun.year + 5),
    );
    return secilen == null ? simdiki : tarihMetni(secilen);
  }

  Future<void> _saatSec() async {
    final parcalar = (_saat ?? '').split(':');
    final simdi = TimeOfDay.now();
    final secilen = await showTimePicker(
      context: context,
      initialTime: parcalar.length == 2
          ? TimeOfDay(hour: int.tryParse(parcalar[0]) ?? simdi.hour, minute: int.tryParse(parcalar[1]) ?? simdi.minute)
          : simdi,
    );
    if (secilen == null) return;
    setState(() => _saat = '${secilen.hour.toString().padLeft(2, '0')}:${secilen.minute.toString().padLeft(2, '0')}');
  }

  Widget _alan({
    required String etiket,
    required String? deger,
    required String bos,
    required VoidCallback sec,
    VoidCallback? temizle,
    required IconData ikon,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), alignment: Alignment.centerLeft),
            onPressed: sec,
            icon: Icon(ikon),
            label: Text(deger == null ? bos : '$etiket: $deger', overflow: TextOverflow.ellipsis),
          ),
        ),
        if (temizle != null && deger != null)
          IconButton(
            tooltip: '$etiket kaldır',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(LucideIcons.x),
            onPressed: temizle,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${_TurBilgisi.of(widget.oneri.tur).ad} düzelt'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _baslik,
              autofocus: true,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Başlık'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (!_gorev)
              _alan(
                etiket: 'Gün',
                deger: _gun,
                bos: 'Gün seç',
                ikon: LucideIcons.calendar,
                sec: () async {
                  final yeni = await _tarihSec(_gun);
                  if (mounted) setState(() => _gun = yeni);
                },
              ),
            if (_saatVar) ...[
              const SizedBox(height: 8),
              _alan(
                etiket: 'Saat',
                deger: _saat,
                bos: 'Saat seç (isteğe bağlı)',
                ikon: LucideIcons.clock,
                sec: _saatSec,
                temizle: () => setState(() => _saat = null),
              ),
            ],
            if (_gorev)
              _alan(
                etiket: 'Bitiş',
                deger: _bitis,
                bos: 'Bitiş tarihi (isteğe bağlı)',
                ikon: LucideIcons.calendar,
                sec: () async {
                  final yeni = await _tarihSec(_bitis);
                  if (mounted) setState(() => _bitis = yeni);
                },
                temizle: () => setState(() => _bitis = null),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: _kaydedilebilir
              ? () => Navigator.of(context).pop(widget.oneri.duzelt(baslik: _baslik.text.trim(), gun: _gun, saat: _saat, bitis: _bitis))
              : null,
          child: const Text('Tamam'),
        ),
      ],
    );
  }
}
