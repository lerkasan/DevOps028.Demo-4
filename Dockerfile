# FROM registry.lerkasan.de:5000/jdk8:152
FROM jdk8:152

ARG DB_HOST=samsara-postgres
ARG DB_PORT=5432
ARG DB_NAME=auradb
ARG DB_USER=aura
ARG DB_PASS=mysecretpassword
ARG ARTIFACT_FILENAME

ENV DB_HOST ${DB_HOST}
ENV DB_PORT ${DB_PORT}
ENV DB_NAME ${DB_NAME}
ENV DB_USER ${DB_USER}
ENV DB_PASS ${DB_PASS}
ENV LOGIN_HOST localhost

EXPOSE 9000

USER root

RUN apt-get update -y && \
    apt-get install -y apt-transport-https && \
    sh -c "echo 'deb https://apt.datadoghq.com/ stable main' > /etc/apt/sources.list.d/datadog.list" && \
    apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 C7A7DA52 && \
    apt-get update && \
    apt-get install datadog-agent

WORKDIR /home/samsara

COPY ${ARTIFACT_FILENAME} .
COPY liquibase ./liquibase

RUN sed "s/%LOGIN_HOST%/${LOGIN_HOST}/g" liquibase/liquibase.properties.template | \
        sed "s/%DB_HOST%/${DB_HOST}/g" | \
        sed "s/%DB_PORT%/${DB_PORT}/g" | \
        sed "s/%DB_NAME%/${DB_NAME}/g" | \
        sed "s/%DB_USER%/${DB_USER}/g" | \
        sed "s/%DB_PASS%/${DB_PASS}/g" > liquibase/liquibase.properties

USER samsara

CMD bin/liquibase --changeLogFile=liquibase/changelogs/changelog-main.xml --defaultsFile=liquibase/liquibase.properties update && \
    java -Dcom.sun.management.jmxremote.port=7199 \
         -Dcom.sun.management.jmxremote.ssl=false \
         -jar *.jar