import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/aliskanlik.dart';
import '../../data/models/enums.dart';
import '../../utils/dogrulama.dart';
import '../core/ikonlar.dart';
import '../core/renkler.dart';
import '../core/widgets.dart';
import 'aliskanlik_form_view_model.dart';

const _gunEtiketleri = {
  HaftaGunu.pzt: 'Pzt',
  HaftaGunu.sal: 'Sal',
  HaftaGunu.car: 'Çar',
  HaftaGunu.per: 'Per',
  HaftaGunu.cum: 'Cum',
  HaftaGunu.cmt: 'Cmt',
  HaftaGunu.paz: 'Paz',
};

/// Habit form. A new habit starts with the Sayaç / Raf choice; the fields
/// below depend on it. Validation repeats the API rules (M05).
class AliskanlikFormScreen extends StatefulWidget {
  const AliskanlikFormScreen({super.key, required this.viewModel});

  final AliskanlikFormViewModel viewModel;

  @override
  State<AliskanlikFormScreen> createState() => _AliskanlikFormScreenState();
}

class _AliskanlikFormScreenState extends State<AliskanlikFormScreen> {
  final _form = GlobalKey<FormState>();
  final _ad = TextEditingController();
  final _hedef = TextEditingController();
  final _birim = TextEditingController();
  final _ogeEtiketi = TextEditingController(text: 'Kitap');
  final _altBaslikEtiketi = TextEditingController(text: 'Yazar');
  final _haftalikSayi = TextEditingController(text: '3');

  var _tur = AliskanlikTuru.sayac;
  var _olcu = Olcu.sayili;
  var _yon = HedefYonu.enAz;
  var _siklik = Siklik.herGun;
  var _ikon = varsayilanIkon;
  var _renk = varsayilanRenk;
  final _gunler = <HaftaGunu>{};
  String? _gunHatasi;
  bool _dolduruldu = false;

  AliskanlikFormViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    for (final c in [_ad, _hedef, _birim, _ogeEtiketi, _altBaslikEtiketi, _haftalikSayi]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fills the fields once, when the habit being edited has arrived.
  void _doldur(Aliskanlik a) {
    _dolduruldu = true;
    _ad.text = a.ad;
    _tur = a.tur;
    _olcu = a.olcu;
    _yon = a.hedefYonu;
    _hedef.text = sayiMetni(a.gunlukHedef);
    _birim.text = a.birim ?? '';
    _ogeEtiketi.text = a.ogeEtiketi ?? '';
    _altBaslikEtiketi.text = a.altBaslikEtiketi ?? '';
    _siklik = a.siklik;
    _haftalikSayi.text = a.haftalikSayi?.toString() ?? '3';
    _gunler
      ..clear()
      ..addAll(a.gunler ?? const []);
    _ikon = a.ikon;
    _renk = a.renk;
  }

  bool get _raf => _tur == AliskanlikTuru.raf;
  bool get _sayili => _raf || _olcu == Olcu.sayili;

  Future<void> _kaydet() async {
    final gunHatasi = _siklik == Siklik.belirliGunler && _gunler.isEmpty ? 'En az bir gün seç.' : null;
    setState(() => _gunHatasi = gunHatasi);
    if (!_form.currentState!.validate() || gunHatasi != null) return;

    String? bos(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final yaz = AliskanlikYaz(
      id: _vm.duzenleme ? _vm.duzenlenenId : const Uuid().v7(),
      ad: _ad.text.trim(),
      tur: _tur,
      ikon: _ikon,
      renk: _renk,
      olcu: _sayili ? Olcu.sayili : Olcu.evetHayir,
      hedefYonu: _raf ? HedefYonu.enAz : _yon,
      gunlukHedef: _sayili ? sayiCoz(_hedef.text) : null,
      birim: _sayili ? bos(_birim) : null,
      ogeEtiketi: _raf ? bos(_ogeEtiketi) : null,
      altBaslikEtiketi: _raf ? bos(_altBaslikEtiketi) : null,
      siklik: _siklik,
      haftalikSayi: _siklik == Siklik.haftadaN ? int.parse(_haftalikSayi.text.trim()) : null,
      gunler: _siklik == Siklik.belirliGunler
          ? (HaftaGunu.values.where(_gunler.contains).toList())
          : null,
      sira: _vm.mevcut?.sira ?? 0,
      arsivlendi: _vm.mevcut?.arsivlendi ?? false,
    );
    if (await _vm.kaydet(yaz) && mounted) {
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
        return Scaffold(
          appBar: AppBar(title: Text(_vm.duzenleme ? 'Alışkanlığı düzenle' : 'Yeni alışkanlık')),
          body: _vm.yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : (_vm.duzenleme && _vm.mevcut == null)
                  ? BosDurum(metin: _vm.hata ?? 'Alışkanlık bulunamadı.', dugme: 'Tekrar dene', onPressed: _vm.yukle)
                  : OrtaGenislik(child: _formu(context)),
        );
      },
    );
  }

  Widget _formu(BuildContext context) {
    final tema = Theme.of(context);
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_vm.duzenleme) ...[
            SegmentedButton<AliskanlikTuru>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: AliskanlikTuru.sayac, label: Text('Sayaç')),
                ButtonSegment(value: AliskanlikTuru.raf, label: Text('Raf')),
              ],
              selected: {_tur},
              onSelectionChanged: (s) => setState(() {
                _tur = s.first;
                if (_raf) {
                  _olcu = Olcu.sayili;
                  _yon = HedefYonu.enAz;
                }
              }),
            ),
            const SizedBox(height: 4),
            Text(
              _raf
                  ? 'Raf: kitap, dizi, kurs gibi öğeleri olan alışkanlık; her gün "nereye kadar geldin" girilir.'
                  : 'Sayaç: su, meditasyon, kahve gibi günlük sayılan alışkanlık.',
              style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _ad,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Ad'),
            validator: (v) => zorunluMetin(v, 'Ad', max: 100),
          ),
          const SizedBox(height: 16),
          Text('İkon', style: tema.textTheme.titleSmall),
          const SizedBox(height: 8),
          _IkonSecici(secili: _ikon, onSecildi: (k) => setState(() => _ikon = k)),
          const SizedBox(height: 16),
          Text('Renk', style: tema.textTheme.titleSmall),
          const SizedBox(height: 8),
          _RenkSecici(secili: _renk, onSecildi: (k) => setState(() => _renk = k)),
          const SizedBox(height: 16),
          if (!_raf) ...[
            SegmentedButton<Olcu>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Olcu.evetHayir, label: Text('Evet / hayır')),
                ButtonSegment(value: Olcu.sayili, label: Text('Sayılı')),
              ],
              selected: {_olcu},
              onSelectionChanged: (s) => setState(() {
                _olcu = s.first;
                if (_olcu == Olcu.evetHayir) _yon = HedefYonu.enAz;
              }),
            ),
            const SizedBox(height: 16),
          ],
          if (_sayili) ...[
            if (!_raf) ...[
              SegmentedButton<HedefYonu>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: HedefYonu.enAz, label: Text('En az (iyi alışkanlık)')),
                  ButtonSegment(value: HedefYonu.enCok, label: Text('En çok (sınır)')),
                ],
                selected: {_yon},
                onSelectionChanged: (s) => setState(() => _yon = s.first),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hedef,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(labelText: 'Günlük hedef'),
                    validator: (v) => hedefDogrula(v, _raf ? HedefYonu.enAz : _yon),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _birim,
                    decoration: const InputDecoration(labelText: 'Birim', hintText: 'bardak, sayfa, dakika'),
                    validator: (v) => zorunluMetin(v, 'Birim', max: 30),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_raf) ...[
            TextFormField(
              controller: _ogeEtiketi,
              decoration: const InputDecoration(labelText: 'Öğe adı', hintText: 'Kitap, Dizi, Kurs'),
              validator: (v) => zorunluMetin(v, 'Öğe adı', max: 30),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _altBaslikEtiketi,
              decoration: const InputDecoration(labelText: 'Alt başlık adı (isteğe bağlı)', hintText: 'Yazar'),
            ),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<Siklik>(
            initialValue: _siklik,
            decoration: const InputDecoration(labelText: 'Sıklık'),
            items: const [
              DropdownMenuItem(value: Siklik.herGun, child: Text('Her gün')),
              DropdownMenuItem(value: Siklik.haftadaN, child: Text('Haftada N gün')),
              DropdownMenuItem(value: Siklik.belirliGunler, child: Text('Belirli günler')),
            ],
            onChanged: (s) => setState(() => _siklik = s!),
          ),
          if (_siklik == Siklik.haftadaN) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _haftalikSayi,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Haftada kaç gün (1-6)'),
              validator: haftalikSayiDogrula,
            ),
          ],
          if (_siklik == Siklik.belirliGunler) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final g in HaftaGunu.values)
                  FilterChip(
                    label: Text(_gunEtiketleri[g]!),
                    selected: _gunler.contains(g),
                    onSelected: (v) => setState(() {
                      v ? _gunler.add(g) : _gunler.remove(g);
                      _gunHatasi = null;
                    }),
                  ),
              ],
            ),
            if (_gunHatasi != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_gunHatasi!, style: TextStyle(color: tema.colorScheme.error)),
              ),
          ],
          if (_vm.hata != null) ...[
            const SizedBox(height: 16),
            Text(_vm.hata!, style: TextStyle(color: tema.colorScheme.error)),
          ],
          const SizedBox(height: 24),
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

class _IkonSecici extends StatelessWidget {
  const _IkonSecici({required this.secili, required this.onSecildi});

  final String secili;
  final ValueChanged<String> onSecildi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final MapEntry(:key, :value) in ikonlar.entries)
          Semantics(
            label: key,
            selected: key == secili,
            button: true,
            child: InkWell(
              onTap: () => onSecildi(key),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: key == secili ? tema.primary.withValues(alpha: 0.16) : null,
                  border: Border.all(color: key == secili ? tema.primary : tema.outlineVariant, width: key == secili ? 2 : 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(value, color: key == secili ? tema.primary : tema.onSurface),
              ),
            ),
          ),
      ],
    );
  }
}

class _RenkSecici extends StatelessWidget {
  const _RenkSecici({required this.secili, required this.onSecildi});

  final String secili;
  final ValueChanged<String> onSecildi;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final MapEntry(:key, :value) in renkAnahtarlari.entries)
          Semantics(
            label: key,
            selected: key == secili,
            button: true,
            child: InkWell(
              onTap: () => onSecildi(key),
              customBorder: const CircleBorder(),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: key == secili
                      ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                      : null,
                ),
                child: CircleAvatar(radius: 16, backgroundColor: value),
              ),
            ),
          ),
      ],
    );
  }
}
