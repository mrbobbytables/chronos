#!/bin/bash

########## Chronos ##########
# Init Script for Chronos
########## Chronos ##########

source /opt/scripts/container_functions.lib.sh

init_vars() {

  if [[ $ENVIRONMENT_INIT && -f $ENVIRONMENT_INIT ]]; then
    source "$ENVIRONMENT_INIT"
  fi 

  if [[ ! $PARENT_HOST && $HOST ]]; then
    export PARENT_HOST="$HOST"
  fi

  export APP_NAME=${APP_NAME:-chronos}
  export ENVIRONMENT=${ENVIRONMENT:-local}
  export PARENT_HOST=${PARENT_HOST:-unknown}

  export LIBPROCESS_PORT=${LIBPROCESS_PORT:-9000}

  export CHRONOS_LOG_STDOUT_LAYOUT=${CHRONOS_LOG_STDOUT_LAYOUT:-standard}
  export CHRONOS_LOG_DIR=${CHRONOS_LOG_DIR:-/var/log/chronos}
  export CHRONOS_LOG_FILE=${CHRONOS_LOG_FILE:-chronos.log}
  export CHRONOS_LOG_FILE_LAYOUT=${CHRONOS_LOG_fILE_LAYOUT:-json}

  # if consul template is to be used, configure rsyslog
  export SERVICE_CONSUL_TEMPLATE=${SERVICE_CONSUL_TEMPLATE:-disabled}
  if [[ "$SERVICE_CONSUL_TEMPLATE" == "enabled" ]]; then
    export SERVICE_RSYSLOG=${SERVICE_RSYSLOG:-enabled}
  fi
  export SERVICE_LOGSTASH_FORWARDER_CONF=${SERVICE_LOGSTASH_FORWARDER_CONF:-/opt/logstash-forwarder/chronos.conf}
  export SERVICE_REDPILL_MONITOR=${SERVICE_REDPILL_MONITOR:-chronos}

  case "${ENVIRONMENT,,}" in
    prod|production|dev|development)
      export JAVA_OPTS=${JAVA_OPTS:-"-Xms384m -Xmx512m"}
      export CHRONOS_LOG_STDOUT_THRESHOLD=${CHRONOS_LOG_STDOUT_THRESHOLD:-WARN}
      export CHRONOS_LOG_FILE_THRESHOLD=${CHRONOS_LOG_FILE_THRESHOLD:-WARN}
      export SERVICE_LOGSTASH_FORWARDER=${SERVICE_LOGSTASH_FORWARDER:-enabled}
      export SERVICE_REDPILL=${SERVICE_REDPILL:-enabled}
      ;;
    debug)
      export JAVA_OPTS=${JAVA_OPTS:-"-Xms384m -Xmx512m"}
      export CHRONOS_LOG_STDOUT_THRESHOLD=${CHRONOS_LOG_STDOUT_THRESHOLD:-DEBUG}
      export CHRONOS_LOG_FILE_THRESHOLD=${CHRONOS_LOG_FILE_THRESHOLD:-DEBUG}
      export SERVICE_LOGSTASH_FORWARDER=${SERVICE_LOGSTASH_FORWARDER:-disabled}
      export SERVICE_REDPILL=${SERVICE_REDPILL:-disabled}
      if [[ "$SERVICE_CONSUL_TEMPLATE" == "enabled" ]]; then
        export CONSUL_TEMPLATE_LOG_LEVEL=${CONSUL_TEMPLATE_LOG_LEVEL:-debug}
      fi
      ;;
   local|*)
      local local_ip="$(ip addr show eth0 | grep -m 1 -P -o '(?<=inet )[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')"
      export CHRONOS_HOSTNAME=${CHRONOS_HOSTNAME:-"$local_ip"}
      export JAVA_OPTS=${JAVA_OPTS:-"-Xmx256m"}
      export CHRONOS_LOG_STDOUT_THRESHOLD=${CHRONOS_LOG_STDOUT_THRESHOLD:-WARN}
      export CHRONOS_LOG_FILE_THRESHOLD=${CHRONOS_LOG_FILE_THRESHOLD:-WARN}
      export SERVICE_LOGSTASH_FORWARDER=${SERVICE_LOGSTASH_FORWARDER:-disabled}
      export SERVICE_REDPILL=${SERVICE_REDPILL:-enabled}
      ;;
  esac

}

config_chronos() {
  #logging settings for log4j and default JAVA_OPTS
  local log_stdout_layout=""
  local log_file_layout=""

  case "${CHRONOS_LOG_STDOUT_LAYOUT,,}" in
    json) log_stdout_layout="net.logstash.log4j.JSONEventLayoutV1";;
    standard|*) log_stdout_layout="org.apache.log4j.PatternLayout";;
  esac
    
  case "${CHRONOS_LOG_FILE_LAYOUT,,}" in
    json) log_file_layout="net.logstash.log4j.JSONEventLayoutV1";;
    standard|*) log_file_layout="org.apache.log4j.PatternLayout";;
  esac
  
  jvm_opts=( "-Djava.library.path=/usr/local/lib:/usr/lib64:/usr/lib"
             "-Dlog4j.configuration=file:/etc/chronos/log4j.properties"
             "-Dlog.stdout.layout=$log_stdout_layout"
             "-Dlog.stdout.threshold=$CHRONOS_LOG_STDOUT_THRESHOLD"
             "-Dlog.file.layout=$log_file_layout"
             "-Dlog.file.threshold=$CHRONOS_LOG_FILE_THRESHOLD"
             "-Dlog.file.dir=$CHRONOS_LOG_DIR"
             "-Dlog.file.name=$CHRONOS_LOG_FILE")

  # Append extra JAVA_OPTS to jvm_opts
  for j_opt in $JAVA_OPTS; do
      jvm_opts+=( ${j_opt} )
  done


  # assembled chronos flags and escape them for supervisor e.g. escape ", % etc.
  for i in $(compgen -A variable | awk '/^CHRONOS_/ && !/^CHRONOS_LOG_/'); do
    var_name="--$(echo "${i:8}" | awk '{print tolower($0)}')"
    cmd_flags+=( "$var_name" ) 
    cmd_flags+=( "${!i}" )
  done

  local chronos_cmd="java ${jvm_opts[*]}  -cp $JSONLOG4JCP:/usr/bin/chronos org.apache.mesos.chronos.scheduler.Main ${cmd_flags[*]}"
  export SERVICE_CHRONOS_CMD=${SERVICE_CHRONOS_CMD:-"$(__escape_svsr_txt "$chronos_cmd")"}
}

main() {

  init_vars

  echo "[$(date)[App-Name] $APP_NAME"
  echo "[$(date)][Environment] $ENVIRONMENT"

  __config_service_consul_template
  __config_service_logstash_forwarder
  __config_service_redpill
  __config_service_rsyslog

  config_chronos

  echo "[$(date)][Chronos][Start-Command] $SERVICE_CHRONOS_CMD"

  exec supervisord -n -c /etc/supervisor/supervisord.conf

}

main "$@"
