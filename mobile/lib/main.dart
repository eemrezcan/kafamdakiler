import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'data/repositories/aliskanlik_repository.dart';
import 'data/repositories/asistan_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/beyin_repository.dart';
import 'data/repositories/bildirim_repository.dart';
import 'data/repositories/brifing_repository.dart';
import 'data/repositories/esitleyici.dart';
import 'data/repositories/bildirim_izni.dart';
import 'data/repositories/eylem_bildirim_yoneticisi.dart';
import 'data/repositories/eylem_repository.dart';
import 'data/repositories/gelen_repository.dart';
import 'data/repositories/gun_plani_repository.dart';
import 'data/repositories/gun_repository.dart';
import 'data/repositories/hatirlatici_bildirim_yoneticisi.dart';
import 'data/repositories/hatirlatici_repository.dart';
import 'data/repositories/is_bildirim_yoneticisi.dart';
import 'data/repositories/is_repository.dart';
import 'data/repositories/kronometre_repository.dart';
import 'data/repositories/kullanici_repository.dart';
import 'data/repositories/push_mesaj_isleyici.dart';
import 'data/repositories/push_yoneticisi.dart';
import 'data/repositories/surum_denetcisi.dart';
import 'data/repositories/yakala_yonlendirici.dart';
import 'data/repositories/yakalama_repository.dart';
import 'data/services/api_service.dart';
import 'data/services/database/app_database.dart';
import 'data/services/bildirim_servisi.dart';
import 'data/services/esitleme_tetikleyici.dart';
import 'data/services/paylasim_kaynagi.dart';
import 'data/services/push_arka_plan.dart';
import 'data/services/push_kaynagi.dart';
import 'data/services/sunucu_bildirim_gosterici.dart';
import 'data/services/token_depo.dart';
import 'routing/router.dart';
import 'ui/surum/guncelleme_gerekli_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');
  // Push (FCM) is optional: if Firebase cannot start the app goes on without it.
  final pushKaynagi = await pushKaynaginiHazirla(pushArkaPlanIsleyici);

  final db = AppDatabase();
  final depo = GuvenliTokenDepo();
  late final AuthRepository auth;
  final api = ApiService(apiDioOlustur(
    apiUrl: AppConfig.apiUrl,
    depo: depo,
    oturumKapandi: () => auth.oturumKapandi(),
  ));
  final paket = await PackageInfo.fromPlatform();
  final surum = SurumDenetcisi(api: api, derlemeNumarasi: int.tryParse(paket.buildNumber) ?? 0);
  final esitleyici = Esitleyici(api: api, db: db);
  final aliskanliklar = AliskanlikRepository(api: api, db: db, esitleyici: esitleyici);
  final yakalamalar = YakalamaRepository(api: api, db: db, esitleyici: esitleyici);
  final hatirlaticilar = HatirlaticiRepository(api: api, db: db, esitleyici: esitleyici);
  final eylemler = EylemRepository(api: api, db: db, esitleyici: esitleyici);
  final gelen = GelenRepository(api: api, db: db, esitleyici: esitleyici);
  final kullanici = KullaniciRepository(api: api, db: db);
  final isler = IsRepository(api: api, db: db);
  final bildirimServisi = YerelBildirimServisi();
  final bildirimIzni = BildirimIzni(servis: bildirimServisi);
  final eylemBildirimleri = EylemBildirimYoneticisi(
    repo: eylemler,
    esitleyici: esitleyici,
    servis: bildirimServisi,
    yazabilir: () => kullanici.sahip,
  );
  final isBildirimleri = IsBildirimYoneticisi(repo: isler, servis: bildirimServisi, yazabilir: () => kullanici.sahip);
  final push = PushYoneticisi(
    api: api,
    kaynak: pushKaynagi,
    isleyici: PushMesajIsleyici(getir: api.sunucuBildirimiGetir, gosterici: YerelSunucuBildirimGosterici()),
    girisYapildi: () => auth.girisYapildi,
    cihazAdi: 'Android',
  );
  final brifing = BrifingRepository(api: api, db: db);
  final bildirimler = HatirlaticiBildirimYoneticisi(
    repo: hatirlaticilar,
    esitleyici: esitleyici,
    servis: bildirimServisi,
    yazabilir: () => kullanici.sahip,
    eylemler: eylemBildirimleri,
    isler: isBildirimleri,
    brifing: brifing,
    brifingOkuyabilir: () => kullanici.brifingOkuyabilir,
  );
  final beyin = BeyinRepository(api: api, db: db);
  final gunPlani = GunPlaniRepository(beyin: beyin, esitleyici: esitleyici);
  final gun = GunRepository(api: api, db: db, esitleyici: esitleyici);
  final bildirimMerkezi = BildirimRepository(api: api, db: db, esitleyici: esitleyici);
  final asistan = AsistanRepository(api: api, db: db, esitleyici: esitleyici);
  auth = AuthRepository(
    api: api,
    depo: depo,
    // The phone leaves the server's list of devices while the session still works.
    cikistanOnce: push.cikisOncesiSil,
    // Explicit sign-out: the user confirmed losing unsent entries.
    cikistaTemizle: () async {
      await yakalamalar.yerelFotograflariSil();
      await db.hepsiniTemizle();
      await bildirimler.temizle();
      await isler.temizle();
      bildirimIzni.sifirla();
      aliskanliklar.resimleriBirak();
      kullanici.temizle();
    },
  );

  await auth.baslat();
  await kullanici.baslat();
  // The role is asked after every sign-in and at start (offline: cached role).
  var girisYapildiydi = false;
  void rolIcin() {
    if (auth.girisYapildi && !girisYapildiydi) {
      kullanici.yukle();
      // Keeps the phone's project list (the capture screen's picker) fresh; quiet when offline or not allowed.
      unawaited(beyin.projeleriYenile());
      // The phone's FCM token goes to the server for this user.
      unawaited(push.kaydet());
      // The notification permission is asked right after sign-in when it is off (the first real run left it off without a word).
      unawaited(bildirimIzni.denetle());
    }
    girisYapildiydi = auth.girisYapildi;
  }

  auth.addListener(rolIcin);
  rolIcin();
  push.baslat();

  runApp(KafamdakilerApp(
    auth: auth,
    kullanici: kullanici,
    api: api,
    esitleyici: esitleyici,
    aliskanliklar: aliskanliklar,
    yakalamalar: yakalamalar,
    hatirlaticilar: hatirlaticilar,
    eylemler: eylemler,
    isler: isler,
    gelen: gelen,
    bildirimler: bildirimler,
    eylemBildirimleri: eylemBildirimleri,
    bildirimIzni: bildirimIzni,
    push: push,
    brifing: brifing,
    beyin: beyin,
    gunPlani: gunPlani,
    gun: gun,
    bildirimMerkezi: bildirimMerkezi,
    asistan: asistan,
    kronometre: KronometreRepository(db: db),
    surum: surum,
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
    required this.yakalamalar,
    required this.hatirlaticilar,
    required this.eylemler,
    required this.isler,
    required this.gelen,
    required this.bildirimler,
    required this.eylemBildirimleri,
    required this.bildirimIzni,
    required this.push,
    required this.brifing,
    required this.beyin,
    required this.gunPlani,
    required this.gun,
    required this.bildirimMerkezi,
    required this.asistan,
    required this.kronometre,
    required this.surum,
  });

  final AuthRepository auth;
  final KullaniciRepository kullanici;
  final ApiService api;
  final Esitleyici esitleyici;
  final AliskanlikRepository aliskanliklar;
  final YakalamaRepository yakalamalar;
  final HatirlaticiRepository hatirlaticilar;
  final EylemRepository eylemler;
  final IsRepository isler;
  final GelenRepository gelen;
  final HatirlaticiBildirimYoneticisi bildirimler;
  final EylemBildirimYoneticisi eylemBildirimleri;
  final BildirimIzni bildirimIzni;
  final PushYoneticisi push;
  final BrifingRepository brifing;
  final BeyinRepository beyin;
  final GunPlaniRepository gunPlani;
  final GunRepository gun;
  final BildirimRepository bildirimMerkezi;
  final AsistanRepository asistan;
  final KronometreRepository kronometre;
  final SurumDenetcisi surum;

  @override
  State<KafamdakilerApp> createState() => _KafamdakilerAppState();
}

