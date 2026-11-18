# Compliance Evidence

Maps each implemented control to the Terraform that enforces it, the Checkov check that verifies it, the framework requirement it supports, and the screenshot that proves it.

## How to read this document

- **CIS** references are to the *CIS Amazon Web Services Foundations Benchmark*. Section numbers differ between benchmark versions. The numbers below follow v3.0, so confirm them against the version you cite before publishing.
- **NIST** references are to *NIST SP 800-53 Rev. 5* control families.
- **Checkov IDs** are the ones Checkov usually emits for these resources. Checkov renumbers and adds checks over time, so confirm each ID against your own scan output and correct any that differ.
- **Evidence** filenames refer to files in `docs/screenshots/`.

---

## Control mapping

### Identity and access management

| Control | Terraform | Checkov | CIS | NIST 800-53 | Evidence |
|---|---|---|---|---|---|
| Strict password policy (14+ chars, complexity, reuse prevention, 90-day expiry) | `iam.tf`: `aws_iam_account_password_policy.strict` | CKV_AWS_9 to CKV_AWS_15 | 1.8, 1.9 | IA-5 | `05-checkov-pass.JPG`; `24-password-policy.JPG` |
| Least-privilege application role scoped to one bucket and one key | `iam.tf`: `app_access` policy, `aws_iam_role.app` | CKV_AWS_355, CKV_AWS_62, CKV_AWS_63 | 1.16 | AC-6 | `05-checkov-pass.JPG`; `25-app-role-policy.JPG` |
| Read-only auditor role using managed `SecurityAudit` | `iam.tf`: `aws_iam_role.auditor` | n/a | 1.16 | AC-6, AU-6 | `26-auditor-role.JPG` |
| MFA required to assume roles | `iam.tf`: `assume_with_mfa` trust policy | n/a (behavioral test) | 1.10 (principle) | IA-2(1) | `11-iam-trust-mfa.JPG`; `21-assume-role-denied.JPG` |
| Short role session duration (1 hour) | `iam.tf`: `max_session_duration = 3600` | n/a | n/a | AC-12 | `25-app-role-policy.JPG` (role summary shows Maximum session duration: 1 hour) |
| Access Analyzer enabled | `cloudtrail.tf`: `aws_accessanalyzer_analyzer.main` | n/a | 1.20 | CA-7, RA-5 | `13-access-analyzer.JPG` |
| Root MFA, billing budgets, admin IAM user with MFA (manual) | Console | n/a | 1.5 | IA-2(1) | `01-root-mfa-enabled.JPG`; `02-budgets.JPG`; `03-iam-user-mfa.JPG` |

### Audit logging

| Control | Terraform | Checkov | CIS | NIST 800-53 | Evidence |
|---|---|---|---|---|---|
| CloudTrail enabled in all regions, including global events | `cloudtrail.tf`: `is_multi_region_trail`, `include_global_service_events` | CKV_AWS_67 | 3.1 | AU-2, AU-12 | `07-cloudtrail-settings.JPG` |
| Log file integrity validation | `cloudtrail.tf`: `enable_log_file_validation` | CKV_AWS_36 | 3.2 | AU-9(3), SI-7 | `07-cloudtrail-settings.JPG` |
| CloudTrail logs encrypted with a CMK | `cloudtrail.tf`: `kms_key_id` | CKV_AWS_35 | 3.5 | SC-28, AU-9 | `07-cloudtrail-settings.JPG`; `12-kms-rotation.JPG` |
| Log bucket not public | `s3.tf`: `audit_logs` module | CKV_AWS_53 to CKV_AWS_56 | 3.3 | AC-3, AU-9 | `08-s3-block-public-access.JPG` |
| Log bucket restricts writers to the CloudTrail service for this trail only | `s3.tf`: `cloudtrail_write` policy with `aws:SourceArn` | n/a | 3.3 | AU-9, AC-3 | `10-s3-tls-policy.JPG` (bucket policy showing the `aws:SourceArn` condition) |
| Log delivery observed in bucket | Console | n/a | n/a | AU-3 | `14-cloudtrail-logs-in-bucket.JPG` |

### Data protection (S3 and KMS)

