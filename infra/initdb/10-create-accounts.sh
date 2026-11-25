#!/bin/bash
# MySQL 컨테이너가 빈 데이터 볼륨을 처음 초기화 할 때 딱 한 번 실행됨

set -euo pipefail
DB_NAME="${MYSQL_DATABASE:?MYSQL_DATABASE is not set in compose.yaml}"
OWNER_PW="$(cat /run/secrets/db_owner_password)"
APP_PW="$(cat /run/secrets/db_app_password)"

ROOT_CNF="$(mktemp)"
trap 'rm -f "$ROOT_CNF"' EXIT
chmod 600 "$ROOT_CNF"
printf '[client]\nuser=root\npassword=%s\n' "$(cat /run/secrets/db_root_password)" > "$ROOT_CNF"

mysql --defaults-extra-file="$ROOT_CNF" --protocol=socket <<SQL
CREATE USER 'GW_OWNER'@'%' IDENTIFIED BY '${OWNER_PW}';
CREATE USER 'GW_APP'@'%' IDENTIFIED BY '${APP_PW}';
-- GW_OWNER: groupware DB 안에서만 테이블, 뷰, 트리거, 프로시저를 만들고, 마이그레이션 파일에서 GW_APP에 테이블별 권한을 나눠줌
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, INDEX, REFERENCES, CREATE VIEW, SHOW VIEW, TRIGGER, CREATE ROUTINE, ALTER ROUTINE, EXECUTE ON \`${DB_NAME}\`.* TO 'GW_OWNER'@'%' WITH GRANT OPTION;
-- GW_APP: DB 전체 읽기만, 쓰기는 테이블을 만드는 마이그레이션 파일마다 따로 준다.
GRANT SELECT ON \`${DB_NAME}\`.* TO 'GW_APP'@'%';
SQL
