# AWS Cloud Security Posture Management and IAM Hardening

A security-focused AWS baseline built entirely with Terraform, with infrastructure-as-code security scanning enforced in CI/CD. The project demonstrates least-privilege IAM, centralized audit logging, hardened S3 configuration, and a pipeline gate that blocks non-compliant changes before they reach `main`.

**Stack:** Terraform, AWS (IAM, S3, KMS, CloudTrail, IAM Access Analyzer), GitHub Actions, Checkov

> Lab project. All resources were deployed to a single AWS account, validated, documented, and then destroyed with `terraform destroy`.

---

## What this project demonstrates

| Area | What was built |
|---|---|
| Least-privilege IAM | An application role scoped to one bucket and one KMS key, a read-only auditor role (`SecurityAudit`), MFA required to assume either role, and a strict account password policy |
| Audit logging | Multi-region CloudTrail with log file validation, KMS encryption, delivering to a dedicated hardened log bucket |
| Secure S3 | Reusable Terraform module: Block Public Access, versioning, KMS encryption with bucket keys, lifecycle rules, TLS-only bucket policy, and bucket-owner-enforced ownership. Plus an account-wide Block Public Access guardrail |
| Encryption | Customer-managed KMS key with automatic rotation and a scoped key policy |
| Detection | IAM Access Analyzer enabled for the account |
| Shift-left security | GitHub Actions runs `terraform fmt`, `validate`, and Checkov on every pull request; branch ruleset blocks merges when checks fail |
| Validation | Deliberately insecure Terraform (`*:*` IAM policy, SSH open to the world) was blocked by the pipeline, then remediated. A public-read ACL was not flagged by Checkov; Block Public Access prevents exposure |

## Architecture

```
                        GitHub (public repo)
                               |
                   Pull request / push to main
                               |
                    GitHub Actions (no AWS creds)
                    |  terraform fmt / validate
                    |  Checkov scan  --> FAIL = merge blocked
                               |
                          merge to main
                               |
              terraform apply (run locally as TF-Admin)
                               |
 +-----------------------------------------------------------+
 |                        AWS account                        |
 |                                                           |
 |   CloudTrail (multi-region, log validation, KMS)          |
 |        |                                                  |
 |        v                                                  |
 |   S3 audit-logs bucket  <-- TLS-only, versioned, KMS      |
 |                                                           |
 |   S3 app-data bucket    <-- TLS-only, versioned, KMS      |
 |        ^                                                  |
 |        | s3 + kms access only                             |
 |   IAM app role (MFA required)                             |
 |   IAM auditor role (SecurityAudit, MFA required)          |
 |                                                           |
 |   KMS CMK (rotation on)   Access Analyzer   Pwd policy    |
 |   Account-level S3 Block Public Access                    |
 +-----------------------------------------------------------+
```

## Repository layout

```
.
├── .github/workflows/security.yml   CI security gate
├── .checkov.yaml                    Scanner config and justified skips
├── providers.tf  variables.tf  main.tf
├── s3.tf  cloudtrail.tf  iam.tf
├── modules/secure_bucket/           Reusable hardened bucket module
└── docs/
    ├── remediation-runbook.md       Risk, detection, fix, verification per finding
    ├── compliance-evidence.md       Control mapping and evidence index
    ├── accepted-risks.md            Every skipped check with justification
    └── screenshots/                 Evidence referenced by the docs
```

## Key design decisions

- **The pipeline never touches AWS.** CI only scans code, so no cloud credentials are stored in GitHub. This removes an entire class of secret-leak and OIDC-misconfiguration risk for a scan-only workflow.
- **Defense in depth on S3.** Block Public Access is set at both the account level and the bucket level, and the bucket policy denies non-TLS requests independently.
- **Guardrails enforced twice.** Misconfigurations such as wildcard IAM policies and open security groups are caught pre-merge by Checkov, and drift is caught post-deploy by `terraform plan`.
- **Risk acceptance is explicit.** Every skipped Checkov check is listed with a reason in [accepted-risks.md](docs/accepted-risks.md).

## Reproduce it

Prerequisites: an AWS account, an IAM user with admin rights and MFA, and Git, AWS CLI, Terraform (>= 1.9) and Python installed.

```powershell
pip install checkov
aws configure                              # region us-east-1
terraform fmt -recursive
terraform init
terraform validate
checkov --config-file .checkov.yaml        # must pass before apply
terraform plan -out tfplan
terraform apply tfplan
```

Teardown:

```powershell
terraform destroy
```

The KMS key enters a 7-day pending-deletion window, which is the AWS minimum.

## Validation results

| Test | Expected | Result | Evidence |
|---|---|---|---|
| Clean baseline passes Checkov | Pass | 109 passed, 0 failed, 0 skipped | `docs/screenshots/05-checkov-pass.JPG` |
| PR with `bad.tf` (public ACL, `*:*` policy, open SSH) | Check fails, merge blocked | Failed, merge blocked. Checkov flagged the `*:*` IAM policy (CKV_AWS_62, 63, 355, plus 286 to 290) and the open SSH security group (CKV_AWS_24). No check fired on the public-read ACL; Block Public Access is the control that prevents public exposure | `docs/screenshots/17-pr-checkov-fail.JPG` |
| `bad.tf` removed | Checks pass, merge allowed | Passed after `bad.tf` was removed; merge allowed | `docs/screenshots/18-pr-checks-green.JPG` |
| Manual console change (drift) | `terraform plan` detects and reverts | Block Public Access disabled in the console. `terraform plan` showed `0 to add, 1 to change, 0 to destroy` on `module.app_data.aws_s3_bucket_public_access_block.this` (four settings false → true); `terraform apply` restored them (`1 changed`) | `docs/screenshots/19-drift-plan.JPG`; `docs/screenshots/20-drift-apply.JPG` |

## Documentation

- [Remediation runbook](docs/remediation-runbook.md)
- [Compliance evidence](docs/compliance-evidence.md)
- [Accepted risks](docs/accepted-risks.md)

## Limitations and production notes

This is a single-account lab. A production version would add:

- Remote Terraform state in S3 with native locking
- A separate log-archive account with Organizations SCPs
- CloudTrail delivery to CloudWatch Logs with metric filters and alarms
- AWS Config, Security Hub and GuardDuty
- S3 access logging and cross-region replication for the log bucket
- GitHub OIDC with a narrowly scoped role if CI ever needs to deploy
- Removal of `force_destroy` on buckets and of the broad `AdministratorAccess` on the deploy user
