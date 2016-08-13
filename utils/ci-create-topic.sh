TOPIC=${TOPIC:='test'}
PARTITIONS=${PARTITIONS:=2}
ZK_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' zookeeper)

echo "creating topic ${TOPIC}, partitions ${PARTITIONS}"

docker run ches/kafka:0.9.0.1 kafka-topics.sh \
  --create \
  --topic $TOPIC \
  --replication-factor 1 \
  --partitions $PARTITIONS \
  --zookeeper $ZK_IP:2181
