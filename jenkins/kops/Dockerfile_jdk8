FROM centos:latest

ARG JDK_FILENAME=jdk-8u152-linux-x64.tar.gz
ARG JDK_URL=http://download.oracle.com/otn-pub/java/jdk/8u152-b16/aa0333dd3019491ca4f6ddbe78cdb6d0/${JDK_FILENAME}
ARG JDK_INSTALL_DIR="/usr/lib/jvm"

ENV JAVA_HOME ${JDK_INSTALL_DIR}/jdk1.8.0_152
WORKDIR /home/demo3

RUN useradd -ms /bin/bash  demo3 && \
    yum update -y && \
    yum install -y wget && \
    wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" ${JDK_URL} && \
    mkdir ${JDK_INSTALL_DIR} && \
    tar -xzf ${JDK_FILENAME} -C "${JDK_INSTALL_DIR}" && \
    alternatives --install /usr/bin/java java "${JAVA_HOME}/bin/java" 200 && \
    alternatives --install /usr/bin/javac javac "${JAVA_HOME}/bin/javac" 200 && \
    alternatives --set java "${JAVA_HOME}/bin/java" && \
    alternatives --set javac "${JAVA_HOME}/bin/javac"

USER demo3