import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/yakala_girdisi.dart';
import '../../data/models/ses.dart';
import '../core/widgets.dart';
import 'is_onizleme_sheet.dart';
import 'ses_view_model.dart';
import 'yakala_view_model.dart';

/// Quick capture: the keyboard is ready on open, Save writes to the phone and
/// clears the form for the next thought (the screen stays). With a view model
/// in edit mode the same form changes a capture that still waits, then closes.
class YakalaScreen extends StatefulWidget {
  const YakalaScreen({super.key, required this.viewModel, this.sesViewModel, this.fotografSecici, this.baslangic});

  final YakalaViewModel viewModel;

  /// Dictation and the voice tools (K2.4); without it the form has none (the edit of a waiting capture).
  final SesViewModel? sesViewModel;

  /// Text and photo shared from another app (new captures only).
  final YakalaGirdisi? baslangic;

  /// Replaces the camera/gallery in tests.
  final Future<String?> Function(ImageSource kaynak)? fotografSecici;

  @override
  State<YakalaScreen> createState() => _YakalaScreenState();
}

class _YakalaScreenState extends State<YakalaScreen> {
  static const _metinSiniri = 5000;

  final _form = GlobalKey<FormState>();
  final _metin = TextEditingController();
  final _odak = FocusNode();
  bool _dolduruldu = false;

  /// Several images were shared and only the first was taken.
  bool _cokluGorselNotu = false;

  /// A photo picked in this form (path of the picker's file).
  String? _yeniFotograf;

  /// Edit mode: the photo the capture had was removed.
  bool _fotografKaldirildi = false;

  YakalaViewModel get _vm => widget.viewModel;
  SesViewModel? get _ses => widget.sesViewModel;

  @override
  void initState() {
    super.initState();
    // The phone's copy of the project list: opening the screen makes no network call.
    _vm.projeleriYukle();
    final baslangic = widget.baslangic;
    if (baslangic != null && !_vm.duzenleme) {
      _metin.text = baslangic.metin ?? '';
      _yeniFotograf = baslangic.fotografYolu;
      _cokluGorselNotu = baslangic.cokluGorsel;
    }
  }

  bool get _fotografVar =>
      _yeniFotograf != null ||
      (!_fotografKaldirildi && (_vm.mevcut?.fotografId != null || _vm.mevcut?.fotografYolu != null));

  /// Something would be lost if the screen closed now: typed text or a picked photo (a new capture), or a changed text
  /// or photo (an edit).
  bool get _kaybolacakVar {
    final mevcut = _vm.mevcut;
    if (_vm.duzenleme) {
      return mevcut != null && (_metin.text != (mevcut.metin ?? '') || _yeniFotograf != null || _fotografKaldirildi);
    }
    return _metin.text.trim().isNotEmpty || _yeniFotograf != null;
  }

