import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repositories/aliskanlik_repository.dart';
import '../data/models/yakala_girdisi.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/beyin_repository.dart';
import '../data/repositories/esitleyici.dart';
import '../data/repositories/gun_plani_repository.dart';
import '../data/repositories/eylem_repository.dart';
import '../data/repositories/gelen_repository.dart';
import '../data/repositories/hatirlatici_bildirim_yoneticisi.dart';
import '../data/repositories/hatirlatici_repository.dart';
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
import '../ui/bugun/bugun_screen.dart';
import '../ui/bugun/bugun_view_model.dart';
import '../ui/bugun/gun_plani_view_model.dart';
import '../ui/bugun/onay_bekleyen_view_model.dart';
import '../ui/eylemler/eylem_detay_screen.dart';
import '../ui/eylemler/eylem_detay_view_model.dart';
import '../ui/eylemler/eylem_liste_screen.dart';
import '../ui/eylemler/eylem_liste_view_model.dart';
import '../ui/gelen/gelen_liste_screen.dart';
import '../ui/gelen/gelen_liste_view_model.dart';
import '../ui/bugun/yaklasanlar_view_model.dart';
import '../ui/giris/giris_screen.dart';
import '../ui/hatirlaticilar/hatirlatici_form_screen.dart';
import '../ui/hatirlaticilar/hatirlatici_form_view_model.dart';
import '../ui/hatirlaticilar/hatirlatici_liste_screen.dart';
import '../ui/hatirlaticilar/hatirlatici_liste_view_model.dart';
import '../ui/giris/giris_view_model.dart';
import '../ui/oturum/kronometre_view_model.dart';
import '../ui/oturum/oturum_screen.dart';
import '../ui/oturum/oturum_view_model.dart';
import '../ui/oturum/sayac_kronometre_screen.dart';
import '../ui/profil/profil_screen.dart';
import '../ui/profil/profil_view_model.dart';
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
import '../ui/yakalama/yakalama_liste_screen.dart';
import '../ui/yakalama/yakalama_liste_view_model.dart';
import '../ui/yonetim/yonetim_screen.dart';
import '../ui/yonetim/yonetim_view_model.dart';

abstract final class Rotalar {
  static const bugun = '/';

  /// The habit list: opened from Profil, a full-screen page (not a tab).
  static const aliskanliklar = '/aliskanliklar';
  static const projeler = '/projeler';
  static const ara = '/ara';
  static const yakalamalar = '/yakalamalar';
  static const yakala = '/yakala';

  /// The reminders list: opened from the Today card and from Profil, a full-screen page (not a tab).
  static const hatirlaticilar = '/hatirlaticilar';

  /// The approval queue: opened from the Today card, from Profil and from its notifications, a full-screen page.
  static const eylemler = '/eylemler';

  /// The inbox: opened from Profil, a full-screen page.
  static const gelen = '/gelen';
  static const profil = '/profil';

  /// The Sahip's management screen: opened from Profil, a full-screen page.
  static const yonetim = '/yonetim';

  /// "Şifremi değiştir": opened from Profil, a full-screen page for every signed-in user.
  static const sifre = '/sifre';
  static const giris = '/giris';
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

/// True when Yakala is the screen on top. The top route is read from the match list: after a `push`
/// the router's `uri` still shows the page underneath.
bool yakalaUstte(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation == Rotalar.yakala;

GoRouter routerOlustur(AuthRepository auth, KullaniciRepository kullanici) {
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
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotalar.bugun,
              builder: (context, state) => MultiProvider(
                providers: [
                  ChangeNotifierProvider(
                    create: (c) => BugunViewModel(repo: c.read<AliskanlikRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
                  ),
                  ChangeNotifierProvider(create: (c) => GunPlaniViewModel(repo: c.read<GunPlaniRepository>(), esitleyici: c.read<Esitleyici>())..yukle()),
                  ChangeNotifierProvider(
                    create: (c) => YaklasanlarViewModel(repo: c.read<HatirlaticiRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
                  ),
                  ChangeNotifierProvider(
                    create: (c) => OnayBekleyenViewModel(repo: c.read<EylemRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
                  ),
                ],
                child: Builder(
                  builder: (context) => BugunScreen(
                    viewModel: context.read<BugunViewModel>(),
                    gunPlani: context.read<GunPlaniViewModel>(),
                    yaklasanlar: context.read<YaklasanlarViewModel>(),
                    onayBekleyen: context.read<OnayBekleyenViewModel>(),
                  ),
                ),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotalar.projeler,
              builder: (context, state) => _sayfa(
                (c) => ProjeListeViewModel(repo: c.read<BeyinRepository>())..yukle(),
                (vm) => ProjeListeScreen(viewModel: vm),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotalar.yakalamalar,
              builder: (context, state) => _sayfa(
                (c) => YakalamaListeViewModel(repo: c.read<YakalamaRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
                (vm) => YakalamaListeScreen(viewModel: vm),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotalar.ara,
              builder: (context, state) => _sayfa(
                (c) => AraViewModel(repo: c.read<BeyinRepository>()),
                (vm) => AraScreen(viewModel: vm),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotalar.profil,
              builder: (context, state) => _sayfa(
                (c) => ProfilViewModel(repo: c.read<AliskanlikRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
                (vm) => ProfilScreen(viewModel: vm),
              ),
            ),
          ]),
        ],
      ),
      // Full-screen pages above the tabs. `yeni` must come before `:id`.
      GoRoute(
        path: Rotalar.aliskanliklar,
        builder: (context, state) => _sayfa(
          (c) => AliskanlikListeViewModel(repo: c.read<AliskanlikRepository>())..yukle(),
          (vm) => AliskanlikListeScreen(viewModel: vm),
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
          (c) => ProjeDetayViewModel(repo: c.read<BeyinRepository>(), kimlik: state.pathParameters['kimlik']!)..yukle(),
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
            (c) => SesViewModel(api: c.read<ApiService>(), dikte: SpeechDikteServisi(), baglanti: ConnectivityBaglantiServisi()),
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
        path: Rotalar.hatirlaticilar,
        builder: (context, state) => _sayfa(
          (c) => HatirlaticiListeViewModel(repo: c.read<HatirlaticiRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
          (vm) => HatirlaticiListeScreen(viewModel: vm),
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
        path: Rotalar.gelen,
        builder: (context, state) => _sayfa(
          (c) => GelenListeViewModel(
            repo: c.read<GelenRepository>(),
            eylemler: c.read<EylemRepository>(),
            esitleyici: c.read<Esitleyici>(),
            beyin: c.read<BeyinRepository>(),
          )..yukle(),
          (vm) => GelenListeScreen(viewModel: vm),
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
