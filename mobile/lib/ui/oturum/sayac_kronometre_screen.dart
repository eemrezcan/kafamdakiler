import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/aliskanlik.dart';
import '../../data/models/gun.dart';
import '../../data/repositories/aliskanlik_repository.dart';
import '../../data/repositories/esitleyici.dart';
import '../core/widgets.dart';
import 'kronometre_gosterge.dart';
import 'kronometre_view_model.dart';

/// Stopwatch for a minute-based counter (e.g. meditation): "Bitir" adds the
/// elapsed minutes to today's total.
class SayacKronometreScreen extends StatefulWidget {
  const SayacKronometreScreen({
    super.key,
    required this.aliskanlikId,
    required this.kronometre,
    required this.repo,
    required this.esitleyici,
  });

  final String aliskanlikId;
  final KronometreViewModel kronometre;
  final AliskanlikRepository repo;
  final Esitleyici esitleyici;

  @override
  State<SayacKronometreScreen> createState() => _SayacKronometreScreenState();
}

class _SayacKronometreScreenState extends State<SayacKronometreScreen> {
  Aliskanlik? _aliskanlik;
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    await widget.kronometre.yukle();
    final liste = await widget.repo.yerelListe();
    if (!mounted) return;
    setState(() {
      _aliskanlik = liste.where((a) => a.id == widget.aliskanlikId).firstOrNull;
      _yukleniyor = false;
    });
  }

  Future<void> _bitir() async {
    final a = _aliskanlik!;
    final dakika = widget.kronometre.dakika;
    // Read again: the day may have changed while the stopwatch ran.
    final guncel = (await widget.repo.yerelListe()).firstWhere((x) => x.id == a.id, orElse: () => a);
    final toplam = (guncel.bugun?.miktar ?? 0) + dakika;
    await widget.esitleyici.gunYazKuyrugaAl(a.id, widget.repo.bugun, GunYaz(miktar: toplam));
    await widget.kronometre.sifirla();
    unawaited(widget.esitleyici.gonder());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$dakika dakika eklendi')));
    context.pop();
  }

  /// Throws the running stopwatch away; nothing is written.
  Future<void> _vazgec() async {
    await widget.kronometre.sifirla();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final a = _aliskanlik;
    return Scaffold(
      appBar: AppBar(title: Text(a?.ad ?? 'Kronometre')),
      body: OrtaGenislik(
        maxGenislik: 480,
        child: _yukleniyor
            ? const Center(child: CircularProgressIndicator())
            : a == null
                ? const BosDurum(metin: 'Alışkanlık bulunamadı. Listeyi yenileyip tekrar dene.')
                : Center(child: KronometreGosterge(viewModel: widget.kronometre, onBitir: _bitir, onVazgec: _vazgec)),
      ),
    );
  }
}
