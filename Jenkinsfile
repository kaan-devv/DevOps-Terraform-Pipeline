@NonCPS
def extractJiraIssueKey(String commitMsg) {
    def matcher = (commitMsg =~ /\[([A-Z]+-\d+)\]/)
    if (matcher.find()) {
        return matcher.group(1)
    }
    return null
}

pipeline {
    agent any

    environment {
        AWS_CREDS = credentials('aws-creds')
        AWS_DEFAULT_REGION = 'us-east-1'
        INVENTORY_FILE = 'inventory.json'
        S3_BUCKET_NAME = 's3://kaan-inventory-bucket'
        JIRA_SITE = 'kaanylmz.atlassian.net'
        JIRA_SECRET = 'jira-secret-cloud'
        JIRA_ISSUE_KEY = ""
    }

    stages {

        stage('1. Checkout Code') {
            steps {
                echo "Fetching the latest code from GitHub..."
                checkout scm
            }
        }

        stage('2. Jira: Send Build Info') {
            steps {
                script {
                    echo "Extracting Jira issue key from commit message..."
                    def commitMsg = sh(script: 'git log -1 --pretty=%B', returnStdout: true).trim()
                    echo "Commit message: ${commitMsg}"

                    // Use NonCPS-safe function
                    def issueKey = extractJiraIssueKey(commitMsg)
                    if (issueKey) {
                        env.JIRA_ISSUE_KEY = issueKey
                        echo "Detected Jira issue: ${env.JIRA_ISSUE_KEY}"

                        jiraSendBuildInfo(
                            site: env.JIRA_SITE,
                            pipelineId: env.JOB_NAME,
                            buildNumber: env.BUILD_NUMBER,
                            state: 'in_progress',
                            issueKeys: [env.JIRA_ISSUE_KEY]
                        )
                    } else {
                        echo "No Jira issue key found in the commit message. Skipping Jira update."
                    }
                }
            }
        }

        stage('3. Terraform: Apply') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh '''
                        terraform init -input=false
                        terraform apply -auto-approve -input=false
                    '''
                }
            }
        }

        stage('4. Save Inventory to S3') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    echo "Generating current infrastructure inventory..."
                    sh '''
                        terraform output -json > ${INVENTORY_FILE}
                        aws s3 cp ${INVENTORY_FILE} ${S3_BUCKET_NAME}/${INVENTORY_FILE}
                    '''
                    echo "Inventory uploaded to S3: ${S3_BUCKET_NAME}/${INVENTORY_FILE}"
                }
            }
        }

        stage('5. Jira: Send Deployment Info') {
            steps {
                script {
                    if (env.JIRA_ISSUE_KEY?.trim()) {
                        jiraSendDeploymentInfo(
                            site: env.JIRA_SITE,
                            environmentId: 'prod-env',
                            environmentName: 'Production',
                            environmentType: 'production',
                            issueKeys: [env.JIRA_ISSUE_KEY]
                        )
                        echo "Deployment info sent to Jira Cloud for issue ${env.JIRA_ISSUE_KEY}."
                    } else {
                        echo "No Jira issue key found. Skipping Jira deployment update."
                    }
                }
            }
        }
    }
}
