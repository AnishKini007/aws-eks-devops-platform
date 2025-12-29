// Jenkinsfile - Main CI Pipeline for Microservices
// This pipeline builds, tests, scans, and deploys microservices to EKS using Helm

pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: python
    image: python:3.11-slim
    command:
    - cat
    tty: true
  - name: docker
    image: docker:24-dind
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-socket
      mountPath: /var/run/docker.sock
  - name: aws-cli
    image: amazon/aws-cli:latest
    command:
    - cat
    tty: true
  - name: trivy
    image: aquasec/trivy:latest
    command:
    - cat
    tty: true
  - name: helm
    image: alpine/helm:3.13.3
    command:
    - cat
    tty: true
  volumes:
  - name: docker-socket
    hostPath:
      path: /var/run/docker.sock
'''
        }
    }

    environment {
        AWS_REGION = 'us-east-1'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        DOCKER_BUILDKIT = '1'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    parameters {
        choice(
            name: 'SERVICE',
            choices: ['all', 'user-service', 'order-service', 'product-service'],
            description: 'Select service to build (or all)'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip running tests'
        )
        booleanParam(
            name: 'DEPLOY_TO_EKS',
            defaultValue: true,
            description: 'Deploy to EKS after successful build'
        )
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    env.GIT_BRANCH_NAME = sh(
                        script: 'git rev-parse --abbrev-ref HEAD',
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Detect Changes') {
            steps {
                script {
                    def changes = []
                    if (params.SERVICE == 'all') {
                        // Detect which services have changes
                        def changedFiles = sh(
                            script: 'git diff --name-only HEAD~1 || echo "apps/"',
                            returnStdout: true
                        ).trim()
                        
                        if (changedFiles.contains('apps/user-service')) {
                            changes.add('user-service')
                        }
                        if (changedFiles.contains('apps/order-service')) {
                            changes.add('order-service')
                        }
                        if (changedFiles.contains('apps/product-service')) {
                            changes.add('product-service')
                        }
                        
                        // If no specific changes detected, build all
                        if (changes.isEmpty()) {
                            changes = ['user-service', 'order-service', 'product-service']
                        }
                    } else {
                        changes.add(params.SERVICE)
                    }
                    
                    env.SERVICES_TO_BUILD = changes.join(',')
                    echo "Services to build: ${env.SERVICES_TO_BUILD}"
                }
            }
        }

        stage('Lint & Test') {
            when {
                expression { !params.SKIP_TESTS }
            }
            parallel {
                stage('User Service') {
                    when {
                        expression { env.SERVICES_TO_BUILD.contains('user-service') }
                    }
                    steps {
                        container('python') {
                            dir('apps/user-service') {
                                sh '''
                                    pip install -r requirements.txt
                                    pip install pytest pytest-cov flake8 black
                                    
                                    echo "Running linting..."
                                    flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics || true
                                    
                                    echo "Checking formatting..."
                                    black --check . || true
                                    
                                    echo "Running tests..."
                                    python -m pytest --cov=. --cov-report=xml || true
                                '''
                            }
                        }
                    }
                }
                stage('Order Service') {
                    when {
                        expression { env.SERVICES_TO_BUILD.contains('order-service') }
                    }
                    steps {
                        container('python') {
                            dir('apps/order-service') {
                                sh '''
                                    pip install -r requirements.txt
                                    pip install pytest pytest-cov flake8
                                    flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics || true
                                    python -m pytest --cov=. --cov-report=xml || true
                                '''
                            }
                        }
                    }
                }
                stage('Product Service') {
                    when {
                        expression { env.SERVICES_TO_BUILD.contains('product-service') }
                    }
                    steps {
                        container('python') {
                            dir('apps/product-service') {
                                sh '''
                                    pip install -r requirements.txt
                                    pip install pytest pytest-cov flake8
                                    flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics || true
                                    python -m pytest --cov=. --cov-report=xml || true
                                '''
                            }
                        }
                    }
                }
            }
        }

        stage('Security Scan - Source') {
            steps {
                container('trivy') {
                    script {
                        def services = env.SERVICES_TO_BUILD.split(',')
                        for (service in services) {
                            sh """
                                echo "Scanning ${service} source code..."
                                trivy fs --severity HIGH,CRITICAL apps/${service} || true
                            """
                        }
                    }
                }
            }
        }

        stage('Build & Push Images') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                container('docker') {
                    withCredentials([
                        string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
                        usernamePassword(
                            credentialsId: 'aws-credentials',
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        script {
                            // Login to ECR
                            sh '''
                                apk add --no-cache aws-cli
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                            '''
                            
                            def services = env.SERVICES_TO_BUILD.split(',')
                            for (service in services) {
                                def imageName = "${ECR_REGISTRY}/eks-platform/${service}"
                                def imageTag = "${env.GIT_COMMIT_SHORT}"
                                
                                echo "Building ${service}..."
                                sh """
                                    cd apps/${service}
                                    docker build -t ${imageName}:${imageTag} .
                                    docker tag ${imageName}:${imageTag} ${imageName}:latest
                                    docker push ${imageName}:${imageTag}
                                    docker push ${imageName}:latest
                                """
                            }
                        }
                    }
                }
            }
        }

        stage('Security Scan - Images') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                }
            }
            steps {
                container('trivy') {
                    withCredentials([
                        string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID'),
                        usernamePassword(
                            credentialsId: 'aws-credentials',
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        script {
                            def services = env.SERVICES_TO_BUILD.split(',')
                            for (service in services) {
                                def imageName = "${ECR_REGISTRY}/eks-platform/${service}:${env.GIT_COMMIT_SHORT}"
                                sh """
                                    echo "Scanning image: ${imageName}"
                                    trivy image --severity HIGH,CRITICAL ${imageName} || true
                                """
                            }
                        }
                    }
                }
            }
        }

        stage('Update Helm Values') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'github-credentials',
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )
                ]) {
                    script {
                        def services = env.SERVICES_TO_BUILD.split(',')
                        for (service in services) {
                            // Update Helm values file with new image tag
                            sh """
                                sed -i 's|tag:.*|tag: "${env.GIT_COMMIT_SHORT}"|' helm/values/${service}.yaml
                            """
                        }
                        
                        sh '''
                            git config user.email "jenkins@ci.local"
                            git config user.name "Jenkins CI"
                            git add helm/values/*.yaml
                            git diff --staged --quiet || git commit -m "chore: Update image tags to ${GIT_COMMIT_SHORT} [skip ci]"
                            git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/${GIT_USERNAME}/aws-eks-devops-platform.git HEAD:main || true
                        '''
                    }
                }
            }
        }

        stage('Deploy via Helm') {
            when {
                allOf {
                    branch 'main'
                    expression { params.DEPLOY_TO_EKS }
                }
            }
            steps {
                container('helm') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'aws-credentials',
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        ),
                        string(credentialsId: 'aws-account-id', variable: 'AWS_ACCOUNT_ID')
                    ]) {
                        script {
                            // Configure kubectl via aws cli
                            sh '''
                                apk add --no-cache aws-cli kubectl
                                aws eks update-kubeconfig --name eks-platform-dev --region ${AWS_REGION}
                            '''
                            
                            def services = env.SERVICES_TO_BUILD.split(',')
                            for (service in services) {
                                def releaseName = service
                                def chartPath = "helm/charts/microservice"
                                def valuesFile = "helm/values/${service}.yaml"
                                
                                echo "Deploying ${service} via Helm..."
                                sh """
                                    helm upgrade --install ${releaseName} ${chartPath} \
                                        --namespace microservices \
                                        --create-namespace \
                                        -f ${valuesFile} \
                                        --set image.tag=${env.GIT_COMMIT_SHORT} \
                                        --set image.repository=${ECR_REGISTRY}/eks-platform/${service} \
                                        --wait \
                                        --timeout 5m \
                                        --atomic
                                """
                            }
                        }
                    }
                }
            }
        }

        stage('Notify ArgoCD') {
            when {
                allOf {
                    branch 'main'
                    expression { params.DEPLOY_TO_EKS }
                }
            }
            steps {
                echo "Helm values updated in Git. ArgoCD will auto-sync deployments."
                // Optional: Trigger ArgoCD sync via CLI or API
                // sh 'argocd app sync user-service order-service product-service --prune'
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo "Pipeline completed successfully!"
            // Notify Slack/Teams on success
            // slackSend(color: 'good', message: "Build successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
        }
        failure {
            echo "Pipeline failed!"
            // Notify Slack/Teams on failure
            // slackSend(color: 'danger', message: "Build failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
        }
    }
}
