import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/kullanici_repository.dart';
import '../../routing/router.dart';
import '../brifing/brifing_ayar_karti.dart';
import '../core/widgets.dart';
import 'daha_fazla_view_model.dart';

/// "Daha fazla", the last tab: the account, the pages that are not tabs (habits, captures, management), the morning
/// notification, the offline queue, the password and sign-out.
class DahaFazlaScreen extends StatelessWidget {
  const DahaFazlaScreen({super.key, required this.viewModel});

  final DahaFazlaViewModel viewModel;

  Future<void> _cikis(BuildContext context) async {
    final auth = context.read<AuthRepository>();
    final kayip = await viewModel.cikistaKaybolacak();
    if (!context.mounted) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        content: Text(
          kayip > 0
              ? '$kayip kayıt henüz gönderilmedi; çıkarsan silinecek.'
              : 'Telefondaki önbellek temizlenecek.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            style: kayip > 0
                ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(kayip > 0 ? 'Yine de çık' : 'Çıkış yap'),
          ),
        ],
      ),
    );
    if (onay == true) await auth.cikis();
  }

  @override
  Widget build(BuildContext context) {
    final kullanici = context.watch<KullaniciRepository>();
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Daha fazla')),
      body: OrtaGenislik(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) => ListView(
            // Room for the floating "Yakala" button under the last card.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              // The account and its password together; the role is told only when it is not the owner's (one user app).
              Card(
                child: Column(
                  children: [
                    ListTile(
                      minTileHeight: 56,
                      leading: const Icon(LucideIcons.circleUser),
                      title: Text(kullanici.ben?.email ?? 'Bilinmiyor', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(kullanici.sahip || kullanici.ben == null ? 'Hesap' : 'Asistan hesabı'),
                    ),
                    ListTile(
                      minTileHeight: 56,
                      leading: const Icon(LucideIcons.keyRound),
                      title: const Text('Şifremi değiştir'),
                      trailing: const Icon(LucideIcons.chevronRight),
                      onTap: () => context.push(Rotalar.sifre),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Pages that are not tabs open from here.
              Card(
                child: Column(
                  children: [
                    ListTile(
                      minTileHeight: 56,
                      leading: const Icon(LucideIcons.target),
                      title: const Text('Alışkanlıklar'),
                      subtitle: const Text('Liste, detay ve raf'),
                      trailing: const Icon(LucideIcons.chevronRight),
                      onTap: () => context.push(Rotalar.aliskanliklar),
                    ),
                    // Permissions, brain status and the sending queue: the Sahip's only.
                    if (kullanici.sahip)
                      ListTile(
                        minTileHeight: 56,
                        leading: const Icon(LucideIcons.settings),
                        title: const Text('Yönetim'),
                        subtitle: const Text('Asistan izinleri, beyin, gönderim kuyruğu'),
                        trailing: const Icon(LucideIcons.chevronRight),
                        onTap: () => context.push(Rotalar.yonetim),
                      ),
                  ],
                ),
              ),
              if (kullanici.brifingOkuyabilir) ...[
                const SizedBox(height: 16),
                const BrifingAyarKarti(),
              ],
              // The offline queue shows only when something waits or was refused; an empty queue is nothing to look at.
              if (viewModel.bekleyen > 0 || viewModel.gonderilemeyenler.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      minTileHeight: 56,
                      leading: const Icon(LucideIcons.cloudUpload),
                      title: Text(viewModel.bekleyen == 0
                          ? 'Gönderilmeyi bekleyen kayıt yok'
                          : '${viewModel.bekleyen} kayıt gönderilmeyi bekliyor'),
                      subtitle: const Text('Çevrimdışı kuyruk'),
                      trailing: viewModel.bekleyen == 0
                          ? null
                          : TextButton(onPressed: viewModel.simdiGonder, child: const Text('Şimdi gönder')),
                    ),
                    if (viewModel.gonderilemeyenler.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          'Gönderilemeyen ${viewModel.gonderilemeyenler.length} kayıt',
                          style: tema.textTheme.titleSmall?.copyWith(color: tema.colorScheme.error),
                        ),
                      ),
                      for (final k in viewModel.gonderilemeyenler)
                        ListTile(
                          minTileHeight: 56,
                          title: Text(k.baslik),
                          subtitle: Text('Sunucu reddetti: ${k.hata}', maxLines: 3, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            tooltip: 'Kaydı sil',
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            icon: const Icon(LucideIcons.trash2),
                            onPressed: () => viewModel.kaydiSil(k.id),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => _cikis(context),
                icon: const Icon(LucideIcons.logOut),
                label: const Text('Çıkış yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