  Future<void> _geriTusu(bool popOldu) async {
    if (popOldu) return;
    final vazgec = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vazgeçilsin mi?'),
        content: const Text('Yazdıkların kaydedilmeden silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Yazmaya devam et')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Vazgeç')),
        ],
      ),
    );
    if (vazgec == true && mounted) Navigator.of(context).pop();
  }

  bool get _kaydedilebilir => _metin.text.trim().isNotEmpty || _fotografVar;

  @override
  void dispose() {
    _metin.dispose();
    _odak.dispose();
    super.dispose();
  }

  Future<void> _fotografSec(ImageSource kaynak) async {
    try {
      final yol = widget.fotografSecici != null
          ? await widget.fotografSecici!(kaynak)
          : (await ImagePicker().pickImage(source: kaynak, maxWidth: 1600, imageQuality: 85))?.path;
      if (yol != null) {
        setState(() {
          _yeniFotograf = yol;
          _fotografKaldirildi = false;
        });
        _vm.hatayiTemizle();
      }
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf alınamadı. Kamera ya da galeri iznini kontrol et.')),
      );
    }
  }

  /// Dictation streams the whole field text; the cursor stays at the end.
  void _dikteMetni(String metin) {
    _metin.value = TextEditingValue(text: metin, selection: TextSelection.collapsed(offset: metin.length));
    _vm.hatayiTemizle();
    setState(() {});
  }

  Future<void> _dikteyiDegistir() async {
    final ses = _ses!;
    if (ses.dinliyor) {
      await ses.dikteDurdur();
    } else {
      await ses.dikteBaslat(temel: _metin.text, metinDegisti: _dikteMetni);
    }
  }

  Future<void> _iseCevir() async {
    final ses = _ses!;
    await ses.dikteDurdur();
    await ses.isCikar(_metin.text);
    if (!mounted || ses.akis != IsAkisi.onizleme) return;
    await isOnizlemesiniGoster(context, ses);
  }

  Future<void> _yenidenYaz(YenidenYazKipi kip) async {
    final ses = _ses!;
    await ses.dikteDurdur();
    final yeni = await ses.yenidenYaz(_metin.text, kip);
    if (yeni == null || !mounted) return;
    final kabul = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(kip.ad),
        content: SingleChildScrollView(child: SelectableText(yeni)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Metnin yerine koy')),
        ],
      ),
    );
    if (kabul == true && mounted) setState(() => _metin.text = yeni);
  }

  Future<void> _kaydet() async {
    await _ses?.dikteDurdur();
    if (!_form.currentState!.validate()) return;
    final kaydedildi = await _vm.kaydet(
      metin: _metin.text,
      fotografKaynagi: _yeniFotograf,
      fotografKaldir: _fotografKaldirildi,
    );
    if (!kaydedildi || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
    if (_vm.duzenleme) {
      context.pop();
    } else {
      // Ready for the next thought.
      setState(() {
        _metin.clear();
        _yeniFotograf = null;
        _cokluGorselNotu = false;
      });
      _odak.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_vm, ?_ses]),
      builder: (context, _) {
        final mevcut = _vm.mevcut;
        if (mevcut != null && !_dolduruldu) {
          _dolduruldu = true;
          _metin.text = mevcut.metin ?? '';
        }
        return PopScope(
          canPop: !_kaybolacakVar,
          onPopInvokedWithResult: (popOldu, _) => _geriTusu(popOldu),
          child: Scaffold(
            appBar: AppBar(title: Text(_vm.duzenleme ? 'Yakalamayı düzenle' : 'Yakala')),
            body: _vm.yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : (_vm.duzenleme && mevcut == null)
                    ? BosDurum(metin: _vm.hata ?? 'Kayıt bulunamadı.')
                    : OrtaGenislik(child: _formu(context)),
          ),
        );
      },
    );
  }

  Widget _fotograf(BuildContext context) {
    final mevcut = _vm.mevcut;
    final Widget resim;
    if (_yeniFotograf != null) {
      resim = Image.file(File(_yeniFotograf!), fit: BoxFit.cover);
    } else if (!_fotografKaldirildi && mevcut?.fotografYolu != null) {
      resim = Image.file(File(mevcut!.fotografYolu!), fit: BoxFit.cover);
    } else if (!_fotografKaldirildi && mevcut?.fotografId != null) {
      resim = ApiResim(dosyaId: mevcut!.fotografId);
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: double.infinity, height: 200, child: resim),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filledTonal(
              tooltip: 'Fotoğrafı kaldır',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(LucideIcons.x),
              onPressed: () => setState(() {
                _yeniFotograf = null;
                _fotografKaldirildi = true;
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// Dictation (works on the phone) and the tools that need the server: turn the text into work, summarize, bullet.
  Widget _sesAraclari(BuildContext context, SesViewModel ses) {
    final tema = Theme.of(context);
    final soluk = TextStyle(color: tema.colorScheme.onSurfaceVariant);
    final metinVar = _metin.text.trim().isNotEmpty;
    final calisiyor = ses.akis == IsAkisi.yukleniyor || ses.yenidenYaziliyor;
    // The server tools need a connection, some text and no other call running.
    final sunucuIsi = ses.cevrimici && metinVar && !calisiyor;
    const dar = Size(48, 48);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (ses.dinliyor)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: dar),
                onPressed: _dikteyiDegistir,
                icon: const Icon(LucideIcons.micOff),
                label: const Text('Durdur'),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: dar),
                onPressed: _dikteyiDegistir,
                icon: const Icon(LucideIcons.mic),
                label: const Text('Dikte'),
              ),
            // These three call Claude: hidden while the assistant is not connected on the server.
            if (ses.asistanBagli) ...[
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: dar),
                onPressed: sunucuIsi ? _iseCevir : null,
                icon: ses.akis == IsAkisi.yukleniyor
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.sparkles),
                label: const Text('İşe çevir'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: dar),
                onPressed: sunucuIsi ? () => _yenidenYaz(YenidenYazKipi.ozet) : null,
                icon: const Icon(LucideIcons.textAlignStart),
                label: const Text('Özetle'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: dar),
                onPressed: sunucuIsi ? () => _yenidenYaz(YenidenYazKipi.madde) : null,
                icon: const Icon(LucideIcons.list),
                label: const Text('Maddele'),
              ),
            ],
          ],
        ),
        if (ses.dinliyor)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Dinliyorum… konuşmayı bitirince durur.', style: soluk)),
        if (calisiyor)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Asistan çalışıyor…', style: soluk)),
        if (!ses.cevrimici && ses.asistanBagli)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Çevrimdışısın: İşe çevir, Özetle ve Maddele internet ister. Metni yine de Kaydet ile yakalayabilirsin.',
              style: soluk,
            ),
          ),
        if (ses.dikteMesaji != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(ses.dikteMesaji!, style: TextStyle(color: tema.colorScheme.error)),
          ),
        // While the preview is open it shows its own errors.
        if (ses.hata != null && ses.akis == IsAkisi.yok)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(ses.hata!, style: TextStyle(color: tema.colorScheme.error)),
          ),
      ],
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
            controller: _metin,
            focusNode: _odak,
            autofocus: !_vm.duzenleme,
            // Dictation rewrites the whole text on every result, so typing in between would be lost.
            readOnly: _ses?.dinliyor ?? false,
            minLines: 4,
            maxLines: 10,
            maxLength: _metinSiniri,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Aklında ne var?',
              alignLabelWithHint: true,
            ),
            // The counter is noise for a quick thought; it shows up only near the limit.
            buildCounter: (context, {required currentLength, required isFocused, required maxLength}) =>
                currentLength > _metinSiniri - 500 ? Text('$currentLength/$maxLength') : null,
            validator: (v) => (v ?? '').length > _metinSiniri ? 'Metin en çok $_metinSiniri karakter olabilir.' : null,
            onChanged: (_) {
              _vm.hatayiTemizle();
              setState(() {});
            },
          ),
          if (_cokluGorselNotu)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Birden çok görsel paylaşıldı; yalnız ilki alındı.'),
            ),
          const SizedBox(height: 8),
          if (_ses != null) ...[
            _sesAraclari(context, _ses!),
            const SizedBox(height: 8),
          ],
          if (_vm.projeSecici) ...[
            _ProjeSecici(viewModel: _vm),
            const SizedBox(height: 8),
          ],
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
          _fotograf(context),
          if (_vm.hata != null) ...[
            const SizedBox(height: 8),
            Text(_vm.hata!, style: TextStyle(color: tema.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            // Text or photo: the same rule as the server, so an empty save is not offered at all.
            onPressed: _vm.kaydediliyor || !_kaydedilebilir ? null : _kaydet,
            child: _vm.kaydediliyor
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

/// The optional project hint of a capture: a button that shows the picked project
/// (or "Proje seç") and opens the list kept on the phone, so it also works offline.
class _ProjeSecici extends StatelessWidget {
  const _ProjeSecici({required this.viewModel});

  final YakalaViewModel viewModel;

  static const _onEk = 'projects/';

  /// The project's title when the phone's list knows it, else its id.
  String _ad(String hedef) {
    final kimlik = hedef.startsWith(_onEk) ? hedef.substring(_onEk.length) : hedef;
    return viewModel.projeler.where((p) => p.kimlik == kimlik).firstOrNull?.baslik ?? kimlik;
  }

  Future<void> _ac(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _ProjeListesi(
        viewModel: viewModel,
        onSec: (hedef) {
          viewModel.hedefSec(hedef);
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final hedef = viewModel.hedef;
        return Row(
          children: [
            Flexible(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => _ac(context),
                icon: const Icon(LucideIcons.folder),
                label: Text(hedef == null ? 'Proje (isteğe bağlı)' : _ad(hedef), overflow: TextOverflow.ellipsis),
              ),
            ),
            if (hedef != null)
              IconButton(
                tooltip: 'Projeyi kaldır',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(LucideIcons.x),
                onPressed: () => viewModel.hedefSec(null),
              ),
          ],
        );
      },
    );
  }
}

class _ProjeListesi extends StatelessWidget {
  const _ProjeListesi({required this.viewModel, required this.onSec});

  final YakalaViewModel viewModel;
  final void Function(String? hedef) onSec;

  Future<void> _yenile(BuildContext context) async {
    final mesaj = ScaffoldMessenger.of(context);
    final tamam = await viewModel.projeleriYenile();
    if (!tamam) {
      mesaj.showSnackBar(const SnackBar(content: Text('Sunucuya ulaşılamadı; telefondaki liste gösteriliyor.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SafeArea(
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final projeler = viewModel.projeler;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  minTileHeight: 56,
                  leading: const Icon(LucideIcons.folderX),
                  title: const Text('Projesiz'),
                  trailing: viewModel.hedef == null ? const Icon(LucideIcons.check) : null,
                  onTap: () => onSec(null),
                ),
                for (final p in projeler)
                  ListTile(
                    minTileHeight: 56,
                    leading: const Icon(LucideIcons.folder),
                    title: Text(p.baslik),
                    subtitle: Text(p.kimlik),
                    trailing: viewModel.hedef == p.hedef ? const Icon(LucideIcons.check) : null,
                    onTap: () => onSec(p.hedef),
                  ),
                if (projeler.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'Telefonda proje listesi yok. İnternet varken "Listeyi yenile" ile al.',
                      style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => _yenile(context),
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('Listeyi yenile'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
