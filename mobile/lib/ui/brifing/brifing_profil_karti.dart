import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/models/brifing.dart';
import '../../data/repositories/brifing_repository.dart';
import '../../data/repositories/hatirlatici_bildirim_yoneticisi.dart';
import '../../routing/router.dart';

/// Profil's briefing rows (K2.7): open today's briefing, and the notification: on or off, and at what hour. A change is
/// kept on the phone and the notification plan is set up again at once.
class BrifingProfilKarti extends StatefulWidget {
  const BrifingProfilKarti({super.key});

  @override
  State<BrifingProfilKarti> createState() => _BrifingProfilKartiState();
}

class _BrifingProfilKartiState extends State<BrifingProfilKarti> {
  BrifingAyari _ayar = BrifingAyari.varsayilan;

  @override
  void initState() {
    super.initState();
    context.read<BrifingRepository>().ayar().then((a) {
      if (mounted) setState(() => _ayar = a);
    });
  }

  Future<void> _yaz(BrifingAyari yeni) async {
    final repo = context.read<BrifingRepository>();
    final bildirimler = context.read<HatirlaticiBildirimYoneticisi>();
    setState(() => _ayar = yeni);
    await repo.ayarYaz(yeni);
    // Turning it on asks for the notification permission (a no-op when it was given).
    if (yeni.acik) await bildirimler.izinIste();
    await bildirimler.kur();
  }

  Future<void> _saatSec() async {
    final secilen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _ayar.saat, minute: _ayar.dakika),
      helpText: 'Brifing saati',
    );
    if (secilen == null) return;
    await _yaz(BrifingAyari(saat: secilen.hour, dakika: secilen.minute));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            minTileHeight: 56,
            leading: const Icon(LucideIcons.sun),
            title: const Text('Sabah brifingi'),
            subtitle: const Text('Bugünün özeti ve önerilen kartlar'),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => context.push(Rotalar.brifing),
          ),
          SwitchListTile(
            key: const ValueKey('brifing-bildirim'),
            secondary: const Icon(LucideIcons.bellRing),
            title: const Text('Sabah bildirimi'),
            subtitle: Text(_ayar.acik ? 'Her gün ${_ayar.saatMetni}' : 'Kapalı'),
            value: _ayar.acik,
            onChanged: (acik) => _yaz(BrifingAyari(acik: acik, saat: _ayar.saat, dakika: _ayar.dakika)),
          ),
          if (_ayar.acik)
            ListTile(
              key: const ValueKey('brifing-saat'),
              minTileHeight: 56,
              leading: const Icon(LucideIcons.clock),
              title: const Text('Brifing saati'),
              trailing: Text(_ayar.saatMetni, style: Theme.of(context).textTheme.titleMedium),
              onTap: _saatSec,
            ),
        ],
      ),
    );
  }
}
