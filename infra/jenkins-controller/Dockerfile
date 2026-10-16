ARG JENKINS_IMAGE=jenkins/jenkins:lts-jdk21
FROM ${JENKINS_IMAGE}

USER root
# Copy and install essential pipeline plugins at build time
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Copy Groovy initialization script to auto-create admin user
COPY init-admin.groovy /usr/share/jenkins/ref/init.groovy.d/init-admin.groovy

USER jenkins
