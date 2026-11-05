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

## Tests
```bash
dotnet test
```

The tests that touch the database create a throwaway PostgreSQL database on the server from your user-secrets connection string (or from the environment variable `KAFAMDAKILER_TEST_DB`), so run `docker compose up -d` first. Without a server they are skipped with a message. The brain client tests need `python3`.
