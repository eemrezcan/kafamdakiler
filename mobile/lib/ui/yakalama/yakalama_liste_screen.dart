import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_theme.dart';
import '../../data/models/yakalama.dart';
import '../core/widgets.dart';
import 'yakalama_liste_view_model.dart';

class YakalamaListeScreen extends StatelessWidget {
  const YakalamaListeScreen({super.key, required this.viewModel});

  final YakalamaListeViewModel viewModel;

  Future<void> _sil(BuildContext context, YakalamaSatiri s) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yakalama silinsin mi?'),
        content: Text(s.konum == YakalamaKonumu.telefonda
            ? 'Henüz gönderilmedi; silersen sunucuya hiçbir şey gitmez.'
            : 'Sunucudaki kayıt da silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (onay == true) await viewModel.sil(s.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yakalamalar')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final liste = viewModel.liste;
          if (liste == null) {
            if (viewModel.yukleniyor) return const YuklemeIskeleti(yukseklik: 72);
            return BosDurum(
              metin: viewModel.hata ?? 'Liste alınamadı.',
              dugme: 'Tekrar dene',
              onPressed: viewModel.yukle,
            );
          }
          return RefreshIndicator(
            onRefresh: viewModel.yukle,
            child: liste.isEmpty
                ? BosDurum(
                    ikon: LucideIcons.inbox,
                    metin: viewModel.hata ?? 'Henüz yakalama yok. Aşağıdaki Yakala düğmesiyle aklındakini kaydet.',
                  )
                : OrtaGenislik(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Room for the floating "Yakala" button under the last row.
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        if (viewModel.hata != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              viewModel.hata!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        for (final gun in _gunlereAyir(liste)) ...[
                          _GunBasligi(gun.first.yakalandiAt.toLocal()),
                          for (final s in gun)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _Satir(satir: s, onSil: () => _sil(context, s)),
                            ),
                        ],
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}

/// The list is newest first, so a day's captures are next to each other.
List<List<YakalamaSatiri>> _gunlereAyir(List<YakalamaSatiri> liste) {
  final gunler = <List<YakalamaSatiri>>[];
  DateTime? son;
  for (final s in liste) {
    final y = s.yakalandiAt.toLocal();
    final gun = DateTime(y.year, y.month, y.day);
    if (gun != son) {
      gunler.add([]);
      son = gun;
    }
    gunler.last.add(s);
  }
  return gunler;
}

/// "Bugün", "Dün", "3 Kasım Pazartesi"; the year only when it is not this year.
String _gunMetni(DateTime an, DateTime simdi) {
  final gun = DateTime(an.year, an.month, an.day);
  final bugun = DateTime(simdi.year, simdi.month, simdi.day);
  if (gun == bugun) return 'Bugün';
  if (gun == bugun.subtract(const Duration(days: 1))) return 'Dün';
  return DateFormat(gun.year == bugun.year ? 'd MMMM EEEE' : 'd MMMM y EEEE', 'tr').format(gun);
}

class _GunBasligi extends StatelessWidget {
  const _GunBasligi(this.an);

  final DateTime an;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        _gunMetni(an, DateTime.now()).toUpperCase(),
        style: tema.textTheme.labelSmall?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// One capture. Waiting on the server is the normal state, so only the other
/// states get a mark: not sent yet, in the brain, refused.
class _Satir extends StatelessWidget {
  const _Satir({required this.satir, required this.onSil});

  final YakalamaSatiri satir;
  final Future<void> Function() onSil;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final kucuk = KdYazi.of(context).sayi.copyWith(fontSize: 12, color: soluk);
    final metin = satir.metin;
    final hata = satir.hata;
    final hedef = satir.hedef;
    final fotografVar = satir.fotografId != null || satir.fotografYolu != null;

    final kart = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: satir.degistirilebilir ? () => context.push('/yakalama/${satir.id}/duzenle') : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fotografVar) ...[_Kucuk(satir), const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metin ?? 'Fotoğraf',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: metin == null
                          ? tema.textTheme.bodyLarge?.copyWith(color: soluk, fontStyle: FontStyle.italic)
                          : tema.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(DateFormat('HH:mm', 'tr').format(satir.yakalandiAt.toLocal()), style: kucuk),
                        if (hedef != null)
                          _Isaret(
                            ikon: LucideIcons.folder,
                            metin: hedef.startsWith('projects/') ? hedef.substring('projects/'.length) : hedef,
                            renk: tema.colorScheme.primary,
                          ),
                        if (satir.konum == YakalamaKonumu.telefonda && hata == null)
                          _Isaret(ikon: LucideIcons.cloudOff, metin: 'Gönderilmedi', renk: soluk),
                        if (satir.konum == YakalamaKonumu.beyinde)
                          _Isaret(
                            ikon: LucideIcons.brain,
                            metin: satir.islendi ? 'Beyinde · işlendi' : 'Beyinde',
                            renk: tema.colorScheme.primary,
                          ),
                      ],
                    ),
                    if (hata != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Gönderilemedi, sunucu reddetti: $hata',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: tema.colorScheme.error, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!satir.degistirilebilir) return kart;

    // Swipe left to delete; the dialog asks first, the list reloads itself.
    return Dismissible(
      key: ValueKey('yakalama-${satir.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await onSil();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: tema.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(LucideIcons.trash2, color: tema.colorScheme.onErrorContainer, semanticLabel: 'Sil'),
      ),
      child: kart,
    );
  }
}

class _Isaret extends StatelessWidget {
  const _Isaret({required this.ikon, required this.metin, required this.renk});

  final IconData ikon;
  final String metin;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 14, color: renk),
        const SizedBox(width: 4),
        Flexible(
          child: Text(metin, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: renk)),
        ),
      ],
    );
  }
}

/// Thumbnail: the phone's copy while it exists, else the server's photo.
class _Kucuk extends StatelessWidget {
  const _Kucuk(this.satir);

  final YakalamaSatiri satir;

  @override
  Widget build(BuildContext context) {
    final Widget resim = satir.fotografYolu != null && File(satir.fotografYolu!).existsSync()
        ? Image.file(File(satir.fotografYolu!), fit: BoxFit.cover)
        : ApiResim(dosyaId: satir.fotografId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 56, height: 56, child: resim),
    );
  }
}
