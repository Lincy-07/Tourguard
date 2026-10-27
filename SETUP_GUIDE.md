# SETUP GUIDE (step by step, on your laptop)

Assumptions I made, change them if you want: tourist theme = Tamil Nadu destinations; monthly
budget = **$20** (about Rs 1,700, see `policy/data.json`); region = `centralindia`; VM = `Standard_B1s`.
Infracost prices in US dollars.

## 0. How the rubric maps to this project
| Rubric row | Where it is |
|---|---|
| Terraform implementation (modular, variables, outputs, state) | `terraform/` with 2 modules, variables, outputs, remote state, governance tags |
| CI/CD pipeline with Jenkins (build, test, deploy, automation) | `Jenkinsfile`: 10 stages incl. cost estimate + policy gate, Poll SCM trigger |
| Azure deployment (containers) | Docker container on Ubuntu VM, reachable at `http://<public-ip>` |
| Documentation and presentation | Architecture, blocked-build and passed-build screenshots, cost report (Section 9) |
| Online certification (10 marks) | Not part of this repo. Ask your instructor which course. |

## 1. Install tools
Git, Docker Desktop (enable WSL2 on Windows), Terraform, Azure CLI, VS Code.
```
git --version && docker --version && terraform -version && az --version
```

## 2. Azure account and login
Use Azure for Students (free credit). Then:
```
az login
az account show --query "{name:name, id:id, tenant:tenantId}"
```
Write down the subscription `id` and `tenant`.

## 3. SSH key
```
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```
(Jenkins will use the same key to log in to the VM.)

## 4. Infracost key (free)
Install the CLI from https://www.infracost.io/docs/ then:
```
infracost auth login
infracost configure get api_key
```
Copy the key. You will paste it into Jenkins in Step 9.

## 5. Terraform state storage (one time)
Pick a unique lowercase name instead of `tourguardtfstate12345`:
```
az group create -n tourguard-tfstate-rg -l centralindia
az storage account create -n tourguardtfstate12345 -g tourguard-tfstate-rg -l centralindia --sku Standard_LRS
az storage container create --name tfstate --account-name tourguardtfstate12345
```
Put the same name in `environments/backend-dev.hcl`. If `centralindia` is blocked, use another
region everywhere (also `environments/dev.tfvars`).

## 6. Service principal for Jenkins
Jenkins needs its own Azure login:
```
az ad sp create-for-rbac --name tourguard-jenkins --role Contributor --scopes /subscriptions/<SUBSCRIPTION_ID>
```
Save the output: `appId` (client id), `password` (client secret), `tenant`.
Let it read/write Terraform state:
```
az role assignment create --assignee <appId> --role "Storage Blob Data Contributor" \
  --scope $(az storage account show -n tourguardtfstate12345 -g tourguard-tfstate-rg --query id -o tsv)
```
If your college account blocks creating service principals, tell your instructor or use a personal
Microsoft account for Azure.

## 7. Edit two files, then push to GitHub
1. `environments/dev.tfvars`: set `owner` to your name or roll number.
2. `environments/backend-dev.hcl`: set your storage account name.

```
git init && git add . && git commit -m "TourGuard initial commit"
git branch -M main
git remote add origin https://github.com/<you>/tourguard.git
git push -u origin main
```

## 8. Run Jenkins on your laptop
```
docker build -t jenkins-tourguard ./jenkins
docker run -d --name jenkins -p 8080:8080 -p 50000:50000 -v jenkins_home:/var/jenkins_home jenkins-tourguard
docker logs jenkins
```
Open http://localhost:8080, use the initial admin password from the logs, install suggested
plugins, create your user. The first image build takes a few minutes (it downloads Terraform,
Infracost and Conftest).

## 9. Add credentials in Jenkins
Manage Jenkins, Credentials, System, Global, Add Credentials:

