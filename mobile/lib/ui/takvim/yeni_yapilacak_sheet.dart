import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/models/beyin.dart';
import '../../data/models/gun_gorunum.dart';
import '../../data/models/hatirlatici.dart';
import '../../data/repositories/beyin_repository.dart';
import '../gun/gun_view_model.dart';
import '../gun/hatirlatici_alanlari.dart';

/// The "Yeni yapılacak" form of Takvim's ＋ button (K-0024): what, which day, an hour if it has one, the estimate, the
/// project, and the reminder switch. The row is kept on the phone and sent when there is a connection.
Future<void> yeniYapilacakAc(BuildContext context, {required GunViewModel viewModel, required DateTime tarih, required DateTime bugun}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => YeniYapilacakSayfasi(viewModel: viewModel, tarih: tarih, bugun: bugun),
  );
}

/// The estimate choices of the form, in minutes.
const tahminSecenekleri = [15, 30, 60, 120];

class YeniYapilacakSayfasi extends StatefulWidget {
  const YeniYapilacakSayfasi({super.key, required this.viewModel, required this.tarih, required this.bugun});

  final GunViewModel viewModel;

  /// The day the form starts on (the chosen day of Takvim; today when that is past).
  final DateTime tarih;
  final DateTime bugun;

  @override
  State<YeniYapilacakSayfasi> createState() => _YeniYapilacakSayfasiState();
}

class _YeniYapilacakSayfasiState extends State<YeniYapilacakSayfasi> {
  final _form = GlobalKey<FormState>();
  final _baslik = TextEditingController();
  late DateTime _gun = widget.tarih.isBefore(widget.bugun) ? widget.bugun : widget.tarih;
  TimeOfDay? _saat;
  int? _tahmin;
  String? _proje;
  var _hatirlatici = false;
  var _taslak = const HatirlaticiTaslagi();
  List<ProjeOzet> _projeler = const [];

  @override
  void initState() {
    super.initState();
    // The projects the phone knows (the capture picker's list); offline too.
    context.read<BeyinRepository>().yerelProjeler().then((p) {
      if (mounted) setState(() => _projeler = p);
    });
  }

  @override
  void dispose() {
    _baslik.dispose();
    super.dispose();
  }

  String get _saatMetni => _saat == null ? '—' : Saat(_saat!.hour, _saat!.minute).kisa;

  Future<void> _gunSec() async {
    final b = widget.bugun;
    final secilen = await showDatePicker(
      context: context,
      initialDate: DateTime(_gun.year, _gun.month, _gun.day),
      firstDate: DateTime(b.year, b.month, b.day),
      lastDate: DateTime(b.year + 2, b.month, b.day),
    );
    if (secilen != null) setState(() => _gun = DateTime.utc(secilen.year, secilen.month, secilen.day));
  }

  Future<void> _saatSec() async {
    final secilen = await showTimePicker(context: context, initialTime: _saat ?? const TimeOfDay(hour: 9, minute: 0), helpText: 'Saat');
    if (secilen != null) setState(() => _saat = secilen);
  }

  Future<void> _ekle() async {
    if (!_form.currentState!.validate()) return;
    final nav = Navigator.of(context);
    await widget.viewModel.ogeEkle(
      YeniOgeYaz(
        baslik: _baslik.text.trim(),
        saat: _saat == null ? null : Saat(_saat!.hour, _saat!.minute).kisa,
        tahminDk: _tahmin,
        proje: _proje,
        hatirlatici: _hatirlatici ? _taslak.govde() : null,
      ),
      tarih: _gun,
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Yeni yapılacak', style: tema.textTheme.titleLarge),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: tema.colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(LucideIcons.sparkles, size: 16, color: tema.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'İstersen Asistan\'a söyle: "cuma 10\'da diş randevusu, bir gün önce hatırlat"',
                        style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('yeni-baslik'),
                controller: _baslik,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Ne yapılacak?', hintText: 'örn. E-kampüsü kontrol et'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Bir şey yaz.' : ((v ?? '').trim().length > 200 ? 'En çok 200 karakter.' : null),
              ),
              const SizedBox(height: 4),
              ListTile(
                key: const ValueKey('yeni-gun'),
                contentPadding: EdgeInsets.zero,
                minTileHeight: 48,
                leading: const Icon(LucideIcons.calendar),
                title: const Text('Gün'),
                trailing: Text(DateFormat('d MMMM', 'tr').format(_gun), style: tema.textTheme.titleMedium),
                onTap: _gunSec,
              ),
              ListTile(
                key: const ValueKey('yeni-saat'),
                contentPadding: EdgeInsets.zero,
                minTileHeight: 48,
                leading: const Icon(LucideIcons.clock),
                title: const Text('Saat (isteğe bağlı)'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_saatMetni, style: tema.textTheme.titleMedium),
                    if (_saat != null)
                      IconButton(
                        tooltip: 'Saati kaldır',
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => setState(() => _saat = null),
                      ),
                  ],
                ),
                onTap: _saatSec,
              ),
              const SizedBox(height: 4),
              Text('Süre tahmini', style: tema.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final dk in tahminSecenekleri)
                    ChoiceChip(
                      key: ValueKey('tahmin-$dk'),
                      label: Text(sureMetni(dk)),
                      selected: _tahmin == dk,
                      onSelected: (s) => setState(() => _tahmin = s ? dk : null),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: const ValueKey('yeni-proje'),
                initialValue: _proje,
                decoration: const InputDecoration(labelText: 'Proje'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Yok')),
                  for (final p in _projeler) DropdownMenuItem(value: p.kimlik, child: Text(p.baslik, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _proje = v),
              ),
              SwitchListTile(
                key: const ValueKey('yeni-hatirlatici'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(LucideIcons.bell),
                title: const Text('Hatırlatıcı ekle'),
                value: _hatirlatici,
                onChanged: (v) => setState(() => _hatirlatici = v),
              ),
              if (_hatirlatici) HatirlaticiAlanlari(taslak: _taslak, varsayilanSaat: _saat == null ? null : _saatMetni, onDegisti: (t) => setState(() => _taslak = t)),
              const SizedBox(height: 16),
              FilledButton(key: const ValueKey('yeni-ekle'), onPressed: _ekle, child: const Text('Ekle')),
            ],
          ),
        ),
      ),
    );
  }
}