| Control | Terraform | Checkov | CIS | NIST 800-53 | Evidence |
|---|---|---|---|---|---|
| Block Public Access at bucket level | `modules/secure_bucket`: `aws_s3_bucket_public_access_block` | CKV_AWS_53 to CKV_AWS_56, CKV2_AWS_6 | 2.1.4 | AC-3, AC-4 | `08-s3-block-public-access.JPG`; `19-drift-plan.JPG`; `20-drift-apply.JPG` |
| Block Public Access at account level | `s3.tf`: `aws_s3_account_public_access_block` | n/a | 2.1.4 | AC-3, AC-4 | `27-account-block-public-access.JPG` |
| ACLs disabled (BucketOwnerEnforced) | `modules/secure_bucket`: ownership controls | n/a | n/a | AC-3 | `28-object-ownership.JPG` |
| TLS-only access enforced by bucket policy | `modules/secure_bucket`: `DenyInsecureTransport` | n/a (no Checkov check; verified by bucket policy screenshot) | 2.1.1 | SC-8 | `10-s3-tls-policy.JPG` |
| SSE-KMS encryption at rest with bucket keys | `modules/secure_bucket`: SSE configuration | CKV_AWS_19, CKV_AWS_145 | 2.1.1 | SC-28, SC-12 | `09-s3-encryption-versioning.JPG` |
| Versioning enabled | `modules/secure_bucket`: `aws_s3_bucket_versioning` | CKV_AWS_21 | n/a | CP-9, SI-12 | `09-s3-encryption-versioning.JPG` |
| Lifecycle rules (expiry, multipart cleanup) | `modules/secure_bucket`: lifecycle configuration | CKV2_AWS_61, CKV_AWS_300 | n/a | SI-12 | `29-lifecycle-rules.JPG` |
| KMS automatic key rotation | `main.tf`: `enable_key_rotation = true` | CKV_AWS_7 | 3.6 | SC-12 | `12-kms-rotation.JPG` |
| Scoped KMS key policy (CloudTrail restricted by source ARN) | `main.tf`: `data.aws_iam_policy_document.kms` | CKV_AWS_109, CKV_AWS_111, CKV_AWS_356 (inline skips, see Accepted risks) | n/a | SC-12, AC-6 | `30-kms-key-policy.JPG` |

### Change management and continuous compliance

| Control | Implementation | Tool | NIST 800-53 | Evidence |
|---|---|---|---|---|
| Infrastructure defined as code and version controlled | Git repository | Terraform, GitHub | CM-2, CM-3 | `06-terraform-apply.JPG`; `15-actions-green.JPG` |
| Automated security scanning on every pull request | `.github/workflows/security.yml` | Checkov | CM-4, SA-11, RA-5 | `15-actions-green.JPG`; `17-pr-checkov-fail.JPG`; `18-pr-checks-green.JPG` |
| Formatting and validation gate | Same workflow | `terraform fmt`, `validate` | CM-3 | `15-actions-green.JPG` (shows the fmt and validate steps passing) |
| Non-compliant changes cannot merge | Branch ruleset with required checks | GitHub rulesets | CM-3, CM-5 | `16-branch-ruleset.JPG`; `17-pr-checkov-fail.JPG` (merge blocked) |
| CI holds no cloud credentials | Scan-only workflow, `permissions: contents: read` | GitHub Actions | AC-6, IA-5 | `32-workflow-permissions.JPG` |
| Drift detection | `terraform plan` shows divergence | Terraform | CM-6, CM-3 | `19-drift-plan.JPG`; `20-drift-apply.JPG` |
| Documented risk acceptance | `accepted-risks.md` | Checkov skip list | RA-3, CA-5 | n/a |

---

## Validation test results

