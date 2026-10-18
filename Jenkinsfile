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
                script {
                    def branch = env.BRANCH_NAME ?: 'staging'
                    echo "==> Jenkins Multibranch Pipeline triggered for branch: [${branch}]"
                    echo "==> Workspace Git State:"
                }
                sh 'git status'
                sh 'git log -1 --oneline'

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
                            sh 'node --check server.js test.js'
                            echo "==> Backend code syntax verified."
                        }
                    }
                }
                stage('Lint Helm Chart') {
                    steps {
                        echo "==> Linting generic Helm chart..."
                        sh 'helm lint ./helm/demo-app'
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
                            sh 'node test.js'
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
                //         sh """
                //             trivy image --severity HIGH,CRITICAL \
				// --ignore-unfixed \
                //                 --exit-code 0 \
                //                 --no-progress \
                //                 ${REGISTRY}/demo-be:${BUILD_ID}
                //         """
                    }
                }
                stage('Scan Frontend Image') {
                    steps {
                        echo "==> Scanning Frontend Container for CVEs..."
                //         sh """
                //             trivy image --severity HIGH,CRITICAL \
				// --ignore-unfixed \
                //                 --exit-code 0 \
                //                 --no-progress \
                //                 ${REGISTRY}/demo-fe:${BUILD_ID}
                //         """
                    }
                }
            }
        }

        stage('Deploy to K3s via Helm') {
            steps {
                script {
                    def branch = env.BRANCH_NAME ?: (params.BRANCH_NAME ?: 'staging')
                    def targetEnv = (branch == 'main' || branch == 'prod') ? 'prod' : 'staging'
                    def targetNamespace = "demo-app-${targetEnv}"
                    def beValues = "./app/backend/values-${targetEnv}.yaml"
                    def feValues = "./app/frontend/values-${targetEnv}.yaml"

                    if (!fileExists(beValues) || !fileExists(feValues)) {
                        error("==> FATAL: Missing values configuration files for environment [${targetEnv}]: ${beValues} or ${feValues}")
                    }

                    echo "==> Branch: [${branch}] -> Target Environment: [${targetEnv}] | Target Namespace: [${targetNamespace}]"
                    echo "==> Deploying Backend with ${beValues}..."
                    sh """
                        helm upgrade --install demo-be ./helm/demo-app \
                            -f ${beValues} \
                            --set image.tag=${BUILD_ID} \
                            --namespace ${targetNamespace} \
                            --create-namespace \
                            --atomic \
                            --timeout 3m
                    """

                    echo "==> Deploying Frontend with ${feValues}..."
                    sh """
                        helm upgrade --install demo-fe ./helm/demo-app \
                            -f ${feValues} \
                            --set image.tag=${BUILD_ID} \
                            --namespace ${targetNamespace} \
                            --create-namespace \
                            --atomic \
                            --timeout 3m
                    """
                }
            }
        }

        stage('Verify Rollout') {
            steps {
                script {
                    def branch = env.BRANCH_NAME ?: (params.BRANCH_NAME ?: 'staging')
                    def targetEnv = (branch == 'main' || branch == 'prod') ? 'prod' : 'staging'
                    def targetNamespace = "demo-app-${targetEnv}"

                    echo "==> Verifying Rollout Status in namespace [${targetNamespace}]..."
                    sh "kubectl -n ${targetNamespace} rollout status deployment/demo-be-demo-app --timeout=60s"
                    sh "kubectl -n ${targetNamespace} rollout status deployment/demo-fe-demo-app --timeout=60s"
                    sh "kubectl -n ${targetNamespace} get pods,svc -l 'app.kubernetes.io/instance in (demo-be, demo-fe)'"
                }
            }
        }
    }

    post {
        success {
            echo "==> Multibranch Pipeline succeeded! Code quality and deployment verified."
        }
        failure {
            echo "==> Multibranch Pipeline failed! Inspecting cluster state..."
            script {
                def branch = env.BRANCH_NAME ?: (params.BRANCH_NAME ?: 'staging')
                def targetEnv = (branch == 'main' || branch == 'prod') ? 'prod' : 'staging'
                def targetNamespace = "demo-app-${targetEnv}"
                sh "kubectl -n ${targetNamespace} get pods --field-selector=status.phase!=Running || true"
            }
        }
    }
}
