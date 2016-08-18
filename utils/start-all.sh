#!/bin/bash
set -eu

UTILS_DIR=$(dirname $0)
source ${UTILS_DIR}/env.sh

for (( i=0 ; i<${#APPS[@]} ; i++ )) ; do
  ${UTILS_DIR}/${APPS[i]}.sh start
done
