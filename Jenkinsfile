pipeline {
    agent {
        label "jenkins-agent"
    }
    
    environment {
        RELEASE = "1.0.0"
        APP_NAME = "comprehensive-production-ci-cd-pipeline"
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
                    
                        sh '''
                            docker run -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image \
                            mohamedesmael/comprehensive-production-ci-cd-pipeline:latest \
                            --no-progress --scanners vuln --exit-code 0 --severity HIGH,CRITICAL --format table \
                            --timeout 30m
                        '''
                    
                }
            }
        }

        stage("Cleanup Artifacts") {
            steps {
                script {
                    echo "Listing Docker images before cleanup"
                    sh "docker images"
                    echo "Removing Docker images"
                    sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true"
                    sh "docker rmi ${IMAGE_NAME}:latest || true"
                }
            }
        }

        stage("Trigger CD Pipeline") {
            steps {
                script {
                    echo "Triggering CD pipeline with IMAGE_TAG=${IMAGE_TAG}"
                    def result = sh(script: """
                        curl -v -k --user esmael:${JENKINS_API_TOKEN} \
                        -X POST -H 'cache-control: no-cache' \
                        -H 'content-type: application/x-www-form-urlencoded' \
                        --data 'IMAGE_TAG=${IMAGE_TAG}' \
                        'https://mohamedesmael.work.gd/job/git-comprehensive-production-pipeline/buildWithParameters?token=gitops-token'
                    """, returnStatus: true)
        
                    if (result != 0) {
                        error "Failed to trigger the CD pipeline"
                    } else {
                        echo "Successfully triggered the CD pipeline"
                    }
                }
            }
        }
    }
    
    post {
        failure {
            emailext(
                subject: "${env.JOB_NAME} - Build #${env.BUILD_NUMBER} - Failed",
                body: "The build failed. Please check the Jenkins console output.",
                mimeType: 'text/plain',
                to: "mohamed.2714104@gmail.com"
            )
        }
        success {
            emailext(
                subject: "${env.JOB_NAME} - Build #${env.BUILD_NUMBER} - Successful",
                body: "The build was successful. You can proceed with the next steps.",
                mimeType: 'text/plain',
                to: "mohamed.2714104@gmail.com"
            )
        }
    }
}
