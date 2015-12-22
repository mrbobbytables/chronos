################################################################################
# chronos: 1.1.3
# Date: 12/21/2015
# Mesos Version: 0.26.0-0.2.145.ubuntu1404
# Chronos Version: 2.4.0-0.1.20151007110204.ubuntu1404
#
# Description:
# Container packaging the Chronos Mesos framework. Mesos-version tied to 
# mesos-base container updates. 
################################################################################

FROM mrbobbytables/mesos-base:1.1.4

MAINTAINER Bob Killen / killen.bob@gmail.com / @mrbobbytables


ENV VERSION_CHRONOS=2.4.0-0.1.20151007110204.ubuntu1404

RUN apt-get -y update          \
 && apt-get -y install         \
    chronos=$VERSION_CHRONOS   \ 
 && mkdir -p /var/log/chronos  \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY ./skel /

RUN chmod +x init.sh                            \
 && chmod +x /opt/scripts/marathon_env_init.sh  \
 && chown -R logstash-forwarder:logstash-forwarder /opt/logstash-forwarder                                                    \
 && wget -P /usr/share/java http://central.maven.org/maven2/net/logstash/log4j/jsonevent-layout/1.7/jsonevent-layout-1.7.jar  \
 && wget -P /usr/share/java http://central.maven.org/maven2/commons-lang/commons-lang/2.6/commons-lang-2.6.jar                \
 && wget -P /usr/share/java http://central.maven.org/maven2/junit/junit/4.12/junit-4.12.jar                                   \
 && wget -P /usr/share/java https://json-smart.googlecode.com/files/json-smart-1.2.jar

ENV JSONLOG4JCP=$JAVACPROOT/jsonevent-layout-1.7.jar:$JAVACPROOT/junit-4.12.jar/:$JAVACPROOT/commons-lang-2.6.jar:$JAVACPROOT/json-smart-1.2.jar

# default chronos web and LIBPROCESS_PORT
EXPOSE 8080 9000

CMD ["./init.sh"]
