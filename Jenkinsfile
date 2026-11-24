pipeline {
    agent any
    options {
        skipDefaultCheckout()
        disableConcurrentBuilds()
        timestamps()
    }
    triggers { githubPush() }
    environment {
        LIVE_NAME = 'cicd-fa23-bct-021-live'
        LIVE_PORT = '8081'
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.RUN_NAME = "cicd-fa23-bct-021-${env.BUILD_NUMBER}"
                }
                sh 'rm -rf results && mkdir results'
            }
        }
        stage('Package') {
            steps {
                sh '''
                    docker build -t "$RUN_NAME:site" .
                    docker build -t "$RUN_NAME:tests" tests
                '''
            }
        }
        stage('Start Staging') {
            steps {
                sh '''
                    docker network create "$RUN_NAME"
                    docker run -d --name "$RUN_NAME-staging" --network "$RUN_NAME" \
                        --network-alias site "$RUN_NAME:site"
                '''
            }
        }
        stage('Test') {
            steps {
                sh '''
                    docker run --rm --network "$RUN_NAME" \
                        --mount "type=bind,source=$WORKSPACE/results,target=/results" \
                        "$RUN_NAME:tests"
                '''
            }
            post {
                always {
                    junit testResults: 'results/junit.xml', allowEmptyResults: true
                    archiveArtifacts artifacts: 'results/*.png', allowEmptyArchive: true
                }
            }
        }
        stage('Deploy') {
            steps {
                sh '''
                    if docker container inspect "$LIVE_NAME" >/dev/null 2>&1; then
                        docker rm -f "$LIVE_NAME"
                    fi
                    docker run -d --restart unless-stopped --name "$LIVE_NAME" \
                        -p "$LIVE_PORT:80" "$RUN_NAME:site"
                '''
            }
        }
    }
    post {
        always {
            sh '''
                if [ -n "$RUN_NAME" ]; then
                    docker rm -f "$RUN_NAME-staging" 2>/dev/null || true
                    docker network rm "$RUN_NAME" 2>/dev/null || true
                fi
            '''
        }
    }
}
