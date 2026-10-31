import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'data/repositories/aliskanlik_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/esitleyici.dart';
import 'data/repositories/kronometre_repository.dart';
import 'data/repositories/kullanici_repository.dart';
import 'data/services/api_service.dart';
import 'data/services/database/app_database.dart';
import 'data/services/esitleme_tetikleyici.dart';
import 'data/services/token_depo.dart';
import 'routing/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');

  final db = AppDatabase();
  final depo = GuvenliTokenDepo();
  late final AuthRepository auth;
  final api = ApiService(apiDioOlustur(
    apiUrl: AppConfig.apiUrl,
    depo: depo,
    oturumKapandi: () => auth.oturumKapandi(),
  ));
  final esitleyici = Esitleyici(api: api, db: db);
  final aliskanliklar = AliskanlikRepository(api: api, db: db, esitleyici: esitleyici);
  final kullanici = KullaniciRepository(api: api, db: db);
  auth = AuthRepository(
    api: api,
    depo: depo,
    // Explicit sign-out: the user confirmed losing unsent entries.
    cikistaTemizle: () async {
      await db.hepsiniTemizle();
      aliskanliklar.resimleriBirak();
      kullanici.temizle();
    },
  );

  await auth.baslat();
  await kullanici.baslat();
  // The role is asked after every sign-in and at start (offline: cached role).
  var girisYapildiydi = false;
  void rolIcin() {
    if (auth.girisYapildi && !girisYapildiydi) kullanici.yukle();
    girisYapildiydi = auth.girisYapildi;
  }

  auth.addListener(rolIcin);
  rolIcin();

  runApp(KafamdakilerApp(
    auth: auth,
    kullanici: kullanici,
    api: api,
    esitleyici: esitleyici,
    aliskanliklar: aliskanliklar,
    kronometre: KronometreRepository(db: db),
  ));
}

class KafamdakilerApp extends StatefulWidget {
  const KafamdakilerApp({
    super.key,
    required this.auth,
    required this.kullanici,
    required this.api,
    required this.esitleyici,
    required this.aliskanliklar,
    required this.kronometre,
  });

  final AuthRepository auth;
  final KullaniciRepository kullanici;
  final ApiService api;
  final Esitleyici esitleyici;
  final AliskanlikRepository aliskanliklar;
  final KronometreRepository kronometre;

  @override
  State<KafamdakilerApp> createState() => _KafamdakilerAppState();
}

class _KafamdakilerAppState extends State<KafamdakilerApp> {
  late final GoRouter _router = routerOlustur(widget.auth, widget.kullanici);
  late final EsitlemeTetikleyici _tetikleyici = EsitlemeTetikleyici(
    gonder: () async {
      if (widget.auth.girisYapildi) await widget.esitleyici.gonder();
    },
  );

  @override
  void initState() {
    super.initState();
    _tetikleyici.baslat();
  }

  @override
  void dispose() {
    _tetikleyici.durdur();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.auth),
        ChangeNotifierProvider.value(value: widget.kullanici),
        Provider.value(value: widget.api),
        ChangeNotifierProvider.value(value: widget.esitleyici),
        ChangeNotifierProvider.value(value: widget.aliskanliklar),
        Provider.value(value: widget.kronometre),
      ],
      child: MaterialApp.router(
        title: 'Kafamdakiler',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
