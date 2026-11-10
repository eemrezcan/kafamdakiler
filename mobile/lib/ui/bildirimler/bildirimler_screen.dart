import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/bildirim_ogesi.dart';
import '../../routing/router.dart';
import '../../utils/hatirlatici_hesap.dart';
import '../../utils/metin.dart';
import '../../utils/push_hedefi.dart';
import '../core/widgets.dart';
import 'bildirimler_view_model.dart';

/// The notification page (K-0024, sözleşme §6): the list under "Bugün", "Dün" and "Daha önce" headings, a dot on what is unread,
/// "Tümü okundu", "Yaptım" and "1 saat ertele" on a reminder, and a tap that reads the notification and opens what it is about.
class BildirimlerScreen extends StatelessWidget {
  const BildirimlerScreen({super.key, required this.viewModel, this.yazabilir = true});

  final BildirimlerViewModel viewModel;

  /// False (the Asistan account) hides "Yaptım" and "Ertele": they write.
  final bool yazabilir;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) => TextButton(
              key: const ValueKey('bildirim-hepsi-okundu'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: viewModel.okunmamis == 0 ? null : viewModel.hepsiOkundu,
              child: const Text('Tümü okundu'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final liste = viewModel.liste;
          if (liste == null) {
            if (viewModel.yukleniyor) return const YuklemeIskeleti(yukseklik: 72);
            return BosDurum(metin: viewModel.hata ?? 'Bildirimler alınamadı.', dugme: 'Tekrar dene', onPressed: viewModel.yukle);
          }
          return RefreshIndicator(
            onRefresh: viewModel.yukle,
            child: liste.isEmpty
                ? const BosDurum(ikon: LucideIcons.bell, metin: 'Henüz bildirim yok.')
                : OrtaGenislik(child: _Liste(viewModel: viewModel, liste: liste, yazabilir: yazabilir)),
          );
        },
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({required this.viewModel, required this.liste, required this.yazabilir});

  final BildirimlerViewModel viewModel;
  final List<BildirimOgesi> liste;
  final bool yazabilir;

  static const _basliklar = {
    BildirimGunu.bugun: 'Bugün',
    BildirimGunu.dun: 'Dün',
    BildirimGunu.once: 'Daha önce',
    BildirimGunu.zamansiz: 'Daha önce',
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gruplar = <BildirimGunu, List<BildirimOgesi>>{};
    for (final b in liste) {
      // A notification without a time sits with the old ones.
      var g = bildirimGunu(b.zaman, viewModel.simdi);
      if (g == BildirimGunu.zamansiz) g = BildirimGunu.once;
      (gruplar[g] ??= []).add(b);
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (viewModel.cevrimdisi)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Çevrimdışısın; son okunan bildirimler gösteriliyor.', style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
          ),
        for (final g in BildirimGunu.values)
          if (gruplar[g] != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                trBuyuk(_basliklar[g]!),
                key: ValueKey('bildirim-baslik-${g.name}'),
                style: tema.textTheme.labelMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w600),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < gruplar[g]!.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: tema.colorScheme.outlineVariant),
                    _Satir(viewModel: viewModel, b: gruplar[g]![i], yazabilir: yazabilir),
                  ],
                ],
              ),
            ),
          ],
        if (viewModel.dahaVar)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: viewModel.dahaYukleniyor
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      key: const ValueKey('bildirim-daha'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: viewModel.dahaYukle,
                      child: const Text('Daha eski bildirimler'),
                    ),
            ),
          ),
      ],
    );
  }
}

IconData _ikon(String? tur) => switch (tur) {
      'hatirlatici' => LucideIcons.bell,
      'asistan' => LucideIcons.sparkles,
      'eylem' || 'onay' => LucideIcons.hourglass,
      'is' => LucideIcons.bot,
      'gorev' || 'dogrulama' => LucideIcons.listChecks,
      _ => LucideIcons.info,
    };

class _Satir extends StatelessWidget {
  const _Satir({required this.viewModel, required this.b, required this.yazabilir});

  final BildirimlerViewModel viewModel;
  final BildirimOgesi b;
  final bool yazabilir;

  /// "14:00" for today, "dün 21:00" for yesterday, "6 Kas 21:00" before.
  String _zaman() {
    final z = b.zaman;
    if (z == null) return '';
    final saat = istanbulSaati(z).kisa;
    return switch (bildirimGunu(z, viewModel.simdi)) {
      BildirimGunu.bugun => saat,
      BildirimGunu.dun => 'dün $saat',
      _ => '${DateFormat('d MMM', 'tr').format(istanbulGunu(z))} $saat',
    };
  }

  /// Where a tap goes: the route the notification names (resolved like a notification tap), or nowhere.
  void _ac(BuildContext context) {
    viewModel.okundu(b);
    if (b.rota != null) rotayaGit(context, hedefRotasi(b.rota, b.hedefKimligi));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final zaman = _zaman();
    final reminderEylemi = b.hatirlaticiMi && !b.okundu && yazabilir;
    final asistandaAc = !b.okundu && b.rota != null && b.kaynakTuru != 'hatirlatici' && (b.kaynakTuru == 'eylem' || b.kaynakTuru == 'onay' || b.kaynakTuru == 'asistan');
    return InkWell(
      key: ValueKey('bildirim-${b.id}'),
      onTap: () => _ac(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: tema.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(_ikon(b.kaynakTuru), size: 18, color: tema.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!b.okundu)
                          Container(
                            key: ValueKey('bildirim-nokta-${b.id}'),
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(shape: BoxShape.circle, color: tema.colorScheme.primary),
                          ),
                        Expanded(
                          child: Text(
                            b.baslik,
                            style: tema.textTheme.bodyLarge?.copyWith(fontWeight: b.okundu ? FontWeight.w400 : FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (b.metin.isNotEmpty) Text(b.metin, style: tema.textTheme.bodyMedium?.copyWith(color: soluk)),
                    if (zaman.isNotEmpty) Text(zaman, style: tema.textTheme.bodySmall?.copyWith(color: soluk)),
                    if (reminderEylemi || asistandaAc)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (reminderEylemi) ...[
                              FilledButton(
                                key: ValueKey('bildirim-yaptim-${b.id}'),
                                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                                onPressed: () => viewModel.yaptim(b),
                                child: const Text('Yaptım'),
                              ),
                              OutlinedButton(
                                key: ValueKey('bildirim-ertele-${b.id}'),
                                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                                onPressed: () => viewModel.ertele(b),
                                child: const Text('1 saat ertele'),
                              ),
                            ],
                            if (asistandaAc)
                              FilledButton(
                                key: ValueKey('bildirim-asistan-${b.id}'),
                                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                                onPressed: () => _ac(context),
                                child: const Text('Asistan\'da aç'),
                              ),
                          ],
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
  }
}
