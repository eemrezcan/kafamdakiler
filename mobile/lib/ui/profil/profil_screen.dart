import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/kullanici_repository.dart';
import '../core/widgets.dart';
import 'profil_view_model.dart';

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key, required this.viewModel});

  final ProfilViewModel viewModel;

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
      appBar: AppBar(title: const Text('Profil')),
      body: OrtaGenislik(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) => ListView(
            // Room for the floating "Yakala" button under the last card.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Card(
                child: Column(
                  children: [
                    ListTile(
                      minTileHeight: 56,
                      leading: const Icon(LucideIcons.mail),
                      title: Text(kullanici.ben?.email ?? 'Bilinmiyor'),
                      subtitle: const Text('E-posta'),
                    ),
                    ListTile(
                      minTileHeight: 56,
                      leading: const Icon(LucideIcons.shield),
                      title: Text(kullanici.ben == null ? 'Bilinmiyor' : kullanici.ben!.roller.join(', ')),
                      subtitle: const Text('Rol'),
                    ),
                  ],
                ),
              ),
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
