#!/bin/bash
set -eu

UTILS_DIR=$(dirname $0)
source ${UTILS_DIR}/env.sh

start() {
  [ $FORCE_PULL = 'true' ] && docker pull $KAFKA_IMAGE:$KAFKA_IMAGE_VERSION
  ZK_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' zookeeper)

  # Start kafka service
  docker run -d -p 9092:9092 --link zookeeper:zookeeper --name kafka \
    -e KAFKA_BROKER_ID=0 \
    -e KAFKA_ADVERTISED_HOST_NAME=localhost \
    -e KAFKA_ADVERTISED_PORT=9092 \
    -e ZOOKEEPER_CONNECTION_STRING=zookeeper:2181 \
    $KAFKA_IMAGE:$KAFKA_IMAGE_VERSION

  # The following statement waits until kafka is up and running
  docker run --rm --link zookeeper:zookeeper -e ZK_IP=$ZK_IP \
    $KAFKA_IMAGE:$KAFKA_IMAGE_VERSION kafka-topics.sh \
      --zookeeper $ZK_IP:2181 \
      --list

  if [ $? != '0' ]; then
    echo "[kafka] failed to start"
    false
  else
    true
  fi
}

stop() {
  docker stop kafka > /dev/null 2>&1 || true
  docker rm kafka > /dev/null 2>&1 || true
}

case "$1" in
  start)
    echo "[kafka] starting $KAFKA_IMAGE:$KAFKA_IMAGE_VERSION"
    stop
    start
    echo "[kafka] started"
    ;;
  stop)
    printf "[kafka] stopping... "
    stop
    echo "Done"
    ;;
esac
