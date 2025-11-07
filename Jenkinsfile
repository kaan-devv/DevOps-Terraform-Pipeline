// Pipeline'ı (Patronu) tanımla
pipeline {
    // 1. Ajan Ayarı: Bu pipeline'ın komutları nerede çalışacak?
    // "any", Jenkins'in bu işi kendi ana makinesi (Controller) üzerinde
    // çalıştırması gerektiğini söyler.
    agent any

    // 2. Ortam Değişkenleri: Bu pipeline'ın ihtiyaç duyduğu anahtarlar.
    environment {
        // Jenkins'e 'aws-creds' ID'si ile kaydettiğimiz AWS anahtarlarını yüklüyoruz.
        AWS_CREDS = credentials('aws-creds')
        
        // AWS CLI'ın varsayılan bölgesini ayarlıyoruz (Virginia).
        AWS_DEFAULT_REGION = 'us-east-1'

        // Bu, pipeline'ın S3'e yazacağı yerel dosyanın adıdır.
        ENVANTER_DOSYASI = 'inventory.json'
        
        // Bu, main.tf'teki S3 kova adınızla AYNI OLMALI.
        // *** KEY POINT: main.tf'te değiştirdiğiniz S3 kova adını buraya da yazın.
        S3_BUCKET_NAME = 's3://kaan-inventory-bucket-xyz' // <-- GEREKİRSE DEĞİŞTİRİN
        
        // *** KEY POINT: 'JIRA-SITENIZ' kısmını kendi Jira sitenizle değiştirin (örn: isminiz.atlassian.net)
        JIRA_SITE = 'https://JIRA-SITENIZ.atlassian.net' // <-- BUNU DEĞİŞTİRİN
        
        // Jira görev kodunu pipeline boyunca saklamak için boş bir değişken
        JIRA_ISSUE_KEY = ""
    }

    // 3. Aşama (Stage) Tanımları: Jenkins'te göreceğiniz 5 SÜTUN.
    stages {
        
        // --- AŞAMA 1: Kodu Al (Checkout) ---
        stage('1. Kodu Al (Checkout)') {
            steps {
                echo "GitHub'dan en güncel kod alınıyor..."
                // 'checkout scm', Jenkins'in proje ayarlarında tanımlı olan
                // GitHub reposundan kodu (main.tf, Jenkinsfile) çekmesini sağlar.
                checkout scm
            }
        }

        // --- AŞAMA 2: Jira Güncelle ('In Progress') ---
        stage('2. Jira: Update to In Progress') {
            steps {
                script {
                    echo "Jira görevi 'In Progress' (Yapılıyor) olarak güncelleniyor..."
                    
                    // Git commit mesajından Jira görev kodunu (örn: [JIRA-101]) çıkarmaya çalışır.
                    def matcher = (env.CHANGE_MESSAGE ?: "").find("\\[([A-Z]+-\\d+)\\]")
                    
                    if (matcher) {
                        // Eğer kodu bulursa, bunu sonraki aşamalarda (Adım 5) kullanmak üzere
                        // environment değişkenine kaydeder.
                        env.JIRA_ISSUE_KEY = matcher[1]
                        
                        // Jenkins'e (Aşama 4'te) kaydettiğimiz 'jira-token' kimliğini kullanarak
                        // 'In Progress' yorumuyla birlikte görevi günceller.
                        jiraTransitionIssue(
                            issueKey: env.JIRA_ISSUE_KEY,
                            siteName: env.JIRA_SITE,
                            transitionName: 'In Progress', // Jira panelinizdeki geçişin adıyla aynı olmalı
                            comment: "Pipeline başladı. Terraform apply çalıştırılıyor...",
                            credentialsId: 'jira-token'
                        )
                    } else {
                        echo "Commit mesajında Jira görev kodu (örn: [JIRA-101]) bulunamadı, Jira adımı atlanıyor."
                    }
                }
            }
        }

        // --- AŞAMA 3: Terraform Uygula (Altyapıyı Oluştur/Güncelle/Sil) ---
        stage('3. Terraform: Apply') {
            steps {
                // Bu adım, 'main.tf' dosyasının olduğu klasörde çalışır.
                
                // 1. Terraform'u başlatır (Gerekli eklentileri indirir)
                sh 'terraform init -input=false'
                
                // 2. Değişiklikleri otomatik onaylayarak uygular.
                // (EC2'yi oluşturur / t2->t3 yapar / EC2'yi siler)
                sh 'terraform apply -auto-approve -input=false'
            }
        }

        // --- AŞAMA 4: Envanteri Kaydet (S3 "Altın Yol" Mantığı) ---
        stage('4. Envanteri Kaydet (S3)') {
            steps {
                echo "En güncel envanter listesi oluşturuluyor..."
                
                // 1. 'terraform output -json' komutuyla o anki "gerçek durumu" JSON olarak dosyaya yaz.
                sh "terraform output -json > ${ENVANTER_DOSYASI}"
                
                echo "Envanter listesi S3'e yükleniyor: ${S3_BUCKET_NAME}/${ENVANTER_DOSYASI}"
                
                // 2. 'aws s3 cp' komutuyla o JSON dosyasını S3'teki eskisinin üzerine yaz.
                sh "aws s3 cp ${ENVANTER_DOSYASI} ${S3_BUCKET_NAME}/${ENVANTER_DOSYASI}"
            }
        }

        // --- AŞAMA 5: Jira Güncelle ('Done') ---
        stage('5. Jira: Update to Done') {
            steps {
                script {
                    echo "Jira görevi 'Done' (Bitti) olarak güncelleniyor..."
                    
                    // 2. Aşamada kaydettiğimiz Jira görev kodu hala var mı diye bakarız
                    if (env.JIRA_ISSUE_KEY) {
                        // Görevi son duruma geçir.
                        jiraTransitionIssue(
                            issueKey: env.JIRA_ISSUE_KEY,
                            siteName: env.JIRA_SITE,
                            transitionName: 'Done', // veya 'Tamamlandı' (Jira panelinizde ne yazıyorsa)
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