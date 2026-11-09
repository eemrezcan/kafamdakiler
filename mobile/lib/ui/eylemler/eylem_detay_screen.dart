import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/models/eylem.dart';
import '../../data/repositories/kullanici_repository.dart';
import '../../utils/eylem_gorunum.dart';
import '../core/widgets.dart';
import 'eylem_detay_view_model.dart';

/// One action: summary, source, reason, confidence and the payload as JSON. For a waiting action the Sahip can correct
/// the payload before approving, or reject it (with "bir daha önerme" to forbid its kind for good).
class EylemDetayScreen extends StatefulWidget {
  const EylemDetayScreen({super.key, required this.viewModel});

  final EylemDetayViewModel viewModel;

  @override
  State<EylemDetayScreen> createState() => _EylemDetayScreenState();
}

class _EylemDetayScreenState extends State<EylemDetayScreen> {
  final _yuk = TextEditingController();
  bool _doldu = false;
  bool _birDahaOnerme = false;
  String? _hata;

  EylemDetayViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_yukDoldur);
    _yukDoldur();
  }

  // The text box is filled once, when the action arrives; later changes of the list must not overwrite what is typed.
  void _yukDoldur() {
    if (_doldu || !_vm.yuklendi) return;
    _doldu = true;
    _yuk.text = _vm.ilkYuk;
  }

  @override
  void dispose() {
    _vm.removeListener(_yukDoldur);
    _yuk.dispose();
    super.dispose();
  }

  Future<void> _uygula() async {
    final hata = await _vm.uygula(_yuk.text);
    if (!mounted) return;
    if (hata != null) {
      setState(() => _hata = hata);
      return;
    }
    context.pop();
  }

  Future<void> _reddet() async {
    await _vm.reddet(birDahaOnerme: _birDahaOnerme);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final sahip = context.watch<KullaniciRepository>().sahip;
    return Scaffold(
      appBar: AppBar(title: const Text('Eylem')),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          if (!_vm.yuklendi) return const YuklemeIskeleti(adet: 2, yukseklik: 120);
          final e = _vm.eylem;
          if (e == null) return const BosDurum(metin: 'Eylem bulunamadı; kararlanmış ve listeden kalkmış olabilir.');
          final tema = Theme.of(context);
          final soluk = tema.colorScheme.onSurfaceVariant;
          final bekliyor = e.durum == EylemDurumu.bekliyor;
          return OrtaGenislik(
            child: ListView(
              padding: listeKenarlari(ust: 12),
              children: [
                Text(e.ozet, style: tema.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(e.turAdi, style: TextStyle(color: tema.colorScheme.primary)),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _Satir('Durum', _durumMetni(e.durum)),
                      _Satir('Kaynak', eylemKaynakAdi(e.kaynak) + (e.disKaynak ? ' (dış kaynak)' : '')),
                      if (e.guven != null) _Satir('Güven', eylemGuvenMetni(e.guven!) + (e.eminDegil ? ' (emin değil)' : '')),
                      _Satir('Önerildi', DateFormat('d MMMM HH:mm', 'tr').format(e.createdAt.toLocal())),
                      if (e.gerekce != null) ...[
                        _Satir('Gerekçe', eylemGerekcesi(e.gerekce!).metin),
                        if (eylemGerekcesi(e.gerekce!).mail case final mail?)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 100, bottom: 4),
                              child: TextButton.icon(
                                onPressed: () => launchUrl(mail, mode: LaunchMode.externalApplication),
                                icon: const Icon(LucideIcons.externalLink, size: 18),
                                label: const Text('Mailde aç'),
                              ),
                            ),
                          ),
                      ],
                      if (e.hataMesaji != null) _Satir('Hata', e.hataMesaji!),
                    ],
                  ),
                ),
                if (e.disKaynak)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Bu öneri başkasının yazdığı bir metinden çıkarıldı; kendiliğinden uygulanmaz. Uygulamadan önce yükü kontrol et.',
                      style: TextStyle(fontSize: 12, color: tema.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Yük', style: tema.textTheme.titleSmall),
                const SizedBox(height: 6),
                if (bekliyor && sahip) ...[
                  Text('Uygulamadan önce düzeltebilirsin; sunucu yeniden doğrular.', style: TextStyle(fontSize: 12, color: soluk)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _yuk,
                    maxLines: null,
                    minLines: 6,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    keyboardType: TextInputType.multiline,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(border: const OutlineInputBorder(), errorText: _hata),
                    onChanged: (_) {
                      if (_hata != null) setState(() => _hata = null);
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: _uygula,
                    icon: const Icon(LucideIcons.check),
                    label: const Text('Uygula'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bir daha önerme'),
                    subtitle: const Text('Reddedince bu türü kalıcı olarak yasaklar.'),
                    value: _birDahaOnerme,
                    onChanged: (v) => setState(() => _birDahaOnerme = v),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: _reddet,
                    icon: const Icon(LucideIcons.x),
                    label: const Text('Reddet'),
                  ),
                ] else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: tema.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(eylemYukMetni(e.yuk), style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _durumMetni(EylemDurumu d) => switch (d) {
        EylemDurumu.bekliyor => 'Bekliyor',
        EylemDurumu.uygulandi => 'Uygulandı',
        EylemDurumu.reddedildi => 'Reddedildi',
        EylemDurumu.geriAlindi => 'Geri alındı',
        EylemDurumu.hatali => 'Hatalı',
      };
}

class _Satir extends StatelessWidget {
  const _Satir(this.etiket, this.deger);

  final String etiket;
  final String deger;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(etiket, style: TextStyle(color: tema.colorScheme.onSurfaceVariant))),
          Expanded(child: Text(deger)),
        ],
      ),
    );
  }
}
