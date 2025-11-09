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

                    def match = (commitMsg =~ /\[([A-Z]+-\d+)\]/)
                    if (match.find()) {
                        env.JIRA_ISSUE_KEY = match.group(1)
                        echo "Detected Jira issue: ${env.JIRA_ISSUE_KEY}"

                        jiraSendBuildInfo(
                            site: env.JIRA_SITE,
                            environmentId: "development",
                            environmentName: "Development",
                            pipelineId: env.JOB_NAME,
                            buildNumber: env.BUILD_NUMBER,
                            revision: env.GIT_COMMIT ?: "N/A",
                            issues: [env.JIRA_ISSUE_KEY],
                            buildDisplayName: "#${env.BUILD_NUMBER}",
                            state: "IN_PROGRESS"
                        )
                    } else {
                        echo "No Jira issue key found in the commit message. Skipping Jira step."
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
                            environmentId: "development",
                            environmentName: "Development",
                            environmentType: "development",
                            pipelineId: env.JOB_NAME,
                            buildNumber: env.BUILD_NUMBER,
                            displayName: "Terraform Apply",
                            issues: [env.JIRA_ISSUE_KEY],
                            state: "SUCCESSFUL"
                        )
                    } else {
                        echo "No Jira issue key found. Skipping Jira deployment update."
                    }
                }
            }
        }
    }
}
