pipeline {
    agent {
        label "jenkins-agent"
    }

    environment {
        JAVA_HOME = '/usr/lib/jvm/temurin-17-jdk-amd64'
        PATH = "${JAVA_HOME}/bin:${env.PATH}"
        RELEASE = "1.0.0"
        DOCKER_USER = "mohamedesmael"
        DOCKER_PASS = 'dockerhub'
        IMAGE_NAME = "${DOCKER_USER}/${APP_NAME}"
        IMAGE_TAG = "${RELEASE}-${BUILD_NUMBER}"
        JENKINS_API_TOKEN = credentials("JENKINS_API_TOKEN")
    }

    tools {
        jdk 'Java17'    
        maven 'Maven3' 
    }

    stages {
        stage("Initialize Workspace") {
            steps {
                cleanWs()
            }
        }

        stage("Fetch Source Code") {
            steps {
                git branch: 'main', 
                    credentialsId: 'github', 
                    url: 'https://github.com/mohamedesmael10/comprehensive-production-ci-cd-pipeline'
            }
        }

        stage("Compile and Package Application") {
            steps {
                sh "mvn clean package"
            }
        }

        stage("Execute Unit Tests") {
            steps {
                sh "mvn test"
            }
        }

        stage("Run Static Code Analysis") {
            steps {
                script {
                    withSonarQubeEnv(credentialsId: 'jenkins_sonarqube_token') {
                        sh "mvn sonar:sonar"
                    }
                }
            }
        }

        stage("Enforce Quality Gate") {
            steps {
                script {
                    waitForQualityGate abortPipeline: true, credentialsId: 'jenkins_sonarqube_token'
                }
            }
        }

        stage("Containerize and Push Image") {
            steps {
                script {
                    docker.withRegistry('', DOCKER_PASS) {
                        def docker_image = docker.build("${IMAGE_NAME}")
                        docker_image.push("${IMAGE_TAG}")
                        docker_image.push('latest')
                    }
                }
            }
        }

        stage("Trivy Scan") {
            steps {
                script {
                    retry(3) {
                            sh '''
                                docker run -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image \
                                mohamedesmael/comprehensive-production-ci-cd-pipeline:latest \
                                --no-progress --scanners vuln --exit-code 0 --severity HIGH,CRITICAL --format table \
                                --timeout 30m
                            '''
                           }
                }
            }
        }

        stage("Cleanup Artifacts") {
            steps {
                script {
                    sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true"
                    sh "docker rmi ${IMAGE_NAME}:latest || true"
                }
            }
        }

        stage("Trigger CD Pipeline") {
            steps {
                script {
                        sh """
                            curl -v -k --user admin:${JENKINS_API_TOKEN} \
                            -X POST -H 'cache-control: no-cache' \
                            -H 'content-type: application/x-www-form-urlencoded' \
                            --data 'IMAGE_TAG=${IMAGE_TAG}' \
                            'https://mohamedesmael.work.gd/job/git-comprehensive-production-pipeline/buildWithParameters?token=gitops-token'
                        """
                }
            }
        }
    }

    post {
        failure {
            emailext(
                body: '''${SCRIPT, template="groovy-html.template"}''',
                subject: "${env.JOB_NAME} - Build #${env.BUILD_NUMBER} - Failed",
                mimeType: 'text/html',
                to: "mohamed.2714104@gmail.com"
            )
        }
        success {
            emailext(
                body: '''${SCRIPT, template="groovy-html.template"}''',
                subject: "${env.JOB_NAME} - Build #${env.BUILD_NUMBER} - Successful",
                mimeType: 'text/html',
                to: "mohamed.2714104@gmail.com"
            )
        }
    }
}
