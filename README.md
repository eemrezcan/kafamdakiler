# Kafamdakiler

Personal tracking app: training, tasks and promises, reminders, reading, weight, notes.
ASP.NET Core Razor Pages + Web API (.NET 10), PostgreSQL, EF Core. A Flutter (Android) client will follow.

Course project for BLM4581 (web) and BLM4587 (mobile).

## Requirements
- .NET 10 SDK
- Docker with Compose

## Project layout
| Path | What |
| --- | --- |
| `backend/` | ASP.NET Core app: Razor Pages and `/api` endpoints |
| `backend.Tests/` | xUnit v3 tests |
| `compose.yaml` | PostgreSQL for local development |
| `docs/` | Decisions (`docs/kararlar/`) and project notes |
| `ornek-beyin/` | Sample "second brain" (Markdown notes, all made up) used in development, tests and demos. Treat it as read-only: the API works on a git-ignored copy, `.ornek-beyin-calisma/` (see "Brain" below) |

## Database
PostgreSQL 18 runs in Docker. Credentials live in `.env`, which is git-ignored; only the empty template `.env.example` is committed.

```bash
cp .env.example .env
chmod 600 .env
# put a password into POSTGRES_PASSWORD, e.g. from: openssl rand -base64 24
docker compose up -d
docker compose ps   # db should be (healthy)
```

The port is bound to `127.0.0.1` only. Data is kept in the named volume `pgdata`: `docker compose down` keeps it, `docker compose down -v` deletes it.

## Configuration
The connection string is not stored in the repository. In development it comes from user secrets:

```bash
dotnet user-secrets set "ConnectionStrings:Default" \
  "Host=localhost;Port=5432;Database=kafamdakiler;Username=kafamdakiler;Password=$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)" \
  --project backend
```

On a server the same key is given as the environment variable `ConnectionStrings__Default`.

The two seed accounts (roles `Sahip` and `Asistan`) are created on startup from these keys. The app does not start without them:

```bash
dotnet user-secrets set "Seed:SahipEmail" "<email>" --project backend
dotnet user-secrets set "Seed:SahipPassword" "<password>" --project backend
dotnet user-secrets set "Seed:AsistanEmail" "<email>" --project backend
dotnet user-secrets set "Seed:AsistanPassword" "<password>" --project backend
dotnet user-secrets list --project backend   # check that the keys exist
```

Uploaded photos are stored on disk, outside `wwwroot`. The folder comes from `Dosyalar:Klasor`: in development it is `.dosyalar/` at the repository root (git-ignored, set in `appsettings.Development.json`); on a server set it with the environment variable `Dosyalar__Klasor`.

## Brain
Captures that wait in the app are sent to the second brain as inbox cards by calling its command, `beyin.py gelen ekle` (K-0023). The app does not write to the brain any other way. The `Beyin` settings:

| Key | Meaning |
| --- | --- |
| `Beyin:Komut` | Path of `beyin.py`. Not in the repository (it is a path on your machine): set it in user-secrets, see below. Empty = brain features off; the rest of the app and the tests still work |
| `Beyin:Vault` | The vault folder passed as `--vault` to every command |
| `Beyin:Sablon` | Development only: where `Beyin:Vault` is copied from when it does not exist yet |
| `Beyin:GonderimGecikmesiDakika` | A capture goes to the brain this many minutes after its last edit (default 10) |
| `Beyin:GonderimAraligiSaniye`, `Beyin:ZamanAsimiSaniye` | How often the sender looks (30), and how long one command may run (30) |

Tell the app where `beyin.py` is (once per machine; on a server use the environment variable `Beyin__Komut`):

```bash
dotnet user-secrets set "Beyin:Komut" "/path/to/brain/sistem/beyin.py" --project backend
```

The tests that run the real `beyin.py` read the same key (or the environment variable `KAFAMDAKILER_BEYIN_KOMUT`) and are skipped without it.

In development `appsettings.Development.json` points `Beyin:Vault` at `.ornek-beyin-calisma/` and `Beyin:Sablon` at `ornek-beyin/`. When the app starts and `.ornek-beyin-calisma/` is missing, it copies `ornek-beyin/` there. The template itself is never written to. To reset the copy to the template, stop the app, delete the folder, start the app again:

```bash
rm -r .ornek-beyin-calisma
dotnet run --project backend
```

A capture is claimed before it is sent, so it never becomes two cards. If a send times out or its output cannot be read, the card may already exist: the capture stays marked (`SonHata` says so) and is not sent again by itself.

The brain is also read through `/api/beyin` (tag "Beyin" in Scalar), for the `Sahip` role or the `beyin.oku` permission: `GET /durum`, `/projeler`, `/projeler/{kimlik}`, `/gunler/{yyyy-MM-dd}`, `/ara?q=&proje=&limit=`, `/not?yol=`. Hidden notes and projects (`gizli: true`) never come out of these. Without a configured brain they answer 503. A ready-made scenario is in `backend/Beyin/beyin.http`.

PNG and WebP photos are converted to JPEG on the server (SkiaSharp) because `gelen ekle` only takes JPEG.

