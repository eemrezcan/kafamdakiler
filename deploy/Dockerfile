# Kafamdakiler API image (K-0020, Kat 2 K2.1).
# Build from the repository root:  docker build -f deploy/Dockerfile -t kafamdakiler .

# Stage 1: compile and publish the app.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# The project file alone first: the restore layer stays cached until a package changes.
# linux-x64 only (the server is amd64): without a runtime identifier the publish carries SkiaSharp's native
# libraries for every platform (Windows, macOS, musl...), about 400 MB of dead weight.
COPY backend/Kafamdakiler.csproj backend/
RUN dotnet restore backend/Kafamdakiler.csproj -r linux-x64

COPY backend/ backend/
RUN dotnet publish backend/Kafamdakiler.csproj -c Release -r linux-x64 --self-contained false -o /app --no-restore

# Stage 2: the EF Core migration bundle, a single executable that applies the migrations without the SDK.
FROM build AS migrations
RUN dotnet tool install --global dotnet-ef --version 10.0.14
ENV PATH="${PATH}:/root/.dotnet/tools"
RUN dotnet ef migrations bundle --project backend/Kafamdakiler.csproj --configuration Release --output /out/efbundle

# Stage 3: the runtime image. No SDK and no source code.
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime

# beyin.py (K-0023) runs inside this container: Python 3 (standard library only) and git.
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 git \
    && rm -rf /var/lib/apt/lists/*

# Claude Code: the app calls it without tools (backend/Claude/). The image carries no binary: the host's single
# install is bind-mounted read-only at /usr/local/bin/claude (deploy/compose.yaml), so the version is the host's.
# Its login and settings live in /claude, a host folder, so a rebuilt image stays signed in.
ENV CLAUDE_CONFIG_DIR=/claude \
    DISABLE_AUTOUPDATER=1

WORKDIR /app
COPY --from=build /app .
COPY --from=migrations /out/efbundle ./efbundle

# /data holds the uploaded photos and the Data Protection keys (deploy/compose.yaml mounts a volume here).
# Owned by the app user: Docker copies this ownership into a new, empty named volume.
RUN mkdir -p /data/dosyalar /data/anahtarlar /claude && chown -R $APP_UID:$APP_UID /data /claude

# The non-root user that the .NET images ship with.
USER $APP_UID

# ASP.NET Core listens on plain HTTP 8080 by default (ASPNETCORE_HTTP_PORTS); TLS ends at `tailscale serve`.
EXPOSE 8080
ENTRYPOINT ["dotnet", "Kafamdakiler.dll"]
