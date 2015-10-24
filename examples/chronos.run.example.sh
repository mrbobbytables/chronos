#!/bin/bash
docker run -d                 \
--name chronos                \
-e ENVIRONMENT=production     \
-e PARENT_HOST=$(hostname)    \
-e LOG_STDOUT_THRESHOLD=WARN  \
-e LIBPROCESS_PORT=9200       \
-e LIBPROCESS_ADVERTISE_PORT=9200      \
-e LIBPROCESS_ADVERTISE_IP=10.10.0.11  \
-e CHRONOS_MASTER=zk://10.10.0.11:2181,10.10.0.12:2181,10.10.0.13:2181/mesos  \
-e CHRONOS_ZK_HOSTS=zk://10.10.0.11:2181,10.10.0.12:2181,10.10.0.13:2181      \
-e CHRONOS_HOSTNAME=10.10.0.11           \
-e CHRONOS_HTTP_PORT=4400                \
-e CHRONOS_MESOS_FRAMEWORK_NAME=chronos  \
-p 4400:4400  \
-p 9200:9200  \
chronos

