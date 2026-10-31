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
