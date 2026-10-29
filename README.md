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

## Run
```bash
dotnet run --project backend
```

Open the URL printed as `Now listening on`. Health check: `GET /saglik` returns `Healthy` when the database is reachable, `Unhealthy` (503) otherwise.

## Migrations
The schema is created with EF Core migrations. The first migration arrives with the Identity tables.

```bash
dotnet tool install --global dotnet-ef   # once
dotnet ef database update --project backend
```

## Tests
```bash
dotnet test
```
