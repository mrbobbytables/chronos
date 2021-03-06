# - Chronos -
An Ubuntu based Chronos container with the capability of logging to both standard and json format. It comes packaged with Logstash-Forwarder and is managed via Supervisord.

##### Version Information:

* **Container Release:** 1.2.0
* **Mesos:** 0.26.0-0.2.145.ubuntu1404
* **Chronos:** 2.4.0-0.1.20151007110204.ubuntu1404

**Services Include**
* **[Chronos](#chronos)** - A Mesos Framework that provides a distributed and fault tolerant 'cron'.
* **[Consul-Template](#consul-template)** - An application that can populate configs from a consul service.
* **[Logrotate](#logrotate)** - A script and application that aid in pruning log files.
* **[Logstash-Forwarder](#logstash-forwarder)** - A lightweight log collector and shipper for use with [Logstash](https://www.elastic.co/products/logstash).
* **[Redpill](#redpill)** - A bash script and healthcheck for supervisord managed services. It is capable of running cleanup scripts that should be executed upon container termination.
* **[Rsyslog](#rsyslog)** - The system logging daemon.

---
---
### Index

* [Usage](#usage)
 * [Example Run Command](#example-run-command)
 * [Example Marathon App Definition](#example-marathon-app-definition)
* [Modification and Anatomy of the Project](#modification-and-anatomy-of-the-project)
* [Important Environment Variables](#important-environment-variables)
* [Service Configuration](#service-configuration)
 * [Consul-Template](#consul-template)
 * [Logrotate](#logrotate)
 * [Chronos](#chronos)
 * [Logstash-Forwarder](#logstash-forwarder)
 * [Redpill](#redpill)
 * [Rsyslog](#rsyslog)
* [Troubleshooting](#troubleshooting)

---
---

### Usage

When running the Chronos container in any deployment; the container does require several environment variables to be
defined to function correctly.

* `ENVIRONMENT` - `ENVIRONMENT` will enable or disable services and change the value of several other environment variables based on where the container is running (`prod`, `local` etc.). Please see the [Environment](#environment) section under [Important Environment Variables](#important-environment-variables).


* `LIBPROCESS_IP` - The ip in which libprocess will bind to. (defaults to `0.0.0.0`)

* `LIBPROCESS_PORT` - The port used for libprocess communication (defaults to `9000`)

* `LIBPROCESS_ADVERTISE_IP` - If set, this will be the 'advertised' or 'externalized' ip used for libprocess communication. Relevant when running an application that uses libprocess within a container, and should be set to the host IP in which you wish to use for Mesos communication.

* `LIBPROCESS_ADVERTISE_PORT` - If set, this will be the 'advertised' or 'externalized' port used for libprocess communication. Relevant when running an application that uses libprocess within a container, and should be set to the host port you wish to use for Mesos communication.

* `CHRONOS_MASTER` - The zk url of Mesos Masters.

* `CHRONOS_ZK_HOSTS` - A comma delimited list of Zookeeper servers used for storing Chronos state. **Note:** Does not need to be prefixed with `zk://`.

The libprocess variables are not necessarily required if using host networking (as long as the default ip and port are available). However, you will quickly run into problems if attempting to run it alongside another container attempting to do the same thing. This is where running with an alternate `LIBPROCESS_PORT` or running the container with standard bridge networking and using the two `LIBPROCESS_ADVERTISE_*` variables is ideal.

A supplied sample seed script is available at `/opt/scripts/marathon_env_init.sh`. This will assign 1 to 1 mappings of the 2 exposed ports needed for Chronos + Mesos to their associated variables.

* `PORT0` - The Chronos WebUI
* `PORT1` - port used for both `LIBPROCESS_PORT` and `LIBPROCESS_ADVERTISED_PORT`.



For further configuration information, please see the [Chronos](#chronos) service section.

---

### Example Run Command

```bash
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
```

---

### Example Marathon App Definition

```json
{
    "id": "/chronos",
    "instances": 1,
    "cpus": 1,
    "mem": 512,
    "container": {
        "type": "DOCKER",
        "docker": {
            "image": "registry.address/mesos/chronos",
            "network": "BRIDGE",
            "portMappings": [
                {
                    "containerPort": 31114,
                    "hostPort": 31114,
                    "protocol": "tcp"
                },
                {
                    "containerPort": 31115,
                    "hostPort": 31115,
                    "protocol": "tcp"
                }
            ]
        }
    },
    "env": {
        "ENVIRONMENT": "production",
        "ENVIRONMENT_INIT": "/opt/scripts/marathon_env_init.sh",
        "CHRONOS_MASTER": "zk://10.10.0.11:2181,10.10.0.12:2181,10.10.0.13:2181/mesos",
        "CHRONOS_ZK_HOSTS": "zk://10.10.0.11:2181,10.10.0.12:2181,10.10.0.13:2181",
        "CHRONOS_LOG_STDOUT_THRESHOLD": "WARN",
        "CHRONOS_HOSTANME": "$HOST",
        "CHRONOS_MESOS_FRAMEWORK_NAME": "chronos"
    },
    "healthChecks": [
        {
            "protocol": "HTTP",
            "portIndex": 0,
            "path": "/",
            "gracePeriodSeconds": 30,
            "intervalSeconds": 20,
            "maxConsecutiveFailures": 3
        }
    ],
    "uris": [
        "file:///docker.tar.gz"
    ]
}
```


### Example ENVIRONMENT_INIT script

```bash
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
```

---
---


### Modification and Anatomy of the Project

**File Structure**
The directory `skel` in the project root maps to the root of the file system once the container is built. Files and folders placed there will map to their corresponding location within the container.

**Init**
The init script (`./init.sh`) found at the root of the directory is the entry process for the container. It's role is to simply set specific environment variables and modify any subsequently required configuration files.

**Chronos**
The chronos configuration will automatically be generated at runtime, however logging options are specified in `/etc/chronos/log4j.properties`.

**Supervisord**
All supervisord configs can be found in `/etc/supervisor/conf.d/`. Services by default will redirect their stdout to `/dev/fd/1` and stderr to `/dev/fd/2` allowing for service's console output to be displayed. Most applications can log to both stdout and their respectively specified log file.

In some cases (such as with zookeeper), it is possible to specify different logging levels and formats for each location.

**Logstash-Forwarder**
The Logstash-Forwarder binary and default configuration file can be found in `/skel/opt/logstash-forwarder`. It is ideal to bake the Logstash Server certificate into the base container at this location. If the certificate is called `logstash-forwarder.crt`, the default supplied Logstash-Forwarder config should not need to be modified, and the server setting may be passed through the `SERVICE_LOGSTASH_FORWARDER_ADDRESS` environment variable.

In practice, the supplied Logstash-Forwarder config should be used as an example to produce one tailored to each deployment.

---
---

### Important Environment Variables

#### Defaults

| **Variable**                      | **Default**                           |
|-----------------------------------|---------------------------------------|
| `ENVIRONMENT_INIT`                |                                       |
| `APP_NAME`                        | `chronos`                             |
| `ENVIRONMENT`                     | `local`                               |
| `PARENT_HOST`                     | `unknown`                             |
| `JAVA_OPTS`                       |                                       |
| `LIBPROCESS_IP`                   | `0.0.0.0`                             |
| `LIBPROCESS_PORT`                 | `9000`                                |
| `LIBPROCESS_ADVERTISE_IP`         |                                       |
| `LIBPROCESS_ADVERTISE_PORT`       |                                       |
| `CHRONOS_LOG_DIR`                 | `/var/log/chronos`                    |
| `CHRONOS_LOG_FILE`                | `chronos.log`                         |
| `CHRONOS_LOG_FILE_LAYOUT`         | `json`                                |
| `CHRONOS_LOG_FILE_THRESHOLD`      |                                       |
| `CHRONOS_LOG_STDOUT_LAYOUT`       | `standard`                            |
| `CHRONOS_LOG_STDOUT_THRESHOLD`    |                                       |
| `SERVICE_CONSUL_TEMPLATE`         | `disabled`                            |
| `SERVICE_LOGROTATE`               | `enabled`                             |
| `SERVICE_LOGSTASH_FORWARDER`      |                                       |
| `SERVICE_LOGSTASH_FORWARDER_CONF` | `/opt/logstash-forwarder/chronos.log` |
| `SERVICE_REDPILL`                 |                                       |
| `SERVICE_REDPILL_MONITOR`         | `chronos`                             |
| `SERVICE_RSYSLOG`                 | `disabled`                            |

#### Description

* `ENVIRONMENT_INIT` - If set, and the file path is valid. This will be sourced and executed before **ANYTHING** else. Useful if supplying an environment file or need to query a service such as consul to populate other variables.

* `APP_NAME` - A brief description of the container. If Logstash-Forwarder is enabled, this will populate the `app_name` field in the Logstash-Forwarder configuration file.

* `ENVIRONMENT` - Sets defaults for several other variables based on the current running environment. Please see the [environment](#environment) section for further information. If logstash-forwarder is enabled, this value will populate the `environment` field in the logstash-forwarder configuration file.

* `PARENT_HOST` - The name of the parent host. If Logstash-Forwarder is enabled, this will populate the `parent_host` field in the Logstash-Forwarder configuration file.

* `JAVA_OPTS` - The Java environment variables that will be passed to Marathon at runtime. Generally used for adjusting memory allocation (`-Xms` and `-Xmx`).

* `LIBPROCESS_IP` - The ip in which libprocess will bind to. (defaults to `0.0.0.0`)

* `LIBPROCESS_PORT` - The port used for libprocess communication (defaults to `9000`)

* `LIBPROCESS_ADVERTISE_IP` - If set, this will be the 'advertised' or 'externalized' ip used for libprocess communication. Relevant when running an application that uses libprocess within a container, and should be set to the host IP in which you wish to use for Mesos communication.

* `LIBPROCESS_ADVERTISE_PORT` - If set, this will be the 'advertised' or 'externalized' port used for libprocess communication. Relevant when running an application that uses libprocess within a container, and should be set to the host port you wish to use for Mesos communication.

* `CHRONOS_LOG_DIR` - The directory in which the Chronos log files will be stored.

* `CHRONOS_LOG_FILE` - The name of the chronos log file.

* `CHRONOS_LOG_FILE_LAYOUT` - The log format or layout to be used for the file logger. There are two available formats, `standard` and `json`. The `standard` format is more humanly readable and is the chronos default. The `json` format is easier for log processing by applications such as logstash. (**Options:** `standard` or `json`).

* `CHRONOS_LOG_FILE_THRESHOLD` - The log level to be used for the file logger. (**Options:** `ERROR`, `WARN`, `INFO`, and `DEBUG`)

* `CHRONOS_LOG_STDOUT_LAYOUT` - The log format or layout to be used for console output. There are two available formats, `standard` and `json`. The `standard` format is more humanly readable and is the chronos default. The `json` format is easier for log processing by applications such as logstash. (**Options:** `standard` or `json`).

* `CHRONOS_LOG_STDOUT_THRESHOLD`  The log level to be used for console output. (**Options:** `ERROR`, `WARN`, `INFO`, and `DEBUG`)

* `SERVICE_CONSUL_TEMPLATE - * `SERVICE_CONSUL_TEMPLATE` - Enables or disables the consul-template service. If enabled, it will also enable `SERVICE_LOGROTATE` and `SERVICE_RSYSLOG` to handle logging. (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGROTATE` - Enables or disabled the Logrotate service. This is managed by `SERVICE_CONSUL_TEMPLATE`, but can be enabled/disabled manually. (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGSTASH_FORWARDER` - Enables or disables the Logstash-Forwarder service. Set automatically depending on the `ENVIRONMENT`. See the Environment section below.  (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGSTASH_FORWARDER_CONF` - The path to the logstash-forwarder configuration.

* `SERVICE_REDPILL` - Enables or disables the Redpill service. Set automatically depending on the `ENVIRONMENT`. See the Environment section below.  (**Options:** `enabled` or `disabled`)

* `SERVICE_REDPILL_MONITOR` - The name of the supervisord service(s) that the Redpill service check script should monitor.

* `SERVICE_RSYSLOG` - Enables of disables the rsyslog service. This is managed by `SERVICE_CONSUL_TEMPLATE`, but can be enabled/disabled manually. (**Options:** `enabled` or `disabled`)

---


#### Environment

* `local` (default)

| **Variable**                   | **Default**                |
|--------------------------------|----------------------------|
| `CHRONOS_HOSTNAME`             | `<first ip bound to eth0>` |
| `CHRONOS_LOG_FILE_THRESHOLD`   | `WARN`                     |
| `CHRONOS_LOG_STDOUT_THRESHOLD` | `WARN`                     |
| `JAVA_OPTS`                    | `-Xmx256m`                 |
| `SERVICE_LOGSTASH_FORWARDER`   | `disabled`                 |
| `SERVICE_REDPILL`              | `enabled`                  |

* `prod`|`production`|`dev`|`development`

| **Variable**                   | **Default**         |
|--------------------------------|---------------------|
| `CHRONOS_LOG_FILE_THRESHOLD`   | `WARN`              |
| `CHRONOS_LOG_STDOUT_THRESHOLD` | `WARN`              |
| `JAVA_OPTS`                    | `-Xms384m -Xmx512m` |
| `SERVICE_LOGSTASH_FORWARDER`   | `enabled`           |
| `SERVICE_REDPILL`              | `enabled`           |


* `debug`

| **Variable**                   | **Default**         |
|--------------------------------|---------------------|
| `CHRONOS_LOG_FILE_THRESHOLD`   | `DEBUG`             |
| `CHRONOS_LOG_STDOUT_THRESHOLD` | `DEBUG`             |
| `JAVA_OPTS`                    | `-Xms384m -Xmx512m` |
| `SERVICE_LOGSTASH_FORWARDER`   | `disabled`          |
| `SERVICE_REDPILL`              | `disabled`          |
| `CONSUL_TEMPLATE_LOG_LEVEL`    | `debug` *           |

\* Only set if `SERVICE_CONSUL_TEMPLATE` is set to `enabled`.


---
---

### Service Configuration

---

### Chronos
Chronos is a highly-available 'distributed cron' Mesos Framework developed by the folks at [Airbnb](http://nerds.airbnb.com/introducing-chronos/). They've made the code and documentation available over at [github](https://github.com/mesos/chronos).

By default, Chronos does not supporting providing start parameters as environment variables; however the init script will translate environment variables to parameters as long as they follow the form `CHRONOS_<COMMAND_LINE_OPTION>` e.g. `CHRONOS_MASTER=zk://10.10.0.11:2181,10.10.0.12:2181,10.10.0.13:2181/mesos`.

A list of the Chronos command line flags can be found in their [configuration](https://github.com/mesos/chronos/blob/master/docs/docs/configuration.md) docs.
Alternatively, you can execute the following command to print the available options with the container itself:

`docker run -it --rm chronos java -cp /usr/share/java:/usr/bin/chronos org.apache.mesos.chronos.scheduler.Main --help`

In addition to the above Chronos configuration, some specific logging options have been added via the following variables:

##### Defaults
| **Variable**                   | **Default**        |
|--------------------------------|--------------------|
| `CHRONOS_LOG_DIR`              | `/var/log/chronos` |
| `CHRONOS_LOG_FILE`             | `chronos.log`      |
| `CHRONOS_LOG_FILE_LAYOUT`      | `json`             |
| `CHRONOS_LOG_FILE_THRESHOLD`   |                    |
| `CHRONOS_LOG_STDOUT_LAYOUT`    | `standard`         |
| `CHRONOS_LOG_STDOUT_THRESHOLD` |                    |

##### Description
* `CHRONOS_LOG_DIR` - The directory in which the Chronos log files will be stored.

* `CHRONOS_LOG_FILE` - The name of the chronos log file.

* `CHRONOS_LOG_FILE_LAYOUT` - The log format or layout to be used for the file logger. There are two available formats, `standard` and `json`. The `standard` format is more humanly readable and is the chronos default. The `json` format is easier for log processing by applications such as logstash. (**Options:** `standard` or `json`).

* `CHRONOS_LOG_FILE_THRESHOLD` - The log level to be used for the file logger. (**Options:** `ERROR`, `WARN`, `INFO`, and `DEBUG`)

* `CHRONOS_LOG_STDOUT_LAYOUT` - The log format or layout to be used for console output. There are two available formats, `standard` and `json`. The `standard` format is more humanly readable and is the chronos default. The `json` format is easier for log processing by applications such as logstash. (**Options:** `standard` or `json`).

* `CHRONOS_LOG_STDOUT_THRESHOLD`  The log level to be used for console output. (**Options:** `ERROR`, `WARN`, `INFO`, and `DEBUG`)


---


### Consul-Template

Provides initial configuration of consul-template. Variables prefixed with `CONSUL_TEMPLATE_` will automatically be passed to the consul-template service at runtime, e.g. `CONSUL_TEMPLATE_SSL_CA_CERT=/etc/consul/certs/ca.crt` becomes `-ssl-ca-cert="/etc/consul/certs/ca.crt"`. If managing the application configuration is handled via file configs, no other variables must be passed at runtime.

#### Consul-Template Environment Variables

##### Defaults

| **Variable**                  | **Default**                           |
|-------------------------------|---------------------------------------|
| `CONSUL_TEMPLATE_CONFIG`      | `/etc/consul/template/conf.d`         |
| `CONSUL_TEMPLATE_SYSLOG`      | `true`                                |
| `SERVICE_CONSUL_TEMPLATE`     |                                       |
| `SERVICE_CONSUL_TEMPLATE_CMD` | `consul-template <CONSUL_TEMPLATE_*>` |


---


### Logrotate

The logrotate script is a small simple script that will either call and execute logrotate on a given interval; or execute a supplied script. This is useful for applications that do not perform their own log cleanup.

#### Logrotate Environment Variables

##### Defaults

| **Variable**                 | **Default**                           |
|------------------------------|---------------------------------------|
| `SERVICE_LOGROTATE`          |                                       |
| `SERVICE_LOGROTATE_INTERVAL` | `3600` (set in script)                |
| `SERVICE_LOGROTATE_CONF`     | `/etc/logrotate.conf` (set in script) |
| `SERVICE_LOGROTATE_SCRIPT`   |                                       |
| `SERVICE_LOGROTATE_FORCE`    |                                       |
| `SERVICE_LOGROTATE_VERBOSE`  |                                       |
| `SERVICE_LOGROTATE_DEBUG`    |                                       |
| `SERVICE_LOGROTATE_CMD`      | `/opt/script/logrotate.sh <flags>`    |

##### Description

* `SERVICE_LOGROTATE` - Enables or disables the Logrotate service. Set automatically depending on the `ENVIRONMENT`. See the Environment section.  (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGROTATE_INTERVAL` - The time in seconds between run of either the logrotate command or the provided logrotate script. Default is set to `3600` or 1 hour in the script itself.

* `SERVICE_LOGROTATE_CONFIG` - The path to the logrotate config file. If neither config or script is provided, it will default to `/etc/logrotate.conf`.

* `SERVICE_LOGROTATE_SCRIPT` - A script that should be executed on the provided interval. Useful to do cleanup of logs for applications that already handle rotation, or if additional processing is required.

* `SERVICE_LOGROTATE_FORCE` - If present, passes the 'force' command to logrotate. Will be ignored if a script is provided.

* `SERVICE_LOGROTATE_VERBOSE` - If present, passes the 'verbose' command to logrotate. Will be ignored if a script is provided.

* `SERVICE_LOGROTATE_DEBUG` - If present, passed the 'debug' command to logrotate. Will be ignored if a script is provided.

* `SERVICE_LOGROTATE_CMD` - The command that is passed to supervisor. If overriding, must be an escaped python string expression. Please see the [Supervisord Command Documentation](http://supervisord.org/configuration.html#program-x-section-settings) for further information.


##### Logrotate Script Help Text
```
root@ec58ca7459cb:/opt/scripts# ./logrotate.sh --help
logrotate.sh - Small wrapper script for logrotate.
-i | --interval     The interval in seconds that logrotate should run.
-c | --config       Path to the logrotate config.
-s | --script       A script to be executed in place of logrotate.
-f | --force        Forces log rotation.
-v | --verbose      Display verbose output.
-d | --debug        Enable debugging, and implies verbose output. No state file changes.
-h | --help         This usage text.
```


---

### Logstash-Forwarder

Logstash-Forwarder is a lightweight application that collects and forwards logs to a logstash server endpoint for further processing. For more information see the [Logstash-Forwarder](https://github.com/elastic/logstash-forwarder) project.


#### Logstash-Forwarder Environment Variables

##### Defaults

| **Variable**                         | **Default**                                                                             |
|--------------------------------------|-----------------------------------------------------------------------------------------|
| `SERVICE_LOGSTASH_FORWARDER`         |                                                                                         |
| `SERVICE_LOGSTASH_FORWARDER_CONF`    | `/opt/logstash-forwadrer/chronos.conf`                                                   |
| `SERVICE_LOGSTASH_FORWARDER_ADDRESS` |                                                                                         |
| `SERVICE_LOGSTASH_FORWARDER_CERT`    |                                                                                         |
| `SERVICE_LOGSTASH_FORWARDER_CMD`     | `/opt/logstash-forwarder/logstash-forwarder -config=”$SERVICE_LOGSTASH_FORWARDER_CONF”` |

##### Description

* `SERVICE_LOGSTASH_FORWARDER` - Enables or disables the Logstash-Forwarder service. Set automatically depending on the `ENVIRONMENT`. See the Environment section.  (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGSTASH_FORWARDER_CONF` - The path to the logstash-forwarder configuration.

* `SERVICE_LOGSTASH_FORWARDER_ADDRESS` - The address of the Logstash server.

* `SERVICE_LOGSTASH_FORWARDER_CERT` - The path to the Logstash-Forwarder server certificate.

* `SERVICE_LOGSTASH_FORWARDER_CMD` - The command that is passed to supervisor. If overriding, must be an escaped python string expression. Please see the [Supervisord Command Documentation](http://supervisord.org/configuration.html#program-x-section-settings) for further information.

---

### Redpill

Redpill is a small script that performs status checks on services managed through supervisor. In the event of a failed service (FATAL) Redpill optionally runs a cleanup script and then terminates the parent supervisor process.


#### Redpill Environment Variables

##### Defaults

| **Variable**               | **Default** |
|----------------------------|-------------|
| `SERVICE_REDPILL`          |             |
| `SERVICE_REDPILL_MONITOR`  | `chronos`   |
| `SERVICE_REDPILL_INTERVAL` |             |
| `SERVICE_REDPILL_CLEANUP`  |             |

##### Description

* `SERVICE_REDPILL` - Enables or disables the Redpill service. Set automatically depending on the `ENVIRONMENT`. See the Environment section.  (**Options:** `enabled` or `disabled`)

* `SERVICE_REDPILL_MONITOR` - The name of the supervisord service(s) that the Redpill service check script should monitor. 

* `SERVICE_REDPILL_INTERVAL` - The interval in which Redpill polls supervisor for status checks. (Default for the script is 30 seconds)

* `SERVICE_REDPILL_CLEANUP` - The path to the script that will be executed upon container termination.


##### Redpill Script Help Text
```
root@c90c98ae31e1:/# /opt/scripts/redpill.sh --help
Redpill - Supervisor status monitor. Terminates the supervisor process if any specified service enters a FATAL state.

-c | --cleanup    Optional path to cleanup script that should be executed upon exit.
-h | --help       This help text.
-i | --interval   Optional interval at which the service check is performed in seconds. (Default: 30)
-s | --service    A comma delimited list of the supervisor service names that should be monitored.
```


---


### Rsyslog
Rsyslog is a high performance log processing daemon. For any modifications to the config, it is best to edit the rsyslog configs directly (`/etc/rsyslog.conf` and `/etc/rsyslog.d/*`).

##### Defaults

| **Variable**                      | **Default**                                      |
|-----------------------------------|--------------------------------------------------|
| `SERVICE_RSYSLOG`                 | `disabled`                                       |
| `SERVICE_RSYSLOG_CONF`            | `/etc/rsyslog.conf`                              |
| `SERVICE_RSYSLOG_CMD`             | `/usr/sbin/rsyslogd -n -f $SERVICE_RSYSLOG_CONF` |

##### Description

* `SERVICE_RSYSLOG` - Enables or disables the rsyslog service. This will automatically be set depending on what other services are enabled. (**Options:** `enabled` or `disabled`)

* `SERVICE_RSYSLOG_CONF` - The path to the rsyslog configuration file.

* `SERVICE_RSYSLOG_CMD` -  The command that is passed to supervisor. If overriding, must be an escaped python string expression. Please see the [Supervisord Command Documentation](http://supervisord.org/configuration.html#program-x-section-settings) for further information.


---
---

### Troubleshooting

In the event of an issue, the `ENVIRONMENT` variable can be set to `debug`.  This will stop the container from shipping logs and prevent it from terminating if one of the services enters a failed state.

For further support, please see either the [Chronos Github Project](https://github.com/mesos/chronos) or post to the [Chronos Google Group](https://groups.google.com/forum/#!forum/chronos-scheduler).


