import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/hatirlatici.dart';
import '../../utils/dogrulama.dart';
import '../../utils/hatirlatici_gorunum.dart';
import '../../utils/hatirlatici_hesap.dart';
import '../core/widgets.dart';
import 'hatirlatici_form_view_model.dart';

/// Add or edit a reminder. "Kime" shows only while the type is Söz; the day is required, the hour is optional
/// (empty means the default morning hour).
class HatirlaticiFormScreen extends StatefulWidget {
  const HatirlaticiFormScreen({super.key, required this.viewModel, this.simdi});

  final HatirlaticiFormViewModel viewModel;

  /// Replaces the clock in tests (the new form starts on today).
  final DateTime Function()? simdi;

  @override
  State<HatirlaticiFormScreen> createState() => _HatirlaticiFormScreenState();
}

class _HatirlaticiFormScreenState extends State<HatirlaticiFormScreen> {
  final _form = GlobalKey<FormState>();
  final _baslik = TextEditingController();
  final _kime = TextEditingController();
  final _not = TextEditingController();
  final _onceGun = TextEditingController(text: '0');

  HatirlaticiTuru _tur = HatirlaticiTuru.gorev;
  Tekrar _tekrar = Tekrar.yok;
  HatirlaticiDurumu _durum = HatirlaticiDurumu.acik;
  DateTime? _gun;
  Saat? _saat;
  bool _israrli = false;
  bool _acil = false;
  int _israrAraligi = varsayilanIsrarAraligi;
  int _israrEnCok = varsayilanIsrarEnCok;
  bool _gunHatasi = false;
  bool _dolduruldu = false;

  HatirlaticiFormViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    if (!_vm.duzenleme) _gun = istanbulGunu((widget.simdi ?? DateTime.now)());
  }

  @override
  void dispose() {
    _baslik.dispose();
    _kime.dispose();
    _not.dispose();
    _onceGun.dispose();
    super.dispose();
  }

  void _doldur(Hatirlatici h) {
    _dolduruldu = true;
    _baslik.text = h.baslik;
    _kime.text = h.kime ?? '';
    _not.text = h.not ?? '';
    _onceGun.text = '${h.onceGun}';
    _tur = h.tur;
    _tekrar = h.tekrar;
    _durum = h.durum;
    _gun = h.gun;
    _saat = h.saat;
    _israrli = h.israrli;
    _acil = h.acil;
    _israrAraligi = israrAraliklari.contains(h.israrAraligiDakika) ? h.israrAraligiDakika : varsayilanIsrarAraligi;
    _israrEnCok = h.israrEnCok;
  }

  Future<void> _gunSec() async {
    final bugun = istanbulGunu((widget.simdi ?? DateTime.now)());
    final secilen = await showDatePicker(
      context: context,
      initialDate: _gun ?? bugun,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (secilen != null) {
      setState(() {
        _gun = DateTime.utc(secilen.year, secilen.month, secilen.day);
        _gunHatasi = false;
      });
    }
  }

  Future<void> _saatSec() async {
    final varsayilan = _saat ?? varsayilanHatirlaticiSaati;
    final secilen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: varsayilan.saat, minute: varsayilan.dakika),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (secilen != null) setState(() => _saat = Saat(secilen.hour, secilen.minute));
  }

  Future<void> _kaydet() async {
    final gecerli = _form.currentState!.validate();
    setState(() => _gunHatasi = _gun == null);
    if (!gecerli || _gun == null) return;

    final kime = _kime.text.trim();
    final not = _not.text.trim();
    final kaydedildi = await _vm.kaydet(HatirlaticiYaz(
      baslik: _baslik.text.trim(),
      not: not.isEmpty ? null : not,
      tur: _tur,
      kime: _tur == HatirlaticiTuru.soz && kime.isNotEmpty ? kime : null,
      gun: _gun!,
      saat: _saat,
      tekrar: _tekrar,
      onceGun: int.tryParse(_onceGun.text.trim()) ?? 0,
      durum: _durum,
      israrli: _israrli,
      israrAraligiDakika: _israrAraligi,
      israrEnCok: _israrEnCok,
      acil: _acil,
    ));
    if (!kaydedildi || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
    context.pop();
  }

  Future<void> _sil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hatırlatıcı silinsin mi?'),
        content: const Text('Silmek geri alınamaz. Bitmiş bir hatırlatıcıyı silmek yerine durumunu Arşiv yapabilirsin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (onay != true) return;
    if (await _vm.sil() && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final mevcut = _vm.mevcut;
        if (mevcut != null && !_dolduruldu) _doldur(mevcut);
        return Scaffold(
          appBar: AppBar(
            title: Text(_vm.duzenleme ? 'Hatırlatıcıyı düzenle' : 'Yeni hatırlatıcı'),
            actions: [
              if (_vm.duzenleme && mevcut != null)
                IconButton(
                  tooltip: 'Sil',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(LucideIcons.trash2),
                  onPressed: _sil,
                ),
            ],
          ),
          body: _vm.yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : (_vm.duzenleme && mevcut == null)
                  ? BosDurum(metin: _vm.hata ?? 'Kayıt bulunamadı.')
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
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          TextFormField(
            controller: _baslik,
            autofocus: !_vm.duzenleme,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Başlık'),
            buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
            validator: (v) => zorunluMetin(v, 'Başlık'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<HatirlaticiTuru>(
            initialValue: _tur,
            decoration: const InputDecoration(labelText: 'Tür'),
            items: [
              for (final t in HatirlaticiTuru.values) DropdownMenuItem(value: t, child: Text(hatirlaticiTurAdi(t))),
            ],
            onChanged: (t) => setState(() => _tur = t!),
          ),
          if (_tur == HatirlaticiTuru.soz) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _kime,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Kime söz verdin?'),
              buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
              validator: kimeDogrula,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: _gunSec,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Gün',
                      errorText: _gunHatasi ? 'Gün zorunlu.' : null,
                      suffixIcon: const Icon(LucideIcons.calendar),
                    ),
                    child: Text(_gun == null ? 'Seç' : hatirlaticiGunu(_gun!)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _saatSec,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Saat',
                      helperText: 'Boşsa ${varsayilanHatirlaticiSaati.kisa}',
                      suffixIcon: _saat == null
                          ? const Icon(LucideIcons.clock)
                          : IconButton(
                              tooltip: 'Saati temizle',
                              icon: const Icon(LucideIcons.x),
                              onPressed: () => setState(() => _saat = null),
                            ),
                    ),
                    child: Text(_saat?.kisa ?? '—'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Tekrar>(
            initialValue: _tekrar,
            decoration: InputDecoration(
              labelText: 'Tekrar',
              // Only "Her ay" has the short-month rule to explain.
              helperText: _tekrar == Tekrar.aylik
                  ? "Ayın 31'inde başlayan aylık hatırlatıcı, kısa aylarda ayın son günü çalar."
                  : null,
              helperMaxLines: 2,
            ),
            items: [for (final t in Tekrar.values) DropdownMenuItem(value: t, child: Text(tekrarAdi(t)))],
            onChanged: (t) => setState(() => _tekrar = t!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _onceGun,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Kaç gün önce de haber verilsin?',
              helperText: '0 ise yalnız asıl günde haber verilir (en çok 60).',
            ),
            validator: onceGunDogrula,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Israrlı'),
            subtitle: Text('Yapılmazsa $_israrEnCok kez daha hatırlatır; Yaptım ya da Ertele deyince durur.'),
            value: _israrli,
            onChanged: (v) => setState(() => _israrli = v),
          ),
          if (_israrli)
            DropdownButtonFormField<int>(
              initialValue: _israrAraligi,
              decoration: const InputDecoration(labelText: 'Israr aralığı'),
              items: [for (final d in israrAraliklari) DropdownMenuItem(value: d, child: Text(d == 60 ? '1 saatte bir' : '$d dakikada bir'))],
              onChanged: (d) => setState(() => _israrAraligi = d!),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Acil'),
            subtitle: const Text('Sessiz modu deler; kilit ekranında tam ekran açılır.'),
            value: _acil,
            onChanged: (v) => setState(() => _acil = v),
          ),
          if (_vm.duzenleme) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<HatirlaticiDurumu>(
              initialValue: _durum,
              decoration: const InputDecoration(labelText: 'Durum'),
              items: [
                for (final d in HatirlaticiDurumu.values) DropdownMenuItem(value: d, child: Text(hatirlaticiDurumAdi(d))),
              ],
              onChanged: (d) => setState(() => _durum = d!),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _not,
            minLines: 3,
            maxLines: 8,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)', alignLabelWithHint: true),
            buildCounter: (context, {required currentLength, required isFocused, required maxLength}) =>
                currentLength > 1800 ? Text('$currentLength/$maxLength') : null,
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
