import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repositories/aliskanlik_repository.dart';
import '../data/models/yakala_girdisi.dart';
import '../data/repositories/asistan_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/beyin_repository.dart';
import '../data/repositories/bildirim_izni.dart';
import '../data/repositories/bildirim_repository.dart';
import '../data/repositories/brifing_repository.dart';
import '../data/repositories/esitleyici.dart';
import '../data/repositories/gun_plani_repository.dart';
import '../data/repositories/eylem_repository.dart';
import '../data/repositories/gelen_repository.dart';
import '../data/repositories/gun_repository.dart';
import '../data/repositories/hatirlatici_bildirim_yoneticisi.dart';
import '../data/repositories/hatirlatici_repository.dart';
import '../data/repositories/is_repository.dart';
import '../data/repositories/kronometre_repository.dart';
import '../data/repositories/kullanici_repository.dart';
import '../data/repositories/yakalama_repository.dart';
import '../data/services/api_service.dart';
import '../data/services/baglanti_servisi.dart';
import '../data/services/dikte_servisi.dart';
import '../ui/aliskanliklar/aliskanlik_detay_screen.dart';
import '../ui/aliskanliklar/aliskanlik_detay_view_model.dart';
import '../ui/aliskanliklar/aliskanlik_form_screen.dart';
import '../ui/aliskanliklar/aliskanlik_form_view_model.dart';
import '../ui/aliskanliklar/aliskanlik_liste_screen.dart';
import '../ui/aliskanliklar/aliskanlik_liste_view_model.dart';
import '../ui/ara/ara_screen.dart';
import '../ui/ara/ara_view_model.dart';
import '../ui/ara/not_screen.dart';
import '../ui/asistan/asistan_pano_screen.dart';
import '../ui/asistan/asistan_screen.dart';
import '../ui/asistan/asistan_view_model.dart';
import '../ui/beyin/beyin_screen.dart';
import '../ui/bildirimler/bildirimler_screen.dart';
import '../ui/bildirimler/bildirimler_view_model.dart';
import '../ui/asistan/asistan_pano_view_model.dart';
import '../ui/asistan/is_detay_screen.dart';
import '../ui/asistan/is_detay_view_model.dart';
import '../ui/asistan/is_form_screen.dart';
import '../ui/asistan/is_form_view_model.dart';
import '../ui/bugun/bugun_screen.dart';
import '../ui/gun/gun_view_model.dart';
import '../ui/takvim/takvim_screen.dart';
import '../ui/takvim/takvim_view_model.dart';
import '../ui/bugun/bugun_view_model.dart';
import '../ui/eylemler/eylem_detay_screen.dart';
import '../ui/eylemler/eylem_detay_view_model.dart';
import '../ui/eylemler/eylem_liste_screen.dart';
import '../ui/eylemler/eylem_liste_view_model.dart';
import '../ui/gelen/gelen_liste_screen.dart';
import '../ui/gelen/gelen_liste_view_model.dart';
import '../ui/giris/giris_screen.dart';
import '../ui/hatirlaticilar/hatirlatici_form_screen.dart';
import '../ui/hatirlaticilar/hatirlatici_form_view_model.dart';
import '../ui/giris/giris_view_model.dart';
import '../ui/oturum/kronometre_view_model.dart';
import '../ui/oturum/oturum_screen.dart';
import '../ui/oturum/oturum_view_model.dart';
import '../ui/oturum/sayac_kronometre_screen.dart';
import '../ui/profil/sifre_screen.dart';
import '../ui/profil/sifre_view_model.dart';
import '../ui/projeler/proje_detay_screen.dart';
import '../ui/projeler/proje_liste_screen.dart';
import '../ui/projeler/proje_view_model.dart';
import '../ui/raf/oge_detay_screen.dart';
import '../ui/raf/oge_detay_view_model.dart';
import '../ui/raf/oge_form_screen.dart';
import '../ui/raf/oge_form_view_model.dart';
import '../ui/raf/raf_screen.dart';
import '../ui/raf/raf_view_model.dart';
import '../ui/shell/ana_iskele.dart';
import '../ui/yakalama/ses_view_model.dart';
import '../ui/yakalama/yakala_screen.dart';
import '../ui/yakalama/yakala_view_model.dart';
import '../ui/yonetim/yonetim_screen.dart';
import '../ui/yonetim/yonetim_view_model.dart';

