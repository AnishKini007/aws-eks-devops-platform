// Jenkins Shared Library - Common Pipeline Functions
// Place this in a shared library repo or in jenkins/vars/

def call(Map config = [:]) {
    // Default configuration
    def defaults = [
        awsRegion: 'us-east-1',
        pythonVersion: '3.11',
        runTests: true,
        runSecurityScan: true
    ]
    
    config = defaults + config
    return config
}

// Build and push Docker image
def buildAndPushImage(String service, String registry, String tag) {
    sh """
        cd apps/${service}
        docker build -t ${registry}/eks-platform/${service}:${tag} .
        docker tag ${registry}/eks-platform/${service}:${tag} ${registry}/eks-platform/${service}:latest
        docker push ${registry}/eks-platform/${service}:${tag}
        docker push ${registry}/eks-platform/${service}:latest
    """
}

// Run Python tests
def runPythonTests(String service) {
    sh """
        cd apps/${service}
        pip install -r requirements.txt
        pip install pytest pytest-cov flake8
        flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics || true
        python -m pytest --cov=. --cov-report=xml || true
    """
}

// Security scan with Trivy
def securityScan(String target, String type = 'fs') {
    sh """
        trivy ${type} --severity HIGH,CRITICAL ${target} || true
    """
}

// Update Kubernetes manifest
def updateK8sManifest(String service, String image) {
    sh """
        sed -i 's|image:.*|image: ${image}|' kubernetes/apps/${service}/deployment.yaml
    """
}

// Send Slack notification
def notifySlack(String status, String channel = '#devops') {
    def color = status == 'SUCCESS' ? 'good' : 'danger'
    def message = "${env.JOB_NAME} #${env.BUILD_NUMBER} - ${status}"
    
    // Uncomment when Slack is configured
    // slackSend(channel: channel, color: color, message: message)
    echo "Notification: ${message}"
}

return this
