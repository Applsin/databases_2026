#!/usr/bin/env bash
set -euo pipefail
C=pg16_check; DB=demo; U=postgres; D=60; N=32; J=8
export MSYS_NO_PATHCONV=1

docker ps --format '{{.Names}}' | grep -qx "$C" || { echo "container $C not running"; exit 1; }

docker exec -i "$C" psql -U "$U" -d "$DB" <<'SQL'
DROP TABLE IF EXISTS hot_serial, hot_uuid;
CREATE TABLE hot_serial (id BIGSERIAL PRIMARY KEY, payload TEXT);
CREATE TABLE hot_uuid   (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), payload TEXT);
SQL

docker exec "$C" sh -c "printf '%s\n' 'INSERT INTO hot_serial (payload) VALUES (md5(random()::text));' > /tmp/hot_serial.sql"
docker exec "$C" sh -c "printf '%s\n' 'INSERT INTO hot_uuid   (payload) VALUES (md5(random()::text));' > /tmp/hot_uuid.sql"

run() {
  local t=$1
  echo "=== $t ==="
  : > /tmp/w_$t
  docker exec "$C" pgbench -U "$U" -d "$DB" -n -c $N -j $J -T $D -f /tmp/hot_$t.sql > /tmp/b_$t.log 2>&1 &
  local p=$!
  while kill -0 $p 2>/dev/null; do
    docker exec "$C" psql -U "$U" -d "$DB" -tA -F'|' -c \
      "SELECT wait_event_type,wait_event,count(*) FROM pg_stat_activity
       WHERE state='active' AND query LIKE 'INSERT INTO hot_%' AND pid<>pg_backend_pid()
       GROUP BY 1,2" >> /tmp/w_$t 2>/dev/null || true
    sleep 1
  done
  wait $p || true
  grep -E 'number of transactions|^tps' /tmp/b_$t.log || true
  awk -F'|' 'NF>=3{s[$1"|"$2]+=$3} END{for(k in s) printf "%8d  %s\n",s[k],k}' /tmp/w_$t | sort -rn | head -5
}

run serial
run uuid

docker exec -i "$C" psql -U "$U" -d "$DB" <<'SQL'
SELECT 'hot_serial' AS tbl, count(*) FROM hot_serial
UNION ALL SELECT 'hot_uuid', count(*) FROM hot_uuid;
SELECT relname, pg_size_pretty(pg_relation_size(oid)) size FROM pg_class
WHERE relname IN ('hot_serial_pkey','hot_uuid_pkey') ORDER BY relname;
SQL