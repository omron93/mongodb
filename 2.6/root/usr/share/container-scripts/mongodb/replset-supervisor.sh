#!/bin/bash
#
# This script registers the current container into MongoDB replica set and
# unregisters it when the container is terminated.

source ${CONTAINER_SCRIPTS_PATH}/base-functions.sh
source ${CONTAINER_SCRIPTS_PATH}/init-functions.sh
source ${CONTAINER_SCRIPTS_PATH}/replset-functions.sh

set -x

echo "=> Waiting for local MongoDB to accept connections ..."
wait_mongo "UP"

# Prepare master
if [ "${1:-}" == "initiate" ]; then
  # Check mandatory environmental variables
  source ${CONTAINER_SCRIPTS_PATH}/pre-init.sh

  echo "=> Initiating the replSet ${MONGODB_REPLICA_NAME} ..."
  mongo_initiate

  echo "=> Creating MongoDB users ..."
  mongo_create_admin
  mongo_create_user "-u admin -p $MONGODB_ADMIN_PASSWORD"

  mongo_wait_primary "-u admin -p $MONGODB_ADMIN_PASSWORD"
  echo "=> Successfully initialized replSet ..."

# Add to the replSet
else
  mongo_wait_primary "-u admin -p $MONGODB_ADMIN_PASSWORD"

  # Add the current container to the replSet
  mongo_add
fi
