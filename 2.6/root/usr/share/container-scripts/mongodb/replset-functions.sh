# container_addr returns the current container external IP address
function container_addr() {
  echo -n $(cat ${HOME}/.address)
}

# mongo_addr returns the IP:PORT of the currently running MongoDB instance
function mongo_addr() {
  echo -n "$(container_addr):${port}"
}

# cache_container_addr waits till the container gets the external IP address and
# cache it to disk
function cache_container_addr() {
  echo -n "=> Waiting for container IP address ..."
  for i in $(seq $MAX_ATTEMPTS); do
    result=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
    if [ ! -z "${result}" ]; then
      echo -n $result > ${HOME}/.address
      echo " $(mongo_addr)"
      return 0
    fi
    sleep $SLEEP_TIME
  done
  echo "Failed to get Docker container IP address." && exit 1
}

# endpoints returns list of IP addresses with other instances of MongoDB
# To get list of endpoints, you need to have headless Service named 'mongodb'.
# NOTE: This won't work with standalone Docker container.
function endpoints() {
  service_name=${MONGODB_SERVICE_NAME:-mongodb}
  dig ${service_name} A +search +short 2>/dev/null
}

# mongo_primary_addr gets the address of the current PRIMARY member
# NOTE: this function hopes that some replset member use standart port
function mongo_primary_addr() {
  local node_port=27017
  local current_endpoints=$(endpoints)
  for node in $current_endpoints; do
    mongo admin -u admin -p "${MONGODB_ADMIN_PASSWORD}" --host "${node}:${node_port}" --quiet --eval "rs.isMaster()" &>/dev/null
    if [ $? -eq 0 ]; then
      local primary=$(mongo admin -u admin -p "${MONGODB_ADMIN_PASSWORD}" --host "${node}:${node_port}" --quiet --eval "print(rs.isMaster().primary);")
      # If there is no PRIMARY yet, rs.isMaster().primary returns "undefined"
      while [ $primary == "undefined" ]; do
        primary=$(mongo admin -u admin -p "${MONGODB_ADMIN_PASSWORD}" --host "${node}:${node_port}" --quiet --eval "print(rs.isMaster().primary);")
        sleep $SLEEP_TIME
      done
      echo -n "$primary"
      break
    fi
  done
  if [ -z "$current_endpoints" ]; then
    echo -n $(mongo_addr)
  fi
}

# mongo_wait_primary waits until primare replset member is ready
function mongo_wait_primary() {
  mongo admin ${1:-} --host ${2:-$(mongo_primary_addr)} --eval "while (rs.status().startupStatus || (rs.status().hasOwnProperty(\"myState\") && rs.status().myState != 1)) { printjson( rs.status() ); sleep(1000); }; printjson( rs.status() );"
}

# mongo_initiate initiates the replica set
function mongo_initiate() {
  config="{ _id: \"${MONGODB_REPLICA_NAME}\", members: [ { _id: 0, host: \"$(mongo_addr)\"} ] }"
  echo "=> Initiating MongoDB replica using: ${config}"
  mongo admin ${1:-}--eval "rs.initiate(${config})"
  mongo_wait_primary "" "localhost"
}

# mongo_remove removes the current MongoDB from the cluster
function mongo_remove() {
  echo "=> Removing $(mongo_addr) on $(mongo_primary_addr) ..."
  mongo admin -u admin -p "${MONGODB_ADMIN_PASSWORD}" \
    --host $(mongo_primary_addr) --eval "rs.remove('$(mongo_addr)');" &>/dev/null || true
}

# mongo_add adds the current container to other mongo replicas
function mongo_add() {
  echo "=> Adding $(mongo_addr) to $(mongo_primary_addr) ..."
  mongo admin -u admin -p "${MONGODB_ADMIN_PASSWORD}" \
    --host $(mongo_primary_addr) --eval "rs.add('$(mongo_addr)');"
}

# setup_keyfile fixes the bug in mounting the Kubernetes 'Secret' volume that
# mounts the secret files with 'too open' permissions.
function setup_keyfile() {
  if [ -z "${MONGODB_KEYFILE_VALUE}" ]; then
    echo "ERROR: You have to provide the 'keyfile' value in ${MONGODB_KEYFILE_VALUE}"
    exit 1
  fi
  echo ${MONGODB_KEYFILE_VALUE} > ${MONGODB_KEYFILE_PATH}
  chmod 0600 ${MONGODB_KEYFILE_PATH}
}

