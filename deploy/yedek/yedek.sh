#!/usr/bin/env bash
# Morning backup of Kafamdakiler (after the brain's day turns at 05:00) (Kat 2 karar 5): a pg_dump of the database plus everything under
# /srv/kafamdakiler except the git clone, encrypted by restic and sent to Backblaze B2.
# Run by kafamdakiler-yedek.service as root. Settings: /srv/kafamdakiler/yedek/restic.env (root, 600).
set -euo pipefail

PROJE=/srv/kafamdakiler
DOKUM="$PROJE/yedek/kafamdakiler.dump"

set -a
# shellcheck source=/dev/null
. "$PROJE/yedek/restic.env"
# POSTGRES_USER and POSTGRES_DB come from the app's own env file.
# shellcheck source=/dev/null
. "$PROJE/.env"
set +a

# 1. Database: a consistent dump taken inside the running container (custom format, restored with pg_restore).
docker compose --project-directory "$PROJE/app/deploy" exec -T db \
    pg_dump --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --format=custom > "$DOKUM.tmp"
mv "$DOKUM.tmp" "$DOKUM"

# 2. Files: photos, Data Protection keys, the sample brain, the env file and the dump. The clone is left out:
#    it is on GitHub.
restic backup "$PROJE" --exclude "$PROJE/app" --tag kafamdakiler --host kafamdakiler

# 3. Keep 7 daily, 4 weekly and 6 monthly snapshots; drop the rest.
restic forget --tag kafamdakiler --host kafamdakiler \
    --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

# 4. On Sundays, check that the repository is readable (a sample of the data, to keep B2 traffic low).
if [ "$(date +%u)" = 7 ]; then
    restic check --read-data-subset=5%
fi
