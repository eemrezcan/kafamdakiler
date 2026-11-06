import 'package:flutter/material.dart';

/// Blocking screen shown over the whole app when the build is older than the
/// API accepts. It has no close button and swallows the back button.
class GuncellemeGerekliScreen extends StatelessWidget {
  const GuncellemeGerekliScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.system_update, size: 56, color: tema.colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  'Uygulamanın yeni sürümü gerekli',
                  style: tema.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bu sürüm sunucuyla artık uyumlu değil. Devam etmek için uygulamayı güncelle.',
                  style: tema.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
