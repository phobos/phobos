#!/usr/bin/env bash
set -eux

source ./utils/env.sh

start() {
  [ $FORCE_PULL = 'true' ] && docker pull $KAFKA_IMAGE:$KAFKA_IMAGE_VERSION
  ZK_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' zookeeper)

  docker run \
    -d \
    -p 9092:9092 \
    --name kafka \
    -e KAFKA_BROKER_ID=0 \
    -e KAFKA_ADVERTISED_HOST_NAME=localhost \
    -e KAFKA_ADVERTISED_PORT=9092 \
    -e ZOOKEEPER_CONNECTION_STRING=zookeeper:2181 \
    --link zookeeper:zookeeper \
    $KAFKA_IMAGE:$KAFKA_IMAGE_VERSION

  # The following statement waits until kafka is up and running
  docker exec kafka bash -c "JMX_PORT=9998 ./bin/kafka-topics.sh --zookeeper $ZK_IP:2181 --list 2> /dev/null"
  [ $? != '0' ] && echo "[kafka] failed to start"
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
