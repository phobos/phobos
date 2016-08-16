#!/usr/bin/env bash
set -eu

UTILS_DIR=$(dirname $0)
source ${UTILS_DIR}/env.sh

for (( i=${#APPS[@]}-1 ; i>=0 ; i-- )) ; do
  ${UTILS_DIR}/${APPS[i]}.sh stop
done