class _KafamdakilerAppState extends State<KafamdakilerApp> {
  late final GoRouter _router = routerOlustur(widget.auth, widget.kullanici);
  final _bekleyenYakala = BekleyenYakala();
  final _mesajAnahtari = GlobalKey<ScaffoldMessengerState>();
  late final YakalaYonlendirici _yakalaYonlendirici = YakalaYonlendirici(
    bekleyen: _bekleyenYakala,
    degisim: Listenable.merge([widget.auth, widget.kullanici, _bekleyenYakala, _router.routerDelegate]),
    girisYapildi: () => widget.auth.girisYapildi,
    rolBilinir: () => widget.kullanici.ben != null,
    kullanabilir: () => widget.kullanici.asistanKullanabilir,
    // After a sign-in the router first goes to the start page; wait for that.
    hazir: () => _router.routeInformationProvider.value.uri.path != Rotalar.giris,
    // Share, the widget and the shortcut land on the Asistan tab; the input starts with what was shared.
    ac: (girdi) => _router.go(Rotalar.asistanSekmesi, extra: girdi),
    mesaj: (metin) => _mesajAnahtari.currentState?.showSnackBar(SnackBar(content: Text(metin))),
  );
  late final EsitlemeTetikleyici _tetikleyici = EsitlemeTetikleyici(
    gonder: () async {
      // At start, on return to the foreground and when connectivity comes back.
      unawaited(widget.surum.kontrolEt());
      if (widget.auth.girisYapildi) {
        // The notification permission: asked once after sign-in if it is off, looked at again each time the app comes back
        // (so turning it on in the settings clears the warning on Bugün). Before the sync: it does not need the network.
        await widget.bildirimIzni.denetle();
        await widget.esitleyici.gonder();
        // After the sync: refresh the reminders and set the notifications up again.
        await widget.bildirimler.esitleVeKur();
        // And announce the actions that came into the approval queue meanwhile.
        await widget.eylemBildirimleri.esitleVeBildir();
        // And hand the FCM token to the server if that has not worked yet (offline at sign-in).
        await widget.push.kaydet();
      }
    },
  );

