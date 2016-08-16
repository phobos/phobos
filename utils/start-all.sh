#!/usr/bin/env bash
set -eux

source ./utils/env.sh

for (( i=0 ; i<${#APPS[@]} ; i++ )) ; do
  sh "./utils/${APPS[i]}.sh" start
done
