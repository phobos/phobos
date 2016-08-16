#!/usr/bin/env bash
set -eu

UTILS_DIR=$(dirname $0)
source ${UTILS_DIR}/env.sh

ZK_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' zookeeper)
TOPIC=${TOPIC:='test'}
PARTITIONS=${PARTITIONS:=2}

echo "creating topic ${TOPIC}, partitions ${PARTITIONS}"
docker run --rm $KAFKA_IMAGE:$KAFKA_IMAGE_VERSION kafka-topics.sh \
  --create \
  --topic $TOPIC \
  --replication-factor 1 \
  --partitions $PARTITIONS \
  --zookeeper $ZK_IP:2181
