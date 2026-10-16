#!/usr/bin/env bash
set -e

JENKINS_URL="${JENKINS_URL:-http://jenkins-controller:8080}"
JENKINS_USER="${JENKINS_ADMIN_USER:-admin}"
JENKINS_PASS="${JENKINS_ADMIN_PASS:-admin123}"
AGENT_NAME="${AGENT_NAME:-k8s-auto-agent}"
AGENT_EXECUTORS="${AGENT_EXECUTORS:-4}"
AGENT_LABELS="${AGENT_LABELS:-k8s docker helm linux}"
AGENT_WORKDIR="${AGENT_WORKDIR:-/home/jenkins/agent}"

echo "==> [1/4] Configuring K3s kubeconfig for Jenkins Agent..."
mkdir -p ~/.kube
while [ ! -f /k3s-config/kubeconfig.yaml ]; do
  echo "Waiting for K3s to generate /k3s-config/kubeconfig.yaml..."
  sleep 2
done
sed 's|https://127.0.0.1:6443|https://k3s:6443|g' /k3s-config/kubeconfig.yaml > ~/.kube/config
chmod 600 ~/.kube/config
echo "==> K3s kubeconfig ready!"

echo "==> [2/4] Waiting for Jenkins Controller at ${JENKINS_URL}..."
until curl -s -f -o /dev/null "${JENKINS_URL}/login"; do
  echo "Jenkins Controller is still starting up... sleeping 5s"
  sleep 5
done
echo "==> Jenkins Controller is UP!"

echo "==> [3/4] Downloading jenkins-cli.jar and registering node '${AGENT_NAME}'..."
curl -sSfL "${JENKINS_URL}/jnlpJars/jenkins-cli.jar" -o /tmp/jenkins-cli.jar

# Auto-create node if not already present
if ! java -jar /tmp/jenkins-cli.jar -s "${JENKINS_URL}" -auth "${JENKINS_USER}:${JENKINS_PASS}" -webSocket get-node "${AGENT_NAME}" >/dev/null 2>&1; then
  cat <<EOF | java -jar /tmp/jenkins-cli.jar -s "${JENKINS_URL}" -auth "${JENKINS_USER}:${JENKINS_PASS}" -webSocket create-node "${AGENT_NAME}"
<slave>
  <name>${AGENT_NAME}</name>
  <description>Auto-joined Docker/K3s/Helm CI Agent</description>
  <remoteFS>${AGENT_WORKDIR}</remoteFS>
  <numExecutors>${AGENT_EXECUTORS}</numExecutors>
  <mode>NORMAL</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy\$Always"/>
  <launcher class="hudson.slaves.JNLPLauncher">
    <workDirSettings>
      <disabled>false</disabled>
      <workDirPath>${AGENT_WORKDIR}</workDirPath>
      <internalDir>remoting</internalDir>
      <failIfWorkDirIsMissing>false</failIfWorkDirIsMissing>
    </workDirSettings>
    <webSocket>true</webSocket>
  </launcher>
  <label>${AGENT_LABELS}</label>
  <nodeProperties/>
</slave>
EOF
  echo "==> Node '${AGENT_NAME}' registered successfully!"
else
  echo "==> Node '${AGENT_NAME}' already registered."
fi

# Fetch the secret via Groovy CLI
echo "==> Extracting secret for node '${AGENT_NAME}'..."
AGENT_SECRET=$(echo "println jenkins.model.Jenkins.instance.getNode('${AGENT_NAME}').getComputer().getJnlpMac()" | \
  java -jar /tmp/jenkins-cli.jar -s "${JENKINS_URL}" -auth "${JENKINS_USER}:${JENKINS_PASS}" -webSocket groovy = | tr -d '[:space:]')

if [ -z "${AGENT_SECRET}" ]; then
  echo "ERROR: Failed to retrieve agent secret from Jenkins controller!"
  exit 1
fi
echo "==> Secret successfully retrieved (length: ${#AGENT_SECRET})"

echo "==> [4/4] Connecting Inbound Agent '${AGENT_NAME}' via WebSocket..."
# Export standard Jenkins remoting environment variables
export JENKINS_URL="${JENKINS_URL}"
export JENKINS_SECRET="${AGENT_SECRET}"
export JENKINS_AGENT_NAME="${AGENT_NAME}"
export JENKINS_AGENT_WORKDIR="${AGENT_WORKDIR}"
export JENKINS_WEB_SOCKET="true"

# Launch agent directly via jar without wrapper flag collision
exec java -jar /usr/share/jenkins/agent.jar \
  -url "${JENKINS_URL}" \
  -workDir "${AGENT_WORKDIR}" \
  -webSocket \
  -secret "${AGENT_SECRET}" \
  -name "${AGENT_NAME}"
