import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_theme.dart';
import '../../data/models/yakalama.dart';
import '../core/widgets.dart';

/// One capture that has not reached the brain yet, in the "Gönderiliyor" part of the inbox. Waiting on the server is the
/// normal state, so only the odd ones get a mark: not sent yet (stuck on the phone) and refused by the server. Tap to
/// edit; swipe left to delete (the caller asks first).
class GonderiliyorSatiri extends StatelessWidget {
  const GonderiliyorSatiri({super.key, required this.satir, required this.onSil});

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
        onTap: () => context.push('/yakalama/${satir.id}/duzenle'),
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
                        Text(DateFormat('d MMM HH:mm', 'tr').format(satir.yakalandiAt.toLocal()), style: kucuk),
                        if (hedef != null)
                          _Isaret(
                            ikon: LucideIcons.folder,
                            metin: hedef.startsWith('projects/') ? hedef.substring('projects/'.length) : hedef,
                            renk: tema.colorScheme.primary,
                          ),
                        if (hata != null)
                          _Isaret(ikon: LucideIcons.triangleAlert, metin: 'Gönderilemedi', renk: tema.colorScheme.error)
                        else if (satir.konum == YakalamaKonumu.telefonda)
                          _Isaret(ikon: LucideIcons.cloudOff, metin: 'Gönderilmedi', renk: soluk),
                      ],
                    ),
                    if (hata != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Sunucu reddetti: $hata',
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
        decoration: BoxDecoration(color: tema.colorScheme.errorContainer, borderRadius: BorderRadius.circular(10)),
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
        Flexible(child: Text(metin, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: renk))),
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
