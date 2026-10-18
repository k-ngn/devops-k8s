ARG JENKINS_IMAGE=jenkins/jenkins:lts-jdk21
FROM ${JENKINS_IMAGE}

USER root
# Copy and install essential pipeline plugins at build time
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Copy Groovy initialization scripts to auto-create admin user and pipeline job
COPY init-admin.groovy /usr/share/jenkins/ref/init.groovy.d/init-admin.groovy
COPY init-job.groovy /usr/share/jenkins/ref/init.groovy.d/init-job.groovy

USER jenkins
