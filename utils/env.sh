DOCKER_HOSTNAME='localhost'
FORCE_PULL=${FORCE_PULL:='false'}
APPS=(zk kafka)

ZK_IMAGE=jplock/zookeeper
ZK_IMAGE_VERSION=3.4.6
KAFKA_IMAGE=ches/kafka
KAFKA_IMAGE_VERSION=0.9.0.1

wait_for () {
  timeout=60;
  date1=$((`date +%s` + $timeout));
  echo "Waiting for $2 ($1)"
  status=$(get $1)
  timewaited=0;
  while [ $status -ne 200 -a  "$date1" -gt `date +%s` ]
  do
    echo "Waited ${timewaited}/${timeout} seconds";
    timewaited=$((timewaited + 1));
    sleep 1
    status=$(get $1)
  done

  if [ $status -eq 200 ]; then
    echo "$2 ($1) is up!"
  else
    echo "Timed out waiting for $2 ($1)"
    docker logs $2
    exit 1
  fi
}