/// "2026-11-11" as a date-only UTC value; null when it is not a real date.
DateTime? gunMetnindenTarih(String? metin) {
  if (metin == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(metin)) return null;
  final g = DateTime.tryParse(metin);
  if (g == null) return null;
  final utc = DateTime.utc(g.year, g.month, g.day);
  return utc.toIso8601String().startsWith(metin) ? utc : null;
}

abstract final class Rotalar {
  // The five bottom tabs, in the order they are shown: Bugün · Takvim · Asistan · Alışkanlıklar · Beyin (K-0024).
  static const bugun = '/';
  static const takvim = '/takvim';
  static const asistanSekmesi = '/asistan';
  static const aliskanliklar = '/aliskanliklar';
  static const beyin = '/beyin';

  /// The tabs' routes, in tab order.
  static const sekmeler = [bugun, takvim, asistanSekmesi, aliskanliklar, beyin];

  /// The old tabs' addresses: a notification or a link made before the revision still lands somewhere useful.
  static const eskiHatirlaticilar = '/hatirlaticilar';
  static const eskiDahaFazla = '/daha-fazla';

  /// The search page: opened from Beyin, a full-screen page (not a tab).
  static const ara = '/ara';

  /// The project list: opened from Beyin, a full-screen page (not a tab); a project is `/projeler/:kimlik`.
  static const projeler = '/projeler';

  static const yakala = '/yakala';

  /// The inbox: opened from the Asistan tab, a full-screen page.
  static const gelen = '/gelen';

  /// The notification list: opened by the bell in the top bar of the tabs.
  static const bildirimler = '/bildirimler';

  /// The work card board: opened from the Asistan tab, a full-screen page. `yeni` is the form; a card is `/asistan/:kimlik`
  /// (the address work card notifications carry).
  static const isler = '/isler';
  static const asistanYeni = '/asistan/yeni';

  /// The approval queue: opened from the Asistan tab and from its notifications, a full-screen page.
  static const eylemler = '/eylemler';

  /// The Sahip's management screen: opened from the profile sheet, a full-screen page.
  static const yonetim = '/yonetim';

  /// "Şifremi değiştir": opened from the profile sheet, a full-screen page for every signed-in user.
  static const sifre = '/sifre';
  static const giris = '/giris';
}

/// Opens [rota]: a tab is switched to (`go`), any other page is put on top (`push`), so back from it returns.
void rotayaGit(BuildContext context, String rota) {
  if (Rotalar.sekmeler.contains(rota)) {
    context.go(rota);
  } else {
    context.push(rota);
  }
}

final _yonetimRotalari = [
  RegExp(r'^/aliskanlik/yeni$'),
  RegExp(r'^/aliskanlik/[^/]+/duzenle$'),
  RegExp(r'^/raf/[^/]+/oge-yeni$'),
  RegExp(r'^/oge/[^/]+/duzenle$'),
  RegExp(r'^/yakala$'),
  RegExp(r'^/yakalama/[^/]+/duzenle$'),
  RegExp(r'^/hatirlatici/yeni$'),
  RegExp(r'^/hatirlatici/[^/]+/duzenle$'),
  RegExp(r'^/yonetim$'),
  RegExp(r'^/asistan/yeni$'),
];

