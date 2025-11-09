@NonCPS
def extractJiraIssueKey(String commitMsg) {
    if (!commitMsg) {
        return null
    }
    commitMsg = commitMsg.trim().replaceAll("\\r|\\n", "")
    def matcher = (commitMsg =~ /([A-Z]+-\d+)/)
    if (matcher.find()) {
        return matcher.group(1)
    }
    return null
}


pipeline {
    agent any

    environment {
        JIRA_API_TOKEN = credentials('jira-secret-cloud') 
        JIRA_SITE = "kaanylmz.atlassian.net"
        S3_BUCKET_NAME = "kaan-inventory-bucket"
        INVENTORY_FILE = 'inventory.json'
        JIRA_TRANSITION_ID_IN_PROGRESS = "21"
        JIRA_TRANSITION_ID_DONE = "31"
    }

    stages {
        stage('1. Checkout Code') {
            steps {
                echo "Fetching the latest code from GitHub..."
                checkout scm
            }
        }

        stage('2. Jira: Move to In Progress') {
            steps {
                script {
                    echo "Extracting Jira issue key from commit message..."
                    def commitMessage = sh(script: 'git log -1 --pretty=%B', returnStdout: true).trim()
                    echo "Commit message: ${commitMessage}"

                    def issueKey = extractJiraIssueKey(commitMessage)
                    
                    if (issueKey) {
                        env.JIRA_ISSUE_KEY = issueKey
                        echo "Detected Jira issue: ${env.JIRA_ISSUE_KEY}"
                        echo "Moving issue ${env.JIRA_ISSUE_KEY} to In Progress..."
                        
                        sh """
                            curl -s -X POST \
                            -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
                            -H "Content-Type: application/json" \
                            --data '{ "transition": { "id": "${JIRA_TRANSITION_ID_IN_PROGRESS}" } }' \
                            https://${JIRA_SITE}/rest/api/3/issue/${env.JIRA_ISSUE_KEY}/transitions
                        """
                    } else {
                        echo "⚠️ No Jira issue key found in commit message."
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
                        aws s3 cp ${INVENTORY_FILE} s3://${S3_BUCKET_NAME}/${INVENTORY_FILE}
                    '''
                    echo "Inventory uploaded to S3: s3://${S3_BUCKET_NAME}/${INVENTORY_FILE}"
                }
            }
        }

        stage('5. Jira: Move to Done') {
            when {
                expression { env.JIRA_ISSUE_KEY?.trim() }
            }
            steps {
                echo "Moving issue ${env.JIRA_ISSUE_KEY} to Done..."
                sh """
                    curl -s -X POST \
                    -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
                    -H "Content-Type: application/json" \
                    --data '{ "transition": { "id": "${JIRA_TRANSITION_ID_DONE}" } }' \
                    https://${JIRA_SITE}/rest/api/3/issue/${env.JIRA_ISSUE_KEY}/transitions
                """
            }
        }
    }
}