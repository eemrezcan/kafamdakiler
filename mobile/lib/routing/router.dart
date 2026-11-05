import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repositories/aliskanlik_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/esitleyici.dart';
import '../data/repositories/kronometre_repository.dart';
import '../data/repositories/kullanici_repository.dart';
import '../data/repositories/yakalama_repository.dart';
import '../ui/aliskanliklar/aliskanlik_detay_screen.dart';
import '../ui/aliskanliklar/aliskanlik_detay_view_model.dart';
import '../ui/aliskanliklar/aliskanlik_form_screen.dart';
import '../ui/aliskanliklar/aliskanlik_form_view_model.dart';
import '../ui/aliskanliklar/aliskanlik_liste_screen.dart';
import '../ui/aliskanliklar/aliskanlik_liste_view_model.dart';
import '../ui/bugun/bugun_screen.dart';
import '../ui/bugun/bugun_view_model.dart';
import '../ui/giris/giris_screen.dart';
import '../ui/giris/giris_view_model.dart';
import '../ui/oturum/kronometre_view_model.dart';
import '../ui/oturum/oturum_screen.dart';
import '../ui/oturum/oturum_view_model.dart';
import '../ui/oturum/sayac_kronometre_screen.dart';
import '../ui/profil/profil_screen.dart';
import '../ui/profil/profil_view_model.dart';
import '../ui/raf/oge_detay_screen.dart';
import '../ui/raf/oge_detay_view_model.dart';
import '../ui/raf/oge_form_screen.dart';
import '../ui/raf/oge_form_view_model.dart';
import '../ui/raf/raf_screen.dart';
import '../ui/raf/raf_view_model.dart';
import '../ui/shell/ana_iskele.dart';
import '../ui/yakalama/yakala_screen.dart';
import '../ui/yakalama/yakala_view_model.dart';
import '../ui/yakalama/yakalama_liste_screen.dart';
import '../ui/yakalama/yakalama_liste_view_model.dart';

abstract final class Rotalar {
  static const bugun = '/';
  static const aliskanliklar = '/aliskanliklar';
  static const yakalamalar = '/yakalamalar';
  static const yakala = '/yakala';
  static const profil = '/profil';
  static const giris = '/giris';
}

final _yonetimRotalari = [
  RegExp(r'^/aliskanlik/yeni$'),
  RegExp(r'^/aliskanlik/[^/]+/duzenle$'),
  RegExp(r'^/raf/[^/]+/oge-yeni$'),
  RegExp(r'^/oge/[^/]+/duzenle$'),
  RegExp(r'^/yakala$'),
  RegExp(r'^/yakalama/[^/]+/duzenle$'),
];

/// Where a visit to [konum] must be sent instead, or null to let it through.
///
/// - Signed-out users only see the login screen.
/// - The forms that create or change content (captures included) are for the
///   Sahip role only; the route is blocked, not just the button hidden (M07).
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
              builder: (context, state) => _sayfa(
                (c) => BugunViewModel(repo: c.read<AliskanlikRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
                (vm) => BugunScreen(viewModel: vm),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rotalar.aliskanliklar,
              builder: (context, state) => _sayfa(
                (c) => AliskanlikListeViewModel(repo: c.read<AliskanlikRepository>())..yukle(),
                (vm) => AliskanlikListeScreen(viewModel: vm),
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
        path: Rotalar.yakala,
        builder: (context, state) => _sayfa(
          (c) => YakalaViewModel(repo: c.read<YakalamaRepository>(), esitleyici: c.read<Esitleyici>()),
          (vm) => YakalaScreen(viewModel: vm),
        ),
      ),
      GoRoute(
        path: '/yakalama/:id/duzenle',
        builder: (context, state) => _sayfa(
          (c) => YakalaViewModel(
            repo: c.read<YakalamaRepository>(),
            esitleyici: c.read<Esitleyici>(),
            duzenlenenId: state.pathParameters['id'],
          )..yukle(),
          (vm) => YakalaScreen(viewModel: vm),
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
