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
WORKDIR /home/demo3
COPY ${ARTIFACT_FILENAME} .
COPY liquibase ./liquibase

RUN sed "s/%LOGIN_HOST%/${LOGIN_HOST}/g" liquibase/liquibase.properties.template | \
        sed "s/%DB_HOST%/${DB_HOST}/g" | \
        sed "s/%DB_PORT%/${DB_PORT}/g" | \
        sed "s/%DB_NAME%/${DB_NAME}/g" | \
        sed "s/%DB_USER%/${DB_USER}/g" | \
        sed "s/%DB_PASS%/${DB_PASS}/g" > liquibase/liquibase.properties

USER demo3
CMD bin/liquibase --changeLogFile=liquibase/changelogs/changelog-main.xml --defaultsFile=liquibase/liquibase.properties update && \
    java -jar *.jar