# TourGuard: Cost-Governed Deployment of a Tourist Guide App

**Problem.** Infrastructure as Code makes it easy to create cloud resources, and just as easy to
create an expensive or untagged mess. Most teams only notice on the monthly bill.

**Solution.** A Jenkins pipeline that estimates the cost of every Terraform change with
**Infracost** and enforces budget, tagging and VM-size rules with **Open Policy Agent (Conftest)**
*before* anything is created in Azure. If a rule is broken, the build stops. If everything passes,
Terraform builds the infrastructure and the app is deployed and smoke-tested automatically.

The workload being deployed is **TN Tourist Guide**, a small Flask web app (Docker) that helps
travellers filter Tamil Nadu destinations by type, season and budget.

```
 git push --> GitHub --> Jenkins (laptop, Docker)
                           1. lint + unit tests (app)
                           2. policy unit tests
                           3. terraform init / validate / plan
                           4. Infracost: monthly cost estimate
                           5. OPA gate: budget? tags? approved VM size?   <-- blocks here
                           6. terraform apply  (Azure: RG, VNet, Subnet, NSG, Public IP, NIC, VM)
                           7. deploy container to VM  8. smoke test
 Terraform state: Azure Storage (remote backend)
```

## Layout
| Path | What it is |
|---|---|
| `app/` | Flask tourist guide, tests, Dockerfile, docker-compose |
| `terraform/` | Root module, `modules/network`, `modules/compute`, remote state backend |
| `environments/` | `dev.tfvars` (vm size, tags) and `backend-dev.hcl` (state location) |
| `policy/` | Rego rules (`cost/`, `plan/`) and `data.json` (budget, allowed sizes, required tags) |
| `scripts/` | `deploy.sh`, `test-policies.sh` |
| `jenkins/Dockerfile` | Jenkins with Terraform, Infracost, Conftest, Python, rsync |
| `Jenkinsfile` | The pipeline |
| `.github/workflows/` | Optional bonus: cost comment on pull requests |

Read **SETUP_GUIDE.md** for the full step-by-step setup and the demo script.
