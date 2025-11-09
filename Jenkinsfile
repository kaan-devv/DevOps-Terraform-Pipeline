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
        
        stage('1. Kodu Al (Checkout)') {
            steps {
                echo "GitHub'dan en güncel kod alınıyor..."
                checkout scm
            }
        }

        stage('2. Jira: Update to In Progress') {
            steps {
                script {
                    echo "Jira görevi 'In Progress' (Yapılıyor) olarak güncelleniyor..."
                    def matcher = (env.CHANGE_MESSAGE ?: "").find("\\[([A-Z]+-\\d+)\\]")
                    
                    if (matcher) {
                        env.JIRA_ISSUE_KEY = matcher[1]
                        
                        jiraTransitionIssue(
                            issueKey: env.JIRA_ISSUE_KEY,
                            siteName: env.JIRA_SITE,
                            transitionName: 'In Progress',
                            comment: "Pipeline başladı. Terraform apply çalıştırılıyor...",
                            credentialsId: 'jira-token'
                        )
                    } else {
                        echo "Commit mesajında Jira görev kodu (örn: [JIRA-101]) bulunamadı, Jira adımı atlanıyor."
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

        stage('4. Envanteri Kaydet (S3)') {
            steps {
                echo "En güncel envanter listesi oluşturuluyor..."
                sh "terraform output -json > ${ENVANTER_DOSYASI}"
                
                echo "Envanter listesi S3'e yükleniyor: ${S3_BUCKET_NAME}/${ENVANTER_DOSYASI}"
                sh "aws s3 cp ${ENVANTER_DOSYASI} ${S3_BUCKET_NAME}/${ENVANTER_DOSYASI}"
            }
        }

        stage('5. Jira: Update to Done') {
            steps {
                script {
                    echo "Jira görevi 'Done' (Bitti) olarak güncelleniyor..."
                    
                    if (env.JIRA_ISSUE_KEY) {
                        jiraTransitionIssue(
                            issueKey: env.JIRA_ISSUE_KEY,
                            siteName: env.JIRA_SITE,
                            transitionName: 'Done',
                            comment: "Pipeline başarıyla tamamlandı. Değişiklikler uygulandı. Panel güncellendi.",
                            credentialsId: 'jira-token'
                        )
                    } else {
                        echo "Takip edilecek bir Jira görevi bulunmadığı için bu adım atlanıyor."
                    }
                }
            }
        }
    }
}