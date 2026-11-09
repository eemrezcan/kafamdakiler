import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/models/eylem.dart';
import '../../data/repositories/kullanici_repository.dart';
import '../../utils/eylem_gorunum.dart';
import '../core/renkler.dart';
import '../core/widgets.dart';
import 'eylem_liste_view_model.dart';

/// The approval queue, a full-screen page opened from the Today and Gelen cards. Swipe right to approve, left to
/// reject, tap for the details (and to correct the payload). Deciding is for the Sahip (K-0009); other users only read.
class EylemListeScreen extends StatelessWidget {
  const EylemListeScreen({super.key, required this.viewModel});

  final EylemListeViewModel viewModel;

  Future<void> _reddet(BuildContext context, Eylem e, {required bool birDahaOnerme}) async {
    await viewModel.reddet(e.id, birDahaOnerme: birDahaOnerme);
  }

  @override
  Widget build(BuildContext context) {
    final sahip = context.watch<KullaniciRepository>().sahip;
    return Scaffold(
      appBar: AppBar(title: const Text('Onay kuyruğu')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final liste = viewModel.liste;
          if (liste == null) {
            if (viewModel.yukleniyor) return const YuklemeIskeleti(yukseklik: 96);
            return BosDurum(
              metin: viewModel.hata ?? 'Liste alınamadı.',
              dugme: 'Tekrar dene',
              onPressed: viewModel.yukle,
            );
          }
          final tema = Theme.of(context);
          final bekleyenler = viewModel.bekleyenler;
          final uygulananlar = viewModel.sonUygulananlar;
          final hatalilar = viewModel.hatalilar;
          return RefreshIndicator(
            onRefresh: viewModel.yukle,
            child: OrtaGenislik(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: listeKenarlari(ust: 12),
                children: [
                  if (viewModel.cevrimdisi)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Çevrimdışısın; kararların telefona yazılıyor, bağlantı gelince gönderilecek.',
                        style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  if (viewModel.hata != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(viewModel.hata!, style: TextStyle(color: tema.colorScheme.error)),
                    ),
                  _Baslik('Bekleyenler', adet: bekleyenler.length),
                  if (bekleyenler.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Onay bekleyen bir şey yok.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  for (final e in bekleyenler)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _BekleyenKart(
                        eylem: e,
                        karar: sahip,
                        onUygula: () => viewModel.uygula(e.id),
                        onReddet: () => _reddet(context, e, birDahaOnerme: false),
                      ),
                    ),
                  if (hatalilar.isNotEmpty) ...[
                    _Baslik('Uygulanamayanlar', adet: hatalilar.length),
                    for (final e in hatalilar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SakinKart(
                          eylem: e,
                          durumMetni: 'Hatalı',
                          renk: tema.colorScheme.error,
                          ayrinti: e.hataMesaji ?? 'Uygulanamadı.',
                        ),
                      ),
                  ],
                  _Baslik('Son uygulananlar'),
                  if (uygulananlar.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Henüz uygulanan bir şey yok.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  for (final e in uygulananlar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SakinKart(
                        eylem: e,
                        durumMetni: 'Uygulandı',
                        renk: tamamRengi(context),
                        ayrinti: e.kararVerenId == null ? 'Kendiliğinden' : 'Onayınla',
                        onGeriAl: sahip && e.geriAlinabilir ? () => viewModel.geriAl(e.id) : null,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik(this.metin, {this.adet});

  final String metin;
  final int? adet;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        adet == null ? metin.toUpperCase() : '${metin.toUpperCase()}  $adet',
        style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant, letterSpacing: 0.8),
      ),
    );
  }
}

/// A waiting action. For the Sahip: swipe right approves, swipe left rejects, and the buttons do the same.
class _BekleyenKart extends StatelessWidget {
  const _BekleyenKart({required this.eylem, required this.karar, required this.onUygula, required this.onReddet});

  final Eylem eylem;
  final bool karar;
  final Future<void> Function() onUygula;
  final Future<void> Function() onReddet;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final e = eylem;

    final kart = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/eylem/${e.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.ozet, style: tema.textTheme.titleMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Isaret(ikon: LucideIcons.tag, metin: e.turAdi, renk: tema.colorScheme.primary),
                  _Isaret(ikon: LucideIcons.inbox, metin: eylemKaynakAdi(e.kaynak), renk: soluk),
                  if (e.disKaynak) _Isaret(ikon: LucideIcons.triangleAlert, metin: 'Dış kaynak', renk: tema.colorScheme.error),
                  if (e.guven != null)
                    _Isaret(
                      ikon: LucideIcons.gauge,
                      metin: e.eminDegil ? 'Emin değil · ${eylemGuvenMetni(e.guven!)}' : 'Güven ${eylemGuvenMetni(e.guven!)}',
                      renk: e.eminDegil ? tema.colorScheme.error : soluk,
                    ),
                  _Isaret(ikon: LucideIcons.clock, metin: DateFormat('d MMM HH:mm', 'tr').format(e.createdAt.toLocal()), renk: soluk),
                ],
              ),
              if (e.gerekce != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(eylemGerekcesi(e.gerekce!).metin, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: soluk)),
                ),
              if (karar) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: onUygula,
                      icon: const Icon(LucideIcons.check),
                      label: const Text('Uygula'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: onReddet,
                      icon: const Icon(LucideIcons.x),
                      label: const Text('Reddet'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!karar) return kart;

    // The swipe only starts the decision; the list reloads itself and the card goes away with it.
    return Dismissible(
      key: ValueKey('eylem-${e.id}'),
      confirmDismiss: (yon) async {
        if (yon == DismissDirection.startToEnd) {
          await onUygula();
        } else {
          await onReddet();
        }
        return false;
      },
      background: _Arka(
        hizalama: Alignment.centerLeft,
        renk: tamamRengi(context).withValues(alpha: 0.25),
        ikon: LucideIcons.check,
        etiket: 'Uygula',
      ),
      secondaryBackground: _Arka(
        hizalama: Alignment.centerRight,
        renk: tema.colorScheme.errorContainer,
        ikon: LucideIcons.x,
        etiket: 'Reddet',
      ),
      child: kart,
    );
  }
}

class _Arka extends StatelessWidget {
  const _Arka({required this.hizalama, required this.renk, required this.ikon, required this.etiket});

  final Alignment hizalama;
  final Color renk;
  final IconData ikon;
  final String etiket;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: hizalama,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(12)),
      child: Icon(ikon, semanticLabel: etiket),
    );
  }
}

/// A decided action: title, status and one line, and "Geri al" for an applied one when [onGeriAl] is given.
class _SakinKart extends StatelessWidget {
  const _SakinKart({required this.eylem, required this.durumMetni, required this.renk, required this.ayrinti, this.onGeriAl});

  final Eylem eylem;
  final String durumMetni;
  final Color renk;
  final String ayrinti;
  final Future<void> Function()? onGeriAl;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/eylem/${eylem.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eylem.ozet, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        Text(durumMetni, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: renk)),
                        Text(ayrinti, style: TextStyle(fontSize: 12, color: soluk)),
                      ],
                    ),
                  ],
                ),
              ),
              if (onGeriAl != null)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: onGeriAl,
                  child: const Text('Geri al'),
                ),
            ],
          ),
        ),
      ),
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