## App version check
`GET /api/surum` (anonymous) returns `{ "enAzMobilSurumKodu": N }` from the setting `Mobil:EnAzSurumKodu` (default 1; on a server the environment variable `Mobil__EnAzSurumKodu`). The app compares its build number (the `+N` in `mobile/pubspec.yaml`) with it at start and when it returns to the foreground; a lower build shows a blocking "update needed" screen, and offline or on any error the app carries on. Raise the setting only after a breaking API change, together with a new app build whose `+N` is at least that value.

Reminders: the hour used when a reminder has none comes from `Hatirlatici:VarsayilanSaat` (Istanbul time, default `09:00`; on a server the environment variable `Hatirlatici__VarsayilanSaat`).

## Reminders API
Under `/api/hatirlaticilar` (permissions `hatirlatici.oku` for reading, `hatirlatici.yaz` for writing; the Sahip always passes):

- `GET /` list, sorted by the effective moment; filters `?durum=acik|tamam|arsiv` and `?yaklasan=N` (open ones due within N days, overdue included)
- `GET /{id}`, `POST /`, `PUT /{id}`, `DELETE /{id}`
- `POST /{id}/yaptim` done: a repeating reminder moves to its next turn, a one-off becomes `tamam`
- `POST /{id}/ertele` with `{ "sure": "1s" | "yarin" }` snooze: one hour from now, or tomorrow at the reminder's hour

Examples: `backend/Hatirlaticilar/hatirlaticilar.http`.

## Migrations
The schema is created with EF Core migrations (Identity tables, then habits). Apply them before the first run and after pulling new ones:

```bash
dotnet tool install --global dotnet-ef   # once
export DOTNET_ROOT=$HOME/.dotnet         # dotnet ef needs this when .NET is installed under ~/.dotnet
dotnet ef database update --project backend
```

## Run
```bash
dotnet run --project backend
```

Open the URL printed as `Now listening on` and log in with the `Sahip` account. Health check: `GET /saglik` returns `Healthy` when the database is reachable, `Unhealthy` (503) otherwise.

## API documentation
In development the API is documented with Scalar at `<url>/scalar` (the OpenAPI document is at `<url>/openapi/v1.json`). Get a token from `POST /api/hesap/login`, then paste the `accessToken` into the Bearer field. A ready-made scenario (a book habit, a water counter, error cases) is in `backend/Aliskanliklar/aliskanliklar.http`.

## Mobile app
The Flutter (Android) client lives in `mobile/`; see [`mobile/README.md`](mobile/README.md) for the details. Short version, with the backend running on port 5051 and a phone connected over USB:

```bash
cd mobile && flutter pub get
dart run build_runner build
adb reverse tcp:5051 tcp:5051
flutter run --dart-define=API_URL=http://localhost:5051
```

Capturing from outside the app (Sahip account only): "Kafamdakiler" appears in Android's share menu for text, links and images; the shared content opens Yakala with the text field or the photo filled in, and you edit and save as usual. Only the first image is taken when several are shared. Long-pressing the app icon shows a "Yakala" shortcut. The home screen widget "Kafamdakiler · Yakala" (add it from the launcher's widget list) opens Yakala the same way; its tap reuses the `quick_actions` plugin's launch extra, so keep `YakalaWidget.kt` in step if that plugin is upgraded. When you are signed out, the shared content waits and Yakala opens with it right after you sign in; with the Asistan account it is dropped with a short message.

Reminder notifications: the phone schedules local notifications for every open reminder (its moment and, when set, the "N days before" heads-up). They are planned again after every sync and at every app start, and the plugin sets them up again after a restart. The first reminder you create asks for the notification permission (Android 13+) and, once per run, for the exact alarm permission; without it the notifications still come, only at an approximate time. The buttons on a notification (Yaptım, 1 saat ertele, Yarın) open the app, write to the offline queue there and send it. Limits: some phone makers (Xiaomi, Huawei, Samsung's battery savers and the like) stop apps from running in the background and may delay or drop scheduled notifications unless the app is excluded from battery optimisation; a reminder changed on another device is only picked up when this phone syncs (app start, return to the foreground, connectivity); when the phone has no connection the times come from the phone's own copy of the recurrence rules.

## Phone over Tailscale

Until the server exists, the laptop plays the server and the phone reaches it through [Tailscale](https://tailscale.com):

1. Install Tailscale on the laptop and the phone and sign in to the same tailnet. In the admin console enable MagicDNS and HTTPS certificates.
2. Run the API (`dotnet run --project backend --launch-profile http`), then expose it over HTTPS inside the tailnet:

   ```bash
   sudo tailscale serve --bg 5051
   ```

   `tailscale serve status` prints the address, e.g. `https://<machine>.<tailnet>.ts.net`. Only devices in your tailnet can reach it.
3. Build the app for the phone with that address: `flutter run --release --dart-define=API_URL=https://<machine>.<tailnet>.ts.net` (from `mobile/`, phone connected with USB debugging).

`sudo tailscale serve --https=443 off` stops it.

## Tests
```bash
dotnet test
```

The tests that touch the database create a throwaway PostgreSQL database on the server from your user-secrets connection string (or from the environment variable `KAFAMDAKILER_TEST_DB`), so run `docker compose up -d` first. Without a server they are skipped with a message. The brain client tests need `python3`.
