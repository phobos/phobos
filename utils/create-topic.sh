#!/bin/bash
set -eu

TOPIC=${TOPIC:='test'}
PARTITIONS=${PARTITIONS:=2}

echo "creating topic ${TOPIC}, partitions ${PARTITIONS}"
docker-compose run --rm -e PARTITIONS=$PARTITIONS -e TOPIC=$TOPIC kafka kafka-topics.sh --create \
  --topic $TOPIC \
  --replication-factor 1 \
  --partitions $PARTITIONS \
  --zookeeper zookeeper:2181 \
  2>/dev/null
