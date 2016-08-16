#!/usr/bin/env bash
set -eux

source ./utils/env.sh

start() {
  [ $FORCE_PULL = 'true' ] && docker pull $ZK_IMAGE:$ZK_IMAGE_VERSION

  docker run \
    -d \
    -p 2181:2181 \
    --name zookeeper \
    $ZK_IMAGE:$ZK_IMAGE_VERSION

  sleep 3
}

stop() {
  docker stop zookeeper > /dev/null 2>&1 || true
  docker rm zookeeper > /dev/null 2>&1 || true
}

case "$1" in
  start)
    echo "[zookeeper] starting $ZK_IMAGE:$ZK_IMAGE_VERSION"
    stop
    start
    echo "[zookeeper] started"
    ;;
  stop)
    printf "[zookeeper] stopping... "
    stop
    echo "Done"
    ;;
esac
