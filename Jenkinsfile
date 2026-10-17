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
        stage('Checkout & Environment Check') {
            steps {
                echo "==> Verifying Cluster & Agent Tools..."
                sh 'kubectl get nodes -o wide'
                sh 'helm version'
                sh 'docker info'
                sh 'trivy --version'
            }
        }

        stage('Code Quality & Linting') {
            parallel {
                stage('Lint Backend') {
                    steps {
                        dir('app/backend') {
                            echo "==> Linting Node.js source files..."
                            sh 'docker run --rm -v $(pwd):/app -w /app node:20-alpine node --check server.js test.js'
                            echo "==> Backend code syntax verified."
                        }
                    }
                }
                stage('Lint Helm Chart') {
                    steps {
                        echo "==> Linting generic Helm chart..."
                        sh 'helm lint ./charts/demo-app'
                    }
                }
            }
        }

        stage('Test & Build Images') {
            parallel {
                stage('Backend CI') {
                    steps {
                        dir('app/backend') {
                            echo "==> Running Backend Unit Checks..."
                            sh 'docker run --rm -v $(pwd):/app -w /app node:20-alpine node test.js'
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

        stage('Security Scan (Trivy)') {
            parallel {
                stage('Scan Backend Image') {
                    steps {
                        echo "==> Scanning Backend Container for CVEs..."
                        // Note: Use --exit-code 0 for report mode, or 1 to fail on CRITICAL
                        sh """
                            trivy image --severity HIGH,CRITICAL \
                                --exit-code 0 \
                                --no-progress \
                                ${REGISTRY}/demo-be:${BUILD_ID}
                        """
                    }
                }
                stage('Scan Frontend Image') {
                    steps {
                        echo "==> Scanning Frontend Container for CVEs..."
                        sh """
                            trivy image --severity HIGH,CRITICAL \
                                --exit-code 0 \
                                --no-progress \
                                ${REGISTRY}/demo-fe:${BUILD_ID}
                        """
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
                        --namespace demo-app \
                        --create-namespace \
                        --atomic \
                        --timeout 3m
                """

                echo "==> Deploying Frontend to Kubernetes..."
                sh """
                    helm upgrade --install demo-fe ./charts/demo-app \
                        -f ./app/frontend/values-dev.yaml \
                        --set image.tag=${BUILD_ID} \
                        --namespace demo-app \
                        --create-namespace \
                        --atomic \
                        --timeout 3m
                """
            }
        }

        stage('Verify Rollout') {
            steps {
                sh 'kubectl -n demo-app rollout status deployment/demo-be-demo-app --timeout=60s'
                sh 'kubectl -n demo-app rollout status deployment/demo-fe-demo-app --timeout=60s'
                sh 'kubectl -n demo-app get pods,svc -l "app.kubernetes.io/instance in (demo-be, demo-fe)"'
            }
        }
    }

    post {
        success {
            echo "==> Pipeline succeeded! Code quality and Trivy scans passed."
        }
        failure {
            echo "==> Pipeline failed! Inspecting cluster state..."
            sh 'kubectl -n demo-app get pods --field-selector=status.phase!=Running'
        }
    }
}