| ID (exact) | Kind | Value |
|---|---|---|
| `azure-vm-ssh` | SSH Username with private key | username `azureuser`, paste contents of `~/.ssh/id_rsa` |
| `azure-client-id` | Secret text | service principal `appId` |
| `azure-client-secret` | Secret text | service principal `password` |
| `azure-tenant-id` | Secret text | tenant id |
| `azure-subscription-id` | Secret text | subscription id |
| `infracost-api-key` | Secret text | key from Step 4 |

## 10. Create the pipeline job
New Item, name `tourguard`, type Pipeline. Pipeline script from SCM, Git, your repo URL, branch
`*/main`, script path `Jenkinsfile`. (Private repo: add a GitHub token credential.) Save,
then **Build Now**.

The first successful run takes about 10 minutes (VM creation plus Docker install). Open
`http://<vm_public_ip>` (printed at the end of the log) and you will see the tourist site.
Screenshots: Terraform plan/apply output, the Infracost table, the green stage view, the live site.

## 11. Automatic triggering
Poll SCM (every 2 minutes) is already in the Jenkinsfile and satisfies the rubric. For instant
builds: run `ngrok http 8080`, add a GitHub webhook to `https://<ngrok-url>/github-webhook/`
(content type `application/json`), and tick "GitHub hook trigger for GITScm polling" in the job.

## 12. THE DEMO (this is what earns top marks)
**Demo A: the gate blocks an expensive change.**
1. In `environments/dev.tfvars` change `vm_size = "Standard_B1s"` to `"Standard_D8s_v5"`.
2. `git commit -am "Try a big VM" && git push`.
3. Jenkins starts by itself. It stops at **FinOps: policy gate** with lines like
   `FAIL ... SIZE: ... Standard_D8s_v5 ... not in the approved list` and
   `FAIL ... COST: estimated monthly cost $... exceeds the budget of $20`.
4. Screenshot the red stage and the console. Nothing was created in Azure.

**Demo B: the gate blocks missing tags.**
1. Set `vm_size` back to `Standard_B1s`. Delete the `cost_center` line from `tags`.
2. Push. The build fails with `TAGS: ... is missing required tag(s): cost_center`.

**Demo C: fix it and it deploys.**
Restore both lines, push, and watch the build go green and redeploy. Change a heading in
`app/templates/index.html` and push again to show continuous deployment. The footer on the page shows
`build-<n> / <git commit>` so you can prove which version is live.

## 13. Report checklist (PDF)
Title and objective, problem statement (README), tools used, architecture diagram (README),
Terraform snippets (`main.tf`, a module, `variables.tf`), `Jenkinsfile`, Rego policies, screenshots
(terraform apply, Infracost table, blocked build, passed build, live site, Azure resource group),
observations (cost before and after, what the gate caught), conclusion and reflection, GitHub link.

## 14. Clean up
```
cd terraform
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"
terraform init -backend-config=../environments/backend-dev.hcl
terraform destroy -var-file=../environments/dev.tfvars
```
(Also delete the `tourguard-tfstate-rg` group when you are fully done.)

## Troubleshooting
- **`infracost` says no pricing found or auth error:** check the `infracost-api-key` credential.
- **Terraform "AuthorizationPermissionMismatch" on state:** the Step 6 role assignment can take a few minutes to apply.
- **VM size or region unavailable:** change `location` and `vm_size` (keep the size in the policy allow-list, or add it to `policy/data.json`).
- **SSH fails in the deploy stage:** wait; cloud-init is still installing Docker. The script retries for 10 minutes.
- **Policy warning about SSH open to the internet:** expected. Set `allowed_ssh_cidr` to `<your public IP>/32` in `dev.tfvars` to clear it (home IPs change, so re-check if SSH stops working).
- **Test the policies alone, no Azure needed:** install Conftest and run `./scripts/test-policies.sh`.
- **Not verified in my environment:** I could run the app tests and the OPA policies, but not Terraform, Jenkins or Azure. Read errors from the first `terraform plan` carefully, they are usually a typo in a name or region.
