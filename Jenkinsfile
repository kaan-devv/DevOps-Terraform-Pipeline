pipeline {
    agent any

    environment {
        AWS_CREDS = credentials('aws-creds')
        AWS_DEFAULT_REGION = 'us-east-1'
        ENVANTER_DOSYASI = 'inventory.json'
        S3_BUCKET_NAME = 's3://kaan-inventory-bucket'
        JIRA_SITE = 'https://kaanylmz.atlassian.net' 
        JIRA_ISSUE_KEY = ""
    }

    stages {
        
        stage('1. Checkout Code') {
            steps {
                echo "Checking out the latest code from GitHub..."
                checkout scm
            }
        }

        stage('2. Jira: Update to In Progress') {
            steps {
                script {
                    echo "Updating Jira task to 'In Progress'..."
                    
                    def commitMsg = sh(returnStdout: true, script: 'git log -1 --pretty=%B').trim()
                    echo "Detected Commit Message: ${commitMsg}"

                    def match = (commitMsg =~ /\[([A-Z]+-\d+)\]/)
                    def jiraKey = match ? match[0][1] : null 

                    if (jiraKey) {
                        env.JIRA_ISSUE_KEY = jiraKey
                        echo "Jira Key Found: ${env.JIRA_ISSUE_KEY}"

                        
                        jiraTransitionIssue(
                            site: env.JIRA_SITE,
                            issueKey: env.JIRA_ISSUE_KEY,
                            transitionName: 'In Progress', 
                            comment: "Pipeline started. Running terraform apply...",
                            credentialsId: 'jira-token'
                        )
                        echo "Jira task ${env.JIRA_ISSUE_KEY} transitioned to In Progress."
                        
                    } else {
                        echo "Jira issue key (e.g., [JIRA-101]) not found in commit message. Skipping Jira step."
                    }
                }
            }
        }

        stage('3. Terraform: Apply') {
            steps {
                sh 'terraform init -input=false'
                sh 'terraform apply -auto-approve -input=false'
            }
        }

        stage('4. Save Inventory (S3)') {
            steps {
                echo "Generating latest inventory file..."
                sh "terraform output -json > ${ENVANTER_DOSYASI}"
                
                echo "Uploading inventory file to S3: ${S3_BUCKET_NAME}/${ENVANTER_DOSYASI}"
                sh "aws s3 cp ${ENVANTER_DOSYASI} ${S3_BUCKET_NAME}/${ENVANTER_DOSYASI}"
            }
        }

        stage('5. Jira: Update to Done') {
            steps {
                script {
                    echo "Updating Jira task to 'Done'..."
                    
                    if (env.JIRA_ISSUE_KEY && !env.JIRA_ISSUE_KEY.isEmpty()) {
                        echo "Updating Jira Key ${env.JIRA_ISSUE_KEY} to 'Done'."
                        
                       
                        jiraTransitionIssue(
                            site: env.JIRA_SITE,
                            issueKey: env.JIRA_ISSUE_KEY,
                            transitionName: 'Done',
                            comment: "Pipeline finished successfully. Changes applied. Panel updated.",
                            credentialsId: 'jira-token'
                        )
                        echo "Jira task ${env.JIRA_ISSUE_KEY} transitioned to Done."
                        
                    } else {
                        echo "No Jira issue key was tracked. Skipping this step."
                    }
                }
            }
        }
    }
}