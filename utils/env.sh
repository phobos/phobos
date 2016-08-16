#!/usr/bin/env bash
set -eu

DOCKER_HOSTNAME='localhost'
FORCE_PULL=${FORCE_PULL:='false'}
APPS=(zk kafka)

ZK_IMAGE=jplock/zookeeper
ZK_IMAGE_VERSION=3.4.6
KAFKA_IMAGE=ches/kafka
KAFKA_IMAGE_VERSION=0.9.0.1
