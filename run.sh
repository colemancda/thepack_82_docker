#!/usr/bin/env bash
set -u

# Builds and runs the MySQL + OdinMS (ThePack v62) containers.
#   ./run.sh         run the servers in the foreground (Ctrl-C stops and cleans up)
#   ./run.sh shell   drop into a shell in the odinms container instead

MYSQL=thepack_mysql
ODINMS=thepack_odinms

docker build -t odinms_mysql odinms_mysql || exit 1
docker build -t odinms odinms || exit 1

docker rm -f $MYSQL $ODINMS >/dev/null 2>&1

# nofile is capped because old mysqld sizes its allocations from the container's
# open-files limit, which is huge by default and makes it grow to 16GB+.
docker run -d --name $MYSQL --ulimit nofile=1024:1024 -p 3306:3306 odinms_mysql >/dev/null || exit 1
trap 'docker rm -f $MYSQL $ODINMS >/dev/null 2>&1' EXIT

# The entrypoint imports thepack.sql on a temporary socket-only server and then
# restarts mysqld with networking, so wait until it answers over TCP.
echo "Waiting for MySQL to finish importing..."
until docker exec $MYSQL mysql -h127.0.0.1 -uroot -proot -e 'use odinms' >/dev/null 2>&1; do
    sleep 2
done

ODINMS_MYSQL_CONTAINER_IP_ADDRESS=`docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $MYSQL`

if [ "${1:-}" = "shell" ]; then
    CMD=bash
else
    CMD='cd /odinms && source compile_and_run.sh; wait'
fi

TTY=; [ -t 0 ] && TTY=-it

docker run $TTY --rm --name $ODINMS \
    -e ODINMS_MYSQL_CONTAINER_IP_ADDRESS=$ODINMS_MYSQL_CONTAINER_IP_ADDRESS \
    -p 7575:7575 -p 7576:7576 -p 7577:7577 -p 7578:7578 -p 8484:8484 \
    odinms bash -c "$CMD"
