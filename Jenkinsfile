pipeline {
    agent {
        label "jenkins-agent"
    }

    environment {
        JAVA_HOME = '/usr/lib/jvm/temurin-17-jdk-amd64'
        PATH = "${JAVA_HOME}/bin:${env.PATH}"
        APP_NAME = "comprehensive-production-ci-cd-pipeline"
        RELEASE = "1.0.0"
        DOCKER_USER = "mohamedesmael"
        DOCKER_PASS = 'dockerhub'
        IMAGE_NAME = "${DOCKER_USER}" + "/" + "${APP_NAME}"
        IMAGE_TAG = "${RELEASE}-${BUILD_NUMBER}"
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
                        docker_image = docker.build "${IMAGE_NAME}"
                    }

                    docker.withRegistry('', DOCKER_PASS) {
                        docker_image.push("${IMAGE_TAG}")
                        docker_image.push('latest')
                    }
                }
            }
        }
    }
}

