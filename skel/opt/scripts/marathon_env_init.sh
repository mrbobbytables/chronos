#!/bin/bash

##### Sample environment init script #####
# PORT0 = Chronos Web
# PORT1 = libprocess bind port
##########################################



local local_ip="$(ip addr show eth0 | grep -m 1 -P -o '(?<=inet )[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')"

export CHRONOS_HTTP_PORT="$PORT0"
export LIBPROCESS_IP="$local_ip"
export LIBPROCESS_PORT="$PORT1"
export LIBPROCESS_ADVERTISE_IP="$HOST"
export LIBPROCESS_ADVERTISE_PORT="$PORT1"

echo "[$(date)][env-init][CHRONOS_HTTP_PORT] $PORT0"
echo "[$(date)][env-init][LIBPROCESS_IP] $local_ip"
echo "[$(date)][env-init][LIBPROCESS_PORT] $PORT1"
echo "[$(date)][env-init][LIBPROCESS_ADVERTISE_IP] $HOST"
echo "[$(date)][env-init][LIBPROCESS_ADVERTISE_PORT] $PORT1"