| # | Test | Method | Expected | Actual | Evidence |
|---|---|---|---|---|---|
| T1 | Baseline passes scan | `checkov --config-file .checkov.yaml` | 0 failed checks | 109 passed, 0 failed, 0 skipped | `05-checkov-pass.JPG` |
| T2 | Public-read bucket blocked | PR with `bad.tf` | Check fails, merge blocked | Partial: PR blocked by Checkov, but no check fired on the public-read ACL (lines 5-8); block came from the IAM and SSH findings | Partial (`17-pr-checkov-fail.JPG`) |
| T3 | `*:*` IAM policy blocked | Same PR | Check fails | Failed: CKV_AWS_62, 63, 355 flagged (also 286 to 290); merge blocked | Pass (`17-pr-checkov-fail.JPG`) |
| T4 | Open SSH security group blocked | Same PR | Check fails | Failed: CKV_AWS_24 flagged on `bad.tf`; merge blocked | Pass (`17-pr-checkov-fail.JPG`) |
| T5 | Fix restores green status | Remove `bad.tf`, push | Checks pass, merge allowed | `checkov` passed after `bad.tf` was removed, 0 failed checks, merge button enabled | Pass (`18-pr-checks-green.JPG`) |
| T6 | Drift detected and corrected | Disable bucket Block Public Access in console, then `terraform plan` and `apply` | Plan shows revert, apply restores | `terraform plan` detected the drift: `Plan: 0 to add, 1 to change, 0 to destroy` on `module.app_data.aws_s3_bucket_public_access_block.this` (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets` all false → true). `terraform apply` completed: `Apply complete! Resources: 0 added, 1 changed, 0 destroyed` | Pass (`19-drift-plan.JPG`, `20-drift-apply.JPG`) |
| T7 | Role refuses assumption without MFA | `aws sts assume-role` with no token | AccessDenied | `AccessDenied`: `TF-Admin` is not authorized to perform `sts:AssumeRole` on `role/mfa-test-role` when no MFA token is supplied. As a control, the same call with `--serial-number` and a valid `--token-code` succeeded and returned temporary credentials. The temporary role has the same MFA trust condition as the project roles | Pass (`21-assume-role-denied.JPG`) |

---

## Screenshot index

Store these in `docs/screenshots/` using sequential names.

| File | What it shows |
|---|---|
| `01-root-mfa-enabled.JPG` | Root account MFA enabled (blur account ID) |
| `02-budgets.JPG` | Zero-spend and monthly budgets |
| `03-iam-user-mfa.JPG` | `TF-Admin` user with MFA |
| `04-sts-identity.JPG` | `aws sts get-caller-identity` output |
| `05-checkov-pass.JPG` | Local Checkov passing |
| `06-terraform-apply.JPG` | Apply complete |
| `07-cloudtrail-settings.JPG` | Multi-region, validation, KMS |
| `08-s3-block-public-access.JPG` | App-data bucket Block Public Access (all four settings on) |
| `09-s3-encryption-versioning.JPG` | Bucket Properties tab |
| `10-s3-tls-policy.JPG` | Bucket policy with TLS deny |
| `11-iam-trust-mfa.JPG` | Role trust policy with MFA condition |
| `12-kms-rotation.JPG` | KMS key with rotation enabled |
| `13-access-analyzer.JPG` | Analyzer active |
| `14-cloudtrail-logs-in-bucket.JPG` | Log files delivered |
| `15-actions-green.JPG` | Passing workflow run |
| `16-branch-ruleset.JPG` | Ruleset with required checks |
| `17-pr-checkov-fail.JPG` | Failed check, merge blocked |
| `18-pr-checks-green.JPG` | After remediation |
| `19-drift-plan.JPG` | Plan showing drift |
| `20-drift-apply.JPG` | Apply restoring state |
| `21-assume-role-denied.JPG` | AccessDenied without MFA |
| `22-destroy-complete.JPG` | Destroy complete |
| `23-billing-after.JPG` | Billing page after teardown |
| `24-password-policy.JPG` | Account password policy settings |
| `25-app-role-policy.JPG` | Application role: scoped permissions policy and 1-hour maximum session duration |
| `26-auditor-role.JPG` | Auditor role with only the `SecurityAudit` policy attached |
| `27-account-block-public-access.JPG` | Account-level S3 Block Public Access (all four settings on) |
| `28-object-ownership.JPG` | App-data bucket Object Ownership: ACLs disabled (bucket owner enforced) |
| `29-lifecycle-rules.JPG` | App-data bucket lifecycle rules |
| `30-kms-key-policy.JPG` | KMS key policy with the account-root and CloudTrail statements |
| `31-auditlogs-block-public-access.JPG` | Block Public Access on the audit-logs bucket |
| `32-workflow-permissions.JPG` | GitHub workflow with `permissions: contents: read` and no cloud credentials |
