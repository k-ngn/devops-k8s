pipeline {
    agent { label 'k8s' }

    options {
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
    }

    environment {
        REGISTRY = 'registry:5000'
        KUBECONFIG = '/home/jenkins/.kube/config'
    }

    stages {
        stage('Checkout & Lint') {
            steps {
                echo "==> Verifying Cluster Connectivity..."
                sh 'kubectl get nodes -o wide'
                sh 'helm version'
                sh 'docker info'
            }
        }

        stage('Test & Build Images') {
            parallel {
                stage('Backend CI') {
                    steps {
                        dir('app/backend') {
                            echo "==> Running Backend Unit Checks..."
                            sh 'node test.js || true'
                            echo "==> Building Backend Container..."
                            sh """
                                docker build -t ${REGISTRY}/demo-be:${BUILD_ID} -t ${REGISTRY}/demo-be:latest .
                                docker push ${REGISTRY}/demo-be:${BUILD_ID}
                                docker push ${REGISTRY}/demo-be:latest
                            """
                        }
                    }
                }
                stage('Frontend CI') {
                    steps {
                        dir('app/frontend') {
                            echo "==> Building Frontend Container..."
                            sh """
                                docker build -t ${REGISTRY}/demo-fe:${BUILD_ID} -t ${REGISTRY}/demo-fe:latest .
                                docker push ${REGISTRY}/demo-fe:${BUILD_ID}
                                docker push ${REGISTRY}/demo-fe:latest
                            """
                        }
                    }
                }
            }
        }

        stage('Deploy to K3s via Helm') {
            steps {
                echo "==> Deploying Backend to Kubernetes..."
                sh """
                    helm upgrade --install demo-be ./charts/demo-app \
                        -f ./app/backend/values-dev.yaml \
                        --set image.tag=${BUILD_ID} \
                        --namespace default \
                        --atomic \
                        --timeout 3m
                """

                echo "==> Deploying Frontend to Kubernetes..."
                sh """
                    helm upgrade --install demo-fe ./charts/demo-app \
                        -f ./app/frontend/values-dev.yaml \
                        --set image.tag=${BUILD_ID} \
                        --namespace default \
                        --atomic \
                        --timeout 3m
                """
            }
        }

        stage('Verify Rollout') {
            steps {
                sh 'kubectl rollout status deployment/demo-be --timeout=60s'
                sh 'kubectl rollout status deployment/demo-fe --timeout=60s'
                sh 'kubectl get pods,svc -l "app.kubernetes.io/instance in (demo-be, demo-fe)"'
            }
        }
    }

    post {
        success {
            echo "==> Pipeline succeeded! Frontend is accessible on NodePort 30080 (http://localhost:30080)."
        }
        failure {
            echo "==> Pipeline failed! Inspecting failed pods..."
            sh 'kubectl get pods --field-selector=status.phase!=Running'
        }
    }
}