/// Where a visit to [konum] must be sent instead, or null to let it through.
///
/// - Signed-out users only see the login screen.
/// - The forms that create or change content (captures included) and the
///   management screen are for the Sahip role only; the route is blocked, not
///   just the button hidden (M07).
String? yetkiYonlendirme(String konum, {required bool girisYapildi, required bool sahip}) {
  final girisEkraninda = konum == Rotalar.giris;
  if (!girisYapildi) return girisEkraninda ? null : Rotalar.giris;
  if (girisEkraninda) return Rotalar.bugun;
  if (!sahip && _yonetimRotalari.any((r) => r.hasMatch(konum))) return Rotalar.aliskanliklar;
  return null;
}

/// Builds a view model with `provider` (disposed with the route) and hands it
/// to the screen.
Widget _sayfa<T extends ChangeNotifier>(T Function(BuildContext) olustur, Widget Function(T) ekran) {
  return ChangeNotifierProvider<T>(
    create: olustur,
    child: Builder(builder: (context) => ekran(context.read<T>())),
  );
}

/// [baglantiServisi] makes the connection check behind the voice/briefing view models; tests hand in a fake one.
GoRouter routerOlustur(
  AuthRepository auth,
  KullaniciRepository kullanici, {
  BaglantiServisi Function() baglantiServisi = ConnectivityBaglantiServisi.new,
}) {
  return GoRouter(
    initialLocation: Rotalar.bugun,
    refreshListenable: Listenable.merge([auth, kullanici]),
    redirect: (context, state) => yetkiYonlendirme(
      state.matchedLocation,
      girisYapildi: auth.girisYapildi,
      sahip: kullanici.sahip,
    ),
    routes: [
      GoRoute(
        path: Rotalar.giris,
        builder: (context, state) => _sayfa(
          (c) => GirisViewModel(c.read<AuthRepository>()),
          (vm) => GirisScreen(viewModel: vm),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AnaIskele(navigationShell: shell),
        branches: [
          // Bugün
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotalar.bugun,
              builder: (context, state) => MultiProvider(
                providers: [
                  ChangeNotifierProvider(
                    create: (c) => BugunViewModel(repo: c.read<AliskanlikRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
                  ),
                  ChangeNotifierProvider(
                    create: (c) => GunViewModel(repo: c.read<GunRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
                  ),
                ],
                child: Builder(
                  builder: (context) => BugunScreen(
                    viewModel: context.read<BugunViewModel>(),
                    gun: context.read<GunViewModel>(),
                    bildirimIzni: context.read<BildirimIzni>(),
                    yazabilir: context.watch<KullaniciRepository>().sahip,
                  ),
                ),
              ),
            ),
          ]),
          // Takvim
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotalar.takvim,
              builder: (context, state) => ChangeNotifierProvider(
                // A new day in the address (`?gun=`) makes a new view model, so the tab opens on that day.
                key: ValueKey(state.uri.queryParameters['gun']),
                create: (c) => TakvimViewModel(
                  repo: c.read<GunRepository>(),
                  esitleyici: c.read<Esitleyici>(),
                  baslangicGunu: gunMetnindenTarih(state.uri.queryParameters['gun']),
                )..yukle(),
                child: Builder(
                  builder: (context) => TakvimScreen(
                    viewModel: context.read<TakvimViewModel>(),
                    yazabilir: context.watch<KullaniciRepository>().sahip,
                  ),
                ),
              ),
            ),
          ]),
          // Asistan
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotalar.asistanSekmesi,
              builder: (context, state) => MultiProvider(
                providers: [
                  ChangeNotifierProvider(
                    create: (c) => AsistanViewModel(
                      repo: c.read<AsistanRepository>(),
                      brifing: c.read<BrifingRepository>(),
                      esitleyici: c.read<Esitleyici>(),
                    )..yukle(),
                  ),
                  // Dictation behind the microphone of the input.
                  ChangeNotifierProvider(
                    create: (c) => SesViewModel(api: c.read<ApiService>(), dikte: SpeechDikteServisi(), baglanti: baglantiServisi()),
                  ),
                ],
                child: Builder(builder: (context) {
                  final k = context.watch<KullaniciRepository>();
                  return AsistanScreen(
                    viewModel: context.read<AsistanViewModel>(),
                    ses: context.read<SesViewModel>(),
                    // Share, the widget and the shortcut come with the starting state (a share: its text or photo).
                    baslangic: state.extra as YakalaGirdisi?,
                    yazabilir: k.asistanKullanabilir,
                    islerOkuyabilir: k.islerOkuyabilir,
                    sahip: k.sahip,
                  );
                }),
              ),
            ),
          ]),
          // Alışkanlıklar
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotalar.aliskanliklar,
              builder: (context, state) => _sayfa(
                (c) => AliskanlikListeViewModel(repo: c.read<AliskanlikRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
                (vm) => AliskanlikListeScreen(viewModel: vm),
              ),
            ),
          ]),
          // Beyin
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotalar.beyin,
              builder: (context, state) => _sayfa(
                (c) => ProjeListeViewModel(repo: c.read<BeyinRepository>())..yukle(),
                (vm) => BeyinScreen(viewModel: vm),
              ),
            ),
          ]),
        ],
      ),
      // The old tabs' addresses lead to where their content went.
      GoRoute(path: Rotalar.eskiHatirlaticilar, redirect: (_, _) => Rotalar.takvim),
      // A day's address (a result's or a notification's `/gun/{tarih}`, sözleşme E8): the Takvim tab on that day.
      GoRoute(
        path: '/gun/:tarih',
        redirect: (_, state) {
          final tarih = state.pathParameters['tarih'];
          return gunMetnindenTarih(tarih) == null ? Rotalar.takvim : '${Rotalar.takvim}?gun=$tarih';
        },
      ),
      GoRoute(path: Rotalar.eskiDahaFazla, redirect: (_, _) => Rotalar.bugun),
      GoRoute(
        path: Rotalar.bildirimler,
        builder: (context, state) => _sayfa(
          (c) => BildirimlerViewModel(
            repo: c.read<BildirimRepository>(),
            hatirlaticilar: c.read<HatirlaticiRepository>(),
            esitleyici: c.read<Esitleyici>(),
          )..yukle(),
          (vm) => BildirimlerScreen(viewModel: vm, yazabilir: kullanici.sahip),
        ),
      ),
      GoRoute(
        path: Rotalar.gelen,
        builder: (context, state) => _sayfa(
          (c) => GelenListeViewModel(
            repo: c.read<GelenRepository>(),
            eylemler: c.read<EylemRepository>(),
            yakalamalar: c.read<YakalamaRepository>(),
            esitleyici: c.read<Esitleyici>(),
            beyin: c.read<BeyinRepository>(),
          )..yukle(),
          (vm) => GelenListeScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: Rotalar.ara,
        builder: (context, state) => _sayfa(
          (c) => AraViewModel(repo: c.read<BeyinRepository>()),
          (vm) => AraScreen(viewModel: vm, baslangicSorgusu: state.uri.queryParameters['q']),
        ),
      ),
      // Full-screen pages above the tabs. `yeni` must come before `:id`.
      GoRoute(
        path: Rotalar.projeler,
        builder: (context, state) => _sayfa(
          (c) => ProjeListeViewModel(repo: c.read<BeyinRepository>())..yukle(),
          (vm) => ProjeListeScreen(viewModel: vm),
        ),
      ),
      // The work card board, the new card form and a card. `yeni` comes before `:kimlik`; `/asistan` itself is the tab.
      GoRoute(
        path: Rotalar.isler,
        builder: (context, state) => _sayfa(
          (c) => AsistanPanoViewModel(repo: c.read<IsRepository>())..yukle(),
          (vm) => AsistanPanoScreen(viewModel: vm, yazabilir: kullanici.sahip),
        ),
      ),
      GoRoute(
        path: Rotalar.asistanYeni,
        builder: (context, state) => _sayfa(
          (c) => IsFormViewModel(repo: c.read<IsRepository>(), beyin: c.read<BeyinRepository>()),
          (vm) => IsFormScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: '/asistan/:kimlik',
        builder: (context, state) => _sayfa(
          (c) => IsDetayViewModel(repo: c.read<IsRepository>(), kimlik: state.pathParameters['kimlik']!, yazabilir: kullanici.sahip)..yukle(),
          (vm) => IsDetayScreen(viewModel: vm),
        ),
      ),
      // The same card under the board's address (`/isler`).
      GoRoute(
        path: '/isler/:kimlik',
        builder: (context, state) => _sayfa(
          (c) => IsDetayViewModel(repo: c.read<IsRepository>(), kimlik: state.pathParameters['kimlik']!, yazabilir: kullanici.sahip)..yukle(),
          (vm) => IsDetayScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: Rotalar.yonetim,
        builder: (context, state) => _sayfa(
          (c) => YonetimViewModel(api: c.read<ApiService>())..yukle(),
          (vm) => YonetimScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: Rotalar.sifre,
        builder: (context, state) => _sayfa(
          (c) => SifreViewModel(
            api: c.read<ApiService>(),
            auth: c.read<AuthRepository>(),
            email: () => c.read<KullaniciRepository>().ben?.email,
          ),
          (vm) => SifreScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: '/projeler/:kimlik',
        builder: (context, state) => _sayfa(
          (c) => ProjeDetayViewModel(
            repo: c.read<BeyinRepository>(),
            gunPlani: c.read<GunPlaniRepository>(),
            esitleyici: c.read<Esitleyici>(),
            kimlik: state.pathParameters['kimlik']!,
          )..yukle(),
          (vm) => ProjeDetayScreen(viewModel: vm),
        ),
      ),
      // A note, by its vault path: /not?yol=projects/kitap-kulubu/notlar/x.md
      GoRoute(
        path: '/not',
        builder: (context, state) => _sayfa(
          (c) => NotViewModel(repo: c.read<BeyinRepository>(), yol: state.uri.queryParameters['yol'] ?? '')..yukle(),
          (vm) => NotScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: Rotalar.yakala,
        builder: (context, state) => _sayfa(
          (c) => YakalaViewModel(
            repo: c.read<YakalamaRepository>(),
            esitleyici: c.read<Esitleyici>(),
            beyin: c.read<BeyinRepository>(),
          ),
          // Dictation and the voice tools only for a new capture, not for the edit of one that waits.
          (vm) => _sayfa(
            (c) => SesViewModel(api: c.read<ApiService>(), dikte: SpeechDikteServisi(), baglanti: baglantiServisi()),
            (ses) => YakalaScreen(viewModel: vm, sesViewModel: ses, baslangic: state.extra as YakalaGirdisi?),
          ),
        ),
      ),
      GoRoute(
        path: '/yakalama/:id/duzenle',
        builder: (context, state) => _sayfa(
          (c) => YakalaViewModel(
            repo: c.read<YakalamaRepository>(),
            esitleyici: c.read<Esitleyici>(),
            beyin: c.read<BeyinRepository>(),
            duzenlenenId: state.pathParameters['id'],
          )..yukle(),
          (vm) => YakalaScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: Rotalar.eylemler,
        builder: (context, state) => _sayfa(
          (c) => EylemListeViewModel(repo: c.read<EylemRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
          (vm) => EylemListeScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: '/eylem/:id',
        builder: (context, state) => _sayfa(
          (c) => EylemDetayViewModel(
            repo: c.read<EylemRepository>(),
            esitleyici: c.read<Esitleyici>(),
            id: state.pathParameters['id']!,
          )..yukle(),
          (vm) => EylemDetayScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: '/hatirlatici/yeni',
        builder: (context, state) => _sayfa(
          (c) => HatirlaticiFormViewModel(
            repo: c.read<HatirlaticiRepository>(),
            esitleyici: c.read<Esitleyici>(),
            bildirim: c.read<HatirlaticiBildirimYoneticisi>(),
          ),
          (vm) => HatirlaticiFormScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: '/hatirlatici/:id/duzenle',
        builder: (context, state) => _sayfa(
          (c) => HatirlaticiFormViewModel(
            repo: c.read<HatirlaticiRepository>(),
            esitleyici: c.read<Esitleyici>(),
            bildirim: c.read<HatirlaticiBildirimYoneticisi>(),
            duzenlenenId: state.pathParameters['id'],
          )..yukle(),
          (vm) => HatirlaticiFormScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: '/aliskanlik/yeni',
        builder: (context, state) => _sayfa(
          (c) => AliskanlikFormViewModel(repo: c.read<AliskanlikRepository>()),
          (vm) => AliskanlikFormScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: '/aliskanlik/:id',
        builder: (context, state) => _sayfa(
          (c) => AliskanlikDetayViewModel(repo: c.read<AliskanlikRepository>(), id: state.pathParameters['id']!)..yukle(),
          (vm) => AliskanlikDetayScreen(viewModel: vm),
        ),
        routes: [
          // A Raf habit's shelf page (no tab of its own; reached from the habit, as on the web).
          GoRoute(
            path: 'raf',
            builder: (context, state) => _sayfa(
              (c) => RafViewModel(
                repo: c.read<AliskanlikRepository>(),
                esitleyici: c.read<Esitleyici>(),
                aliskanlikId: state.pathParameters['id']!,
              )..yukle(),
              (vm) => RafScreen(viewModel: vm),
            ),
          ),
          GoRoute(
            path: 'duzenle',
            builder: (context, state) => _sayfa(
              (c) => AliskanlikFormViewModel(
                repo: c.read<AliskanlikRepository>(),
                duzenlenenId: state.pathParameters['id'],
              )..yukle(),
              (vm) => AliskanlikFormScreen(viewModel: vm),
            ),
          ),
          GoRoute(
            path: 'kronometre',
            builder: (context, state) => _sayfa(
              (c) => KronometreViewModel(repo: c.read<KronometreRepository>(), hedefId: state.pathParameters['id']!),
              (kronometre) => Builder(
                builder: (context) => SayacKronometreScreen(
                  aliskanlikId: state.pathParameters['id']!,
                  kronometre: kronometre,
                  repo: context.read<AliskanlikRepository>(),
                  esitleyici: context.read<Esitleyici>(),
                ),
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/raf/:aliskanlikId/oge-yeni',
        builder: (context, state) => _sayfa(
          (c) => OgeFormViewModel(
            repo: c.read<AliskanlikRepository>(),
            aliskanlikId: state.pathParameters['aliskanlikId'],
          )..yukle(),
          (vm) => OgeFormScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: '/oge/:id',
        builder: (context, state) => _sayfa(
          (c) => OgeDetayViewModel(
            repo: c.read<AliskanlikRepository>(),
            esitleyici: c.read<Esitleyici>(),
            id: state.pathParameters['id']!,
          )..yukle(),
          (vm) => OgeDetayScreen(viewModel: vm),
        ),
        routes: [
          GoRoute(
            path: 'duzenle',
            builder: (context, state) => _sayfa(
              (c) => OgeFormViewModel(
                repo: c.read<AliskanlikRepository>(),
                duzenlenenId: state.pathParameters['id'],
              )..yukle(),
              (vm) => OgeFormScreen(viewModel: vm),
            ),
          ),
          GoRoute(
            path: 'oturum',
            builder: (context, state) => _sayfa(
              (c) => OturumViewModel(
                repo: c.read<AliskanlikRepository>(),
                esitleyici: c.read<Esitleyici>(),
                kronometre: KronometreViewModel(
                  repo: c.read<KronometreRepository>(),
                  hedefId: state.pathParameters['id']!,
                ),
                ogeId: state.pathParameters['id']!,
              )..yukle(),
              (vm) => OturumScreen(viewModel: vm),
            ),
          ),
        ],
      ),
    ],
  );
}
