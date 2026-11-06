import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/hatirlatici.dart';
import '../../utils/hatirlatici_gorunum.dart';

/// One reminder on the list: title, type, who it was promised to, when and how many days are left, the repeat
/// rule, the heads-up note, and (for an open one, when [duzenlenebilir]) the Yaptım / 1 saat / Yarın buttons.
class HatirlaticiKarti extends StatelessWidget {
  const HatirlaticiKarti({
    super.key,
    required this.hatirlatici,
    required this.simdi,
    required this.duzenlenebilir,
    required this.onYaptim,
    required this.onErtele,
  });

  final Hatirlatici hatirlatici;
  final DateTime simdi;

  /// The Sahip can change reminders; the others only read.
  final bool duzenlenebilir;
  final VoidCallback onYaptim;
  final void Function(String sure) onErtele;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final h = hatirlatici;
    final acik = h.durum == HatirlaticiDurumu.acik;
    final gecikmis = h.gecikmis(simdi);
    final vurgu = gecikmis ? tema.colorScheme.error : soluk;
    final tekrar = tekrarOzeti(h.tekrar, h.gun);
    final once = onceNotu(h.onceGun);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: gecikmis
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: tema.colorScheme.error.withValues(alpha: 0.6)),
            )
          : null,
      child: InkWell(
        onTap: duzenlenebilir ? () => context.push('/hatirlatici/${h.id}/duzenle') : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h.baslik, style: tema.textTheme.titleMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Isaret(ikon: LucideIcons.tag, metin: hatirlaticiTurAdi(h.tur), renk: tema.colorScheme.primary),
                  if (h.kime != null) _Isaret(ikon: LucideIcons.user, metin: 'Kime: ${h.kime}', renk: soluk),
                  _Isaret(ikon: LucideIcons.calendar, metin: hatirlaticiZamani(h.etkinAn), renk: soluk),
                  if (acik)
                    Text(
                      kalanGunMetni(h.kalanGun(simdi)),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: vurgu),
                    ),
                  if (h.erteleAn != null) _Isaret(ikon: LucideIcons.clock, metin: 'ertelendi', renk: tema.colorScheme.primary),
                  if (tekrar != null) _Isaret(ikon: LucideIcons.repeat, metin: tekrar, renk: soluk),
                ],
              ),
              if (once != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(once, style: TextStyle(fontSize: 12, color: soluk)),
                ),
              if (acik && duzenlenebilir) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: onYaptim,
                      icon: const Icon(LucideIcons.check),
                      label: const Text('Yaptım'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: () => onErtele(ErteleSuresi.birSaat),
                      child: const Text('1 saat ertele'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: () => onErtele(ErteleSuresi.yarin),
                      child: const Text('Yarın'),
                    ),
                  ],
                ),
              ],
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
