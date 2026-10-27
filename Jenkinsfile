// TourGuard pipeline: build -> test -> terraform plan -> COST ESTIMATE -> POLICY GATE -> apply -> deploy -> smoke test
//
// Jenkins credentials needed (Manage Jenkins -> Credentials):
//   azure-vm-ssh           SSH Username with private key (username: azureuser)
//   azure-client-id        Secret text   (service principal appId)
//   azure-client-secret    Secret text   (service principal password)
//   azure-tenant-id        Secret text
//   azure-subscription-id  Secret text
//   infracost-api-key      Secret text   (free key from `infracost auth login`)
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    triggers {
        // Fallback trigger. A GitHub webhook (via ngrok) makes it instant.
        pollSCM('H/2 * * * *')
    }

    environment {
        TF_IN_AUTOMATION      = 'true'
        TF_CLI_ARGS           = '-no-color'
        ARM_CLIENT_ID         = credentials('azure-client-id')
        ARM_CLIENT_SECRET     = credentials('azure-client-secret')
        ARM_TENANT_ID         = credentials('azure-tenant-id')
        ARM_SUBSCRIPTION_ID   = credentials('azure-subscription-id')
        INFRACOST_API_KEY     = credentials('infracost-api-key')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log -1 --pretty="Commit: %h %s (%an)"'
            }
        }

        stage('App: lint and test') {
            steps {
                dir('app') {
                    sh '''
                        python3 -m venv .venv
                        . .venv/bin/activate
                        pip install --quiet -r requirements.txt -r requirements-dev.txt
                        flake8 app.py tests --max-line-length=100
                        pytest -q --junitxml=test-results.xml
                    '''
                }
            }
            post {
                always { junit allowEmptyResults: true, testResults: 'app/test-results.xml' }
            }
        }

        stage('Policy unit tests') {
            steps {
                // Proves the guardrails themselves work (good input passes, bad input is blocked).
                sh 'bash./scripts/test-policies.sh'
            }
        }

        stage('Terraform: init and validate') {
            steps {
                sh '''
                    terraform -chdir=terraform init -input=false -backend-config=../environments/backend-dev.hcl
                    terraform -chdir=terraform fmt -check -recursive
                    TF_VAR_ssh_public_key="dummy" terraform -chdir=terraform validate
                '''
            }
        }

        stage('Terraform: plan') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'azure-vm-ssh', keyFileVariable: 'KEY')]) {
                    sh '''
                        export TF_VAR_ssh_public_key="$(ssh-keygen -y -f "$KEY")"
                        terraform -chdir=terraform plan -input=false -var-file=../environments/dev.tfvars -out=tfplan
                        terraform -chdir=terraform show -no-color tfplan > tfplan.txt
                        terraform -chdir=terraform show -json tfplan > tfplan.json
                    '''
                }
            }
        }

        stage('FinOps: cost estimate (Infracost)') {
            steps {
                sh '''
                    infracost breakdown --path tfplan.json --format json --out-file infracost.json --no-color
                    infracost output --path infracost.json --format table --no-color
                    infracost output --path infracost.json --format html --out-file infracost.html
                '''
            }
        }

        stage('FinOps: policy gate (OPA / Conftest)') {
            steps {
                // Any "deny" rule fails the build here, BEFORE anything is created in Azure.
                sh '''
                    conftest test --no-color --policy policy/cost --data policy/data.json infracost.json
                    conftest test --no-color --policy policy/plan --data policy/data.json tfplan.json
                '''
            }
        }

        stage('Terraform: apply') {
            steps {
                sh 'terraform -chdir=terraform apply -input=false tfplan'
            }
        }

        stage('Deploy app to Azure VM') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'azure-vm-ssh',
                                                   keyFileVariable: 'SSH_KEY',
                                                   usernameVariable: 'SSH_USER')]) {
                    sh '''
                        export VM_IP="$(terraform -chdir=terraform output -raw vm_public_ip)"
                        export APP_VERSION="build-${BUILD_NUMBER}"
                        export GIT_SHA="$(git rev-parse --short HEAD)"
                        echo "$VM_IP" > vm_ip.txt
                        bash./scripts/deploy.sh
                    '''
                }
            }
        }

        stage('Smoke test') {
            steps {
                sh '''
                    VM_IP="$(cat vm_ip.txt)"
                    for i in $(seq 1 12); do
                      if curl -fsS "http://$VM_IP/health"; then echo; echo "App is healthy"; exit 0; fi
                      echo "waiting for app... ($i)"; sleep 5
                    done
                    echo "Smoke test failed"; exit 1
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'tfplan.txt, infracost.json, infracost.html', allowEmptyArchive: true
        }
        success { sh 'echo "Deployed. Open http://$(cat vm_ip.txt)"' }
        failure { echo 'Pipeline stopped. If it failed at a FinOps stage, read the FAIL lines: that is the guardrail working.' }
    }
}