  @override
  void initState() {
    super.initState();
    _tetikleyici.baslat();
    _yakalaYonlendirici.degerlendir();
    // Share menu and app shortcut; a platform failure must not stop the app.
    PaylasimKaynagi(_bekleyenYakala).baslat().catchError((Object _) {});
    // Notification taps and buttons; a platform failure must not stop the app.
    widget.bildirimler
        .baslat(listeyiAc: () {
          if (widget.auth.girisYapildi) _router.go(Rotalar.takvim);
        }, kuyruguAc: () {
          if (widget.auth.girisYapildi) _router.push(Rotalar.eylemler);
        }, brifingiAc: () {
          if (widget.auth.girisYapildi) _router.go(Rotalar.bugun);
        }, rotayiAc: (rota) {
          // A tap on a notification of the server: the route it names (Bugün when it names none).
          if (!widget.auth.girisYapildi) return;
          if (Rotalar.sekmeler.contains(rota)) {
            _router.go(rota);
          } else {
            _router.push(rota);
          }
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _tetikleyici.durdur();
    widget.bildirimler.durdur();
    widget.push.durdur();
    _yakalaYonlendirici.durdur();
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
        ChangeNotifierProvider.value(value: widget.yakalamalar),
        ChangeNotifierProvider.value(value: widget.hatirlaticilar),
        ChangeNotifierProvider.value(value: widget.eylemler),
        ChangeNotifierProvider.value(value: widget.isler),
        ChangeNotifierProvider.value(value: widget.gelen),
        Provider.value(value: widget.bildirimler),
        ChangeNotifierProvider.value(value: widget.bildirimIzni),
        Provider.value(value: widget.brifing),
        Provider.value(value: widget.beyin),
        ChangeNotifierProvider.value(value: widget.gunPlani),
        ChangeNotifierProvider.value(value: widget.gun),
        ChangeNotifierProvider.value(value: widget.bildirimMerkezi),
        ChangeNotifierProvider.value(value: widget.asistan),
        Provider.value(value: widget.kronometre),
        ChangeNotifierProvider.value(value: widget.surum),
      ],
      child: MaterialApp.router(
        title: 'Kafamdakiler',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        // Turkish date and time pickers (the reminder form).
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: _router,
        scaffoldMessengerKey: _mesajAnahtari,
        debugShowCheckedModeBanner: false,
        // Android 15 draws the app under the system navigation bar; keeping every screen and bottom sheet above it
        // stops their last buttons from hiding behind the phone's own keys.
        builder: (context, child) => ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            child: Consumer<SurumDenetcisi>(
              builder: (context, surum, _) =>
                  surum.guncellemeGerekli ? const GuncellemeGerekliScreen() : child!,
            ),
          ),
        ),
      ),
    );
  }
}
