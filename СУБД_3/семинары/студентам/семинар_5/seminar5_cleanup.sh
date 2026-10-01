#!/usr/bin/env bash
# seminar5_cleanup.sh (студенческий контекст)
# Удаляет базу demo и роли семинара №5.

set -euo pipefail

export MSYS_NO_PATHCONV=1

CONTAINER="pg16_check"
ROLES=("bank_manager" "agro_analyst")

for role in "${ROLES[@]}"; do
    for db in postgres demo template1; do
        docker exec -i "${CONTAINER}" \
          psql -U postgres -d "${db}" -c "DO \$\$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${role}') THEN EXECUTE 'REASSIGN OWNED BY ${role} TO postgres'; EXECUTE 'DROP OWNED BY ${role}'; END IF; END \$\$;" || true
    done
    docker exec -i "${CONTAINER}" \
      psql -U postgres -d postgres -c "DROP ROLE IF EXISTS ${role};"
done

docker exec -i "${CONTAINER}" \
  psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS demo;"

echo "-- seminar5 cleanup done"
