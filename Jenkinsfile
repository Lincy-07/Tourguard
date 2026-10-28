
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    triggers {
        pollSCM('H/2 * * * *')
    }

    environment {
        TF_IN_AUTOMATION    = 'true'
        TF_CLI_ARGS         = '-no-color'
        ARM_CLIENT_ID       = credentials('azure-client-id')
        ARM_CLIENT_SECRET   = credentials('azure-client-secret')
        ARM_TENANT_ID       = credentials('azure-tenant-id')
        ARM_SUBSCRIPTION_ID = credentials('azure-subscription-id')
        INFRACOST_API_KEY   = credentials('infracost-api-key')
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
                always {
                    junit allowEmptyResults: true,
                          testResults: 'app/test-results.xml'
                }
            }
        }

        stage('Policy unit tests') {
            steps {
                sh 'bash ./scripts/test-policies.sh'
            }
        }

        stage('Terraform: init and validate') {
            steps {
                sh '''
                    terraform -chdir=terraform init -input=false \
                        -backend-config=../environments/backend-dev.hcl
                    terraform -chdir=terraform fmt -check -recursive
                    TF_VAR_ssh_public_key="dummy" \
                        terraform -chdir=terraform validate
                '''
            }
        }

        stage('Terraform: plan') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'azure-vm-ssh',
                        keyFileVariable: 'KEY'
                    )
                ]) {
                    sh '''
                        set -eu
                        export TF_VAR_ssh_public_key="$(ssh-keygen -y -f "$KEY")"
                        terraform -chdir=terraform plan \
                            -input=false \
                            -var-file=../environments/dev.tfvars \
                            -out=tfplan
                        terraform -chdir=terraform show -no-color tfplan > tfplan.txt
                        terraform -chdir=terraform show -json tfplan > tfplan.json
                    '''
                }
            }
        }

        stage('FinOps: cost estimate (Infracost)') {
            steps {
                sh '''
                    infracost breakdown --path tfplan.json \
                        --format json --out-file infracost.json --no-color
                    infracost output --path infracost.json \
                        --format table --no-color
                    infracost output --path infracost.json \
                        --format html --out-file infracost.html
                '''
            }
        }

        stage('FinOps: policy gate (OPA / Conftest)') {
            steps {
                sh '''
                    conftest test --no-color \
                        --policy policy/cost --data policy/data.json infracost.json
                    conftest test --no-color \
                        --policy policy/plan --data policy/data.json tfplan.json
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
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'azure-vm-ssh',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        set -eu
                        export VM_IP="$(terraform -chdir=terraform output -raw vm_public_ip)"
                        export APP_VERSION="build-${BUILD_NUMBER}"
                        export GIT_SHA="$(git rev-parse --short HEAD)"

                        echo "Checking SSH private key format..."
                        ssh-keygen -y -f "$SSH_KEY" >/dev/null
                        echo "Private key format is valid."

                        echo "Checking SSH connection and remote readiness..."
                        ssh -i "$SSH_KEY" \
                            -o BatchMode=yes \
                            -o IdentitiesOnly=yes \
                            -o StrictHostKeyChecking=no \
                            -o UserKnownHostsFile=/dev/null \
                            -o ConnectTimeout=15 \
                            -o LogLevel=ERROR \
                            "$SSH_USER@$VM_IP" \
                            'whoami && test -f /opt/tourguide/.cloud-init-done && docker --version'

                        echo "SSH and remote readiness check passed."
                        echo "$VM_IP" > vm_ip.txt
                        bash ./scripts/deploy.sh
                    '''
                }
            }
        }

        stage('Smoke test') {
            steps {
                sh '''
                    set -eu
                    VM_IP="$(cat vm_ip.txt)"
                    for i in $(seq 1 12); do
                        if curl -fsS "http://$VM_IP/health"; then
                            echo
                            echo "App is healthy"
                            exit 0
                        fi
                        echo "Waiting for app... ($i/12)"
                        sleep 5
                    done
                    echo "Smoke test failed" >&2
                    exit 1
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'tfplan.txt, infracost.json, infracost.html',
                             allowEmptyArchive: true
        }
        success {
            sh 'echo "Deployed. Open http://$(cat vm_ip.txt)"'
        }
        failure {
            echo 'Pipeline failed. Check the first failing stage and its Console Output.'
        }
    }
}
