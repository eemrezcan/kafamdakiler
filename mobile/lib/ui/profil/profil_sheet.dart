import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/aliskanlik_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/bildirim_izni.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/kullanici_repository.dart';
import '../../routing/router.dart';
import '../brifing/brifing_ayar_karti.dart';
import '../bugun/bildirim_kapali_uyarisi.dart';
import 'kapasite_sheet.dart';
import 'profil_view_model.dart';

/// Opens the profile sheet from the avatar in the top bar (K-0024): the account, management, the day capacity, the
/// notification settings, the password, the sending queue and sign-out. It replaces the old "Daha fazla" tab.
Future<void> profilAc(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => ChangeNotifierProvider(
      create: (c) => ProfilViewModel(repo: c.read<AliskanlikRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
      child: Builder(builder: (c) => ProfilSayfasi(viewModel: c.read<ProfilViewModel>(), kok: context)),
    ),
  );
}

/// The content of the profile sheet. [kok] is the context of the screen under the sheet: pages are pushed with it and the
/// sheet is closed first.
class ProfilSayfasi extends StatelessWidget {
  const ProfilSayfasi({super.key, required this.viewModel, required this.kok});

  final ProfilViewModel viewModel;
  final BuildContext kok;

  Future<void> _cikis(BuildContext context) async {
    final auth = context.read<AuthRepository>();
    final kayip = await viewModel.cikistaKaybolacak();
    if (!context.mounted) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        content: Text(
          kayip > 0 ? '$kayip kayıt henüz gönderilmedi; çıkarsan silinecek.' : 'Telefondaki önbellek temizlenecek.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            style: kayip > 0 ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error) : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(kayip > 0 ? 'Yine de çık' : 'Çıkış yap'),
          ),
        ],
      ),
    );
    if (onay == true) {
      if (context.mounted) Navigator.pop(context);
      await auth.cikis();
    }
  }

  /// Closes the sheet, then opens [rota] on top of the tab under it.
  void _git(BuildContext context, String rota) {
    final router = GoRouter.of(kok);
    Navigator.pop(context);
    router.push(rota);
  }

  @override
  Widget build(BuildContext context) {
    final kullanici = context.watch<KullaniciRepository>();
    final tema = Theme.of(context);
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The role is told only when it is not the owner's (one user app).
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 56,
              leading: const Icon(LucideIcons.circleUser),
              title: Text(kullanici.ben?.email ?? 'Bilinmiyor', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(kullanici.sahip || kullanici.ben == null ? 'Hesap' : 'Asistan hesabı'),
            ),
            const Divider(),
            if (kullanici.sahip)
              ListTile(
                key: const ValueKey('profil-yonetim'),
                minTileHeight: 56,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.settings),
                title: const Text('Asistan izinleri ve yönetim'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _git(context, Rotalar.yonetim),
              ),
            if (kullanici.sahip)
              ListTile(
                key: const ValueKey('profil-kapasite'),
                minTileHeight: 56,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.gauge),
                title: const Text('Gün kapasitesi'),
                subtitle: const Text('Bir günde yapılabilecek iş süresi'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => kapasiteAc(kok),
              ),
            ListTile(
              key: const ValueKey('profil-bildirim'),
              minTileHeight: 56,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.bellRing),
              title: const Text('Bildirim ayarları'),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => _bildirimAyarlari(context),
            ),
            ListTile(
              key: const ValueKey('profil-sifre'),
              minTileHeight: 56,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.keyRound),
              title: const Text('Şifremi değiştir'),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => _git(context, Rotalar.sifre),
            ),
            ListTile(
              key: const ValueKey('profil-kuyruk'),
              minTileHeight: 56,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.cloudUpload),
              title: const Text('Gönderim kuyruğu'),
              subtitle: Text(
                [
                  '${viewModel.bekleyen} bekleyen',
                  if (viewModel.gonderilemeyenler.isNotEmpty) '${viewModel.gonderilemeyenler.length} gönderilemedi',
                  if (viewModel.uyarilar.isNotEmpty) '${viewModel.uyarilar.length} uyarı',
                ].join(', '),
              ),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => _kuyruk(context),
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const ValueKey('profil-cikis'),
              minTileHeight: 56,
              contentPadding: EdgeInsets.zero,
              leading: Icon(LucideIcons.logOut, color: tema.colorScheme.error),
              title: Text('Çıkış yap', style: TextStyle(color: tema.colorScheme.error)),
              onTap: () => _cikis(context),
            ),
          ],
        ),
      ),
    );
  }

  /// The notification permission (with the way to the system settings when it is off) and the morning briefing's switch.
  void _bildirimAyarlari(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Bildirim ayarları', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              BildirimKapaliUyarisi(izin: context.read<BildirimIzni>()),
              // The warning above is there only while the permission is off; while it is on, say so.
              ListenableBuilder(
                listenable: context.read<BildirimIzni>(),
                builder: (context, _) => context.read<BildirimIzni>().kapali
                    ? const SizedBox.shrink()
                    : const ListTile(
                        key: ValueKey('bildirim-izni-acik'),
                        contentPadding: EdgeInsets.zero,
                        minTileHeight: 56,
                        leading: Icon(LucideIcons.bell),
                        title: Text('Bildirimler açık'),
                        subtitle: Text('Hatırlatıcılar ve sunucu mesajları görünür'),
                      ),
              ),
              if (context.read<KullaniciRepository>().brifingOkuyabilir) const BrifingAyarKarti(),
            ],
          ),
        ),
      ),
    );
  }

  /// The offline queue: what waits, the button to send now, and what the server refused (each can be deleted).
  void _kuyruk(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final tema = Theme.of(context);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gönderim kuyruğu', style: tema.textTheme.titleLarge),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 56,
                  leading: const Icon(LucideIcons.cloudUpload),
                  title: Text(viewModel.bekleyen == 0 ? 'Gönderilmeyi bekleyen kayıt yok' : '${viewModel.bekleyen} kayıt gönderilmeyi bekliyor'),
                  trailing: viewModel.bekleyen == 0 ? null : TextButton(onPressed: viewModel.simdiGonder, child: const Text('Şimdi gönder')),
                ),
                if (viewModel.uyarilar.isNotEmpty) ...[
                  Text('Dikkat: ${viewModel.uyarilar.length} kayıt', style: tema.textTheme.titleSmall),
                  for (final u in viewModel.uyarilar)
                    ListTile(
                      key: ValueKey('uyari-${u.id}'),
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: 56,
                      title: Text(u.baslik),
                      subtitle: Text(u.metin, maxLines: 4, overflow: TextOverflow.ellipsis),
                      trailing: TextButton(
                        key: ValueKey('uyari-tamam-${u.id}'),
                        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                        onPressed: () => viewModel.kaydiSil(u.id),
                        child: const Text('Tamam'),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
                if (viewModel.gonderilemeyenler.isNotEmpty) ...[
                  Text(
                    'Gönderilemeyen ${viewModel.gonderilemeyenler.length} kayıt',
                    style: tema.textTheme.titleSmall?.copyWith(color: tema.colorScheme.error),
                  ),
                  for (final k in viewModel.gonderilemeyenler)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
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
          );
        },
      ),
    );
  }
}
