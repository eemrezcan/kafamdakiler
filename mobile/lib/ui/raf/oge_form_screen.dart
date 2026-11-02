import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/enums.dart';
import '../../data/models/oge.dart';
import '../../utils/dogrulama.dart';
import '../core/widgets.dart';
import 'oge_detay_screen.dart' show ogeDurumMetni;
import 'oge_form_view_model.dart';

class OgeFormScreen extends StatefulWidget {
  const OgeFormScreen({super.key, required this.viewModel});

  final OgeFormViewModel viewModel;

  @override
  State<OgeFormScreen> createState() => _OgeFormScreenState();
}

class _OgeFormScreenState extends State<OgeFormScreen> {
  final _form = GlobalKey<FormState>();
  final _ad = TextEditingController();
  final _altBaslik = TextEditingController();
  final _toplam = TextEditingController();
  final _baslangic = TextEditingController(text: '0');
  final _not = TextEditingController();
  var _durum = OgeDurumu.siradaki;
  int? _puan;
  String? _fotografYolu;
  bool _dolduruldu = false;

  OgeFormViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    for (final c in [_ad, _altBaslik, _toplam, _baslangic, _not]) {
      c.dispose();
    }
    super.dispose();
  }

  void _doldur(Oge o) {
    _dolduruldu = true;
    _ad.text = o.ad;
    _altBaslik.text = o.altBaslik ?? '';
    _toplam.text = sayiMetni(o.toplam);
    _baslangic.text = sayiMetni(o.baslangicKonumu);
    _not.text = o.not ?? '';
    _durum = o.durum;
    _puan = o.puan;
  }

  Future<void> _fotografSec(ImageSource kaynak) async {
    try {
      final dosya = await ImagePicker().pickImage(source: kaynak, maxWidth: 1600, imageQuality: 85);
      if (dosya != null) setState(() => _fotografYolu = dosya.path);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf alınamadı. Kamera ya da galeri iznini kontrol et.')),
      );
    }
  }

  Future<void> _kaydet() async {
    if (!_form.currentState!.validate()) return;
    String? bos(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final yaz = OgeYaz(
      id: _vm.duzenleme ? _vm.duzenlenenId : const Uuid().v7(),
      ad: _ad.text.trim(),
      altBaslik: bos(_altBaslik),
      toplam: sayiCoz(_toplam.text),
      baslangicKonumu: sayiCoz(_baslangic.text)!,
      fotografId: _vm.mevcut?.fotografId,
      durum: _durum,
      // The rating belongs to a finished item only (as on the web form).
      puan: _durum == OgeDurumu.bitti ? _puan : null,
      not: bos(_not),
    );
    if (await _vm.kaydet(yaz, fotografYolu: _fotografYolu) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.mevcut != null && !_dolduruldu) _doldur(_vm.mevcut!);
        final etiket = _vm.ogeEtiketi;
        return Scaffold(
          appBar: AppBar(title: Text(_vm.duzenleme ? '$etiket düzenle' : 'Yeni ${etiket.toLowerCase()}')),
          body: _vm.yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : (_vm.duzenleme && _vm.mevcut == null)
                  ? BosDurum(metin: _vm.hata ?? 'Kayıt bulunamadı.', dugme: 'Tekrar dene', onPressed: _vm.yukle)
                  : OrtaGenislik(child: _formu(context)),
        );
      },
    );
  }

  Widget _formu(BuildContext context) {
    final tema = Theme.of(context);
    final baslangic = sayiCoz(_baslangic.text) ?? 0;
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 120,
                    height: 172,
                    child: _fotografYolu != null
                        ? Image.file(File(_fotografYolu!), fit: BoxFit.cover)
                        : ApiResim(dosyaId: _vm.mevcut?.fotografId, yedekIkon: LucideIcons.image),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: () => _fotografSec(ImageSource.camera),
                      icon: const Icon(LucideIcons.camera),
                      label: const Text('Kamera'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: () => _fotografSec(ImageSource.gallery),
                      icon: const Icon(LucideIcons.image),
                      label: const Text('Galeri'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ad,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: '${_vm.ogeEtiketi} adı'),
            validator: (v) => zorunluMetin(v, 'Ad'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _altBaslik,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: '${_vm.altBaslikEtiketi} (isteğe bağlı)'),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _baslangic,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(
                    labelText: 'Kaldığın yer',
                    helperText: 'Yeni başlıyorsan 0 bırak.',
                  ),
                  validator: ogeBaslangicDogrula,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _toplam,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Toplam (isteğe bağlı)'),
                  validator: (v) => ogeToplamDogrula(v, baslangic),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<OgeDurumu>(
            initialValue: _durum,
            decoration: const InputDecoration(labelText: 'Hangi rafta?'),
            items: [
              for (final d in OgeDurumu.values) DropdownMenuItem(value: d, child: Text(ogeDurumMetni(d))),
            ],
            onChanged: (d) => setState(() => _durum = d!),
          ),
          if (_durum == OgeDurumu.bitti) ...[
            const SizedBox(height: 16),
            Text('Kaç puan verdin? (isteğe bağlı)', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var p = 1; p <= 5; p++)
                  ChoiceChip(
                    label: Text('$p'),
                    selected: _puan == p,
                    onSelected: (v) => setState(() => _puan = v ? p : null),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _not,
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)', alignLabelWithHint: true),
            validator: notDogrula,
          ),
          if (_vm.hata != null) ...[
            const SizedBox(height: 8),
            Text(_vm.hata!, style: TextStyle(color: tema.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _vm.kaydediliyor ? null : _kaydet,
            child: _vm.kaydediliyor
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
