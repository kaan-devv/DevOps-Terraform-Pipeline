@NonCPS
def extractJiraIssueKey(String commitMsg) {
    if (!commitMsg) return null
    commitMsg = commitMsg.trim().replaceAll("\\r|\\n", "")
    def matcher = (commitMsg =~ /\b([A-Z]+-\d+)\b/)
    if (matcher.find()) {
        return matcher.group(1)
    }
    return null
}

pipeline {
    agent any

    environment {
        JIRA_SITE = "kaanylmz.atlassian.net"
        S3_BUCKET_NAME = "kaan-inventory-bucket"
        INVENTORY_FILE = 'inventory.json'
        JIRA_TRANSITION_ID_IN_PROGRESS = "21"
        JIRA_TRANSITION_ID_DONE = "31"
        JIRA_ISSUE_KEY = ""
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
                    
                    if (!issueKey) {
                        echo "No Jira issue key found in commit message."
                        return
                    }

                    env.JIRA_ISSUE_KEY = issueKey
                    echo "Detected Jira issue: ${env.JIRA_ISSUE_KEY}"
                    
                    withCredentials([usernamePassword(credentialsId: 'jira-token', usernameVariable: 'JIRA_USER', passwordVariable: 'JIRA_TOKEN')]) {
                        echo "Moving issue ${env.JIRA_ISSUE_KEY} to In Progress..."
                        def response = sh(
                            script: """curl -s -o response.json -w "%{http_code}" \
                            -u "$JIRA_USER:$JIRA_TOKEN" \
                            -H "Accept: application/json" \
                            -H "Content-Type: application/json" \
                            --data '{ "transition": { "id": "${JIRA_TRANSITION_ID_IN_PROGRESS}" } }' \
                            https://${JIRA_SITE}/rest/api/3/issue/${env.JIRA_ISSUE_KEY}/transitions""",
                            returnStdout: true
                        ).trim()

                        echo "Jira In Progress transition response code: ${response}"
                        sh 'cat response.json || true'

                        if (response != "204") {
                            error("Jira transition to In Progress failed. Check credentials or transition ID.")
                        }
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
                script {
                    withCredentials([usernamePassword(credentialsId: 'jira-token', usernameVariable: 'JIRA_USER', passwordVariable: 'JIRA_TOKEN')]) {
                        echo "Moving issue ${env.JIRA_ISSUE_KEY} to Done..."
                        def response = sh(
                            script: """curl -s -o response.json -w "%{http_code}" \
                            -u "$JIRA_USER:$JIRA_TOKEN" \
                            -H "Accept: application/json" \
                            -H "Content-Type: application/json" \
                            --data '{ "transition": { "id": "${JIRA_TRANSITION_ID_DONE}" } }' \
                            https://${JIRA_SITE}/rest/api/3/issue/${env.JIRA_ISSUE_KEY}/transitions""",
                            returnStdout: true
                        ).trim()

                        echo "Jira Done transition response code: ${response}"
                        sh 'cat response.json || true'

                        if (response != "204") {
                            error("Jira transition to Done failed. Check credentials or transition ID.")
                        }
                    }
                }
            }
        }
    }
}