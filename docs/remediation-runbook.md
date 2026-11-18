# Remediation Runbook

Procedures for each class of misconfiguration this project detects. Every entry follows the same structure: **risk, how it is detected, how to fix it, and how to verify the fix.**

Replace `<bucket>`, `<account-id>` and similar placeholders with your real values when running commands.

---

## Summary

| # | Finding | Severity | Detected by | Evidence |
|---|---|---|---|---|
| R1 | S3 bucket with public-read ACL | High | Present in `bad.tf`; not flagged by Checkov in the PR run. Public exposure is prevented by Block Public Access (account and bucket level) | `17-pr-checkov-fail.JPG`; `08-s3-block-public-access.JPG`; `27-account-block-public-access.JPG` |
| R2 | IAM policy allowing `*:*` | Critical | Checkov (pre-merge): CKV_AWS_62, 63, 286, 287, 288, 289, 290, 355 | `17-pr-checkov-fail.JPG` |
| R3 | Security group open to the world on SSH | High | Checkov (pre-merge): CKV_AWS_24 | `17-pr-checkov-fail.JPG` |
| R4 | Role assumable without MFA | High | Code review, behavioral test (`AccessDenied` without MFA) | `11-iam-trust-mfa.JPG`; `21-assume-role-denied.JPG` |
| R5 | Console drift: Block Public Access disabled | High | `terraform plan` (post-deploy) | `19-drift-plan.JPG`; `20-drift-apply.JPG` |
| R6 | S3 access over plain HTTP | Medium | Bucket policy review (no Checkov check) | `10-s3-tls-policy.JPG` |

---

## R1. S3 bucket with public-read ACL

**Risk.** Anyone on the internet can list or read objects. Public buckets are a leading cause of cloud data breaches.

**Detection.** In this project the public-read ACL (`aws_s3_bucket_acl` set to `public-read`) was present in `bad.tf`, but Checkov did not flag it in the PR run. The PR was blocked by the IAM and SSH findings (R2 and R3). The control that actually prevents public exposure is Block Public Access at account and bucket level. Terraform itself would not complain about the ACL.

**Fix.**
1. Remove the ACL resource and use the `secure_bucket` module, which sets `BucketOwnerEnforced` ownership (ACLs disabled) and all four Block Public Access settings.
2. The account-level `aws_s3_account_public_access_block` is a second layer, so even a hand-created bucket cannot be made public.

**Verify.**
```powershell
aws s3api get-public-access-block --bucket <bucket>
aws s3api get-bucket-ownership-controls --bucket <bucket>
```
Expect all four values `true` and `BucketOwnerEnforced`.

**Known gap.** Checkov 3.4.3 did not report a finding for a public-read ACL on `aws_s3_bucket_acl`. Do not rely on the scanner alone for this class of issue; keep Block Public Access enabled.

---

## R2. IAM policy allowing `Action: *` on `Resource: *`

**Risk.** Full administrative access to the account. A single leaked credential or compromised workload becomes total compromise.

**Detection.** Checkov flagged the wildcard policy in the PR: `CKV_AWS_62`, `CKV_AWS_63`, `CKV_AWS_286`, `CKV_AWS_287`, `CKV_AWS_288`, `CKV_AWS_289`, `CKV_AWS_290` and `CKV_AWS_355`. The PR merge was blocked.

**Fix.** Replace it with a scoped policy. The reference implementation is `data.aws_iam_policy_document.app_access` in `iam.tf`: two S3 object actions on one bucket's objects, `s3:ListBucket` on the bucket, and two KMS actions on one key.

**Verify.**
- Checkov passes.
- Run IAM Access Analyzer or the policy simulator against the role to confirm that unrelated actions (for example `ec2:RunInstances`) are denied:
```powershell
aws iam simulate-principal-policy --policy-source-arn <role-arn> --action-names ec2:RunInstances s3:GetObject
```

---

## R3. Security group allowing SSH from `0.0.0.0/0`

**Risk.** Exposes port 22 to automated scanning and brute force from the entire internet.

**Detection.** Checkov flagged `CKV_AWS_24` ("Ensure no security groups allow ingress from 0.0.0.0:0 to port 22") in the PR and the merge was blocked.

**Fix.** Remove the rule, or restrict `cidr_blocks` to a known admin address. Prefer AWS Systems Manager Session Manager, which needs no inbound port at all.

**Verify.** Checkov passes. In a real deployment, confirm with `aws ec2 describe-security-groups` that no rule lists `0.0.0.0/0` on port 22.

> In this project the security group existed only in `bad.tf`, which was never applied.

---

## R4. Role can be assumed without MFA

**Risk.** A stolen long-lived access key alone could assume the role.

**Detection.** Review of the trust policy during code review, confirmed by a behavioral test. Checkov has no check for this, so it is not a scanner finding.

**Fix.** The trust policy in `iam.tf` requires `aws:MultiFactorAuthPresent = true`.

**Verify (behavioral test).** From a terminal using the IAM user's long-term access keys (not a console session that already carries MFA, such as CloudShell) and no MFA token:
```powershell
aws sts assume-role --role-arn arn:aws:iam::<account-id>:role/<role-name> --role-session-name test
```
Expect `AccessDenied`. Then retry with `--serial-number <mfa-arn> --token-code <fresh-code>` and expect temporary credentials.

In this project the test was run against a temporary role (`mfa-test-role`) with the same trust condition. It returned `AccessDenied` without MFA and credentials with MFA (see `21-assume-role-denied.JPG`). The temporary role was deleted afterwards.

---

## R5. Console drift: Block Public Access disabled manually

**Risk.** Manual changes bypass code review and the CI gate. The deployed state silently diverges from the approved code.

**Detection.** `terraform plan` shows the resource will be changed back. In this project it reported `0 to add, 1 to change, 0 to destroy` on `module.app_data.aws_s3_bucket_public_access_block.this`, with all four settings going from `false` to `true`. In production, run this on a schedule and alert on a non-empty plan, and add AWS Config rules for continuous detection.

**Fix.** Run `terraform apply` to restore the declared state (it reported `1 changed`). Then address the root cause by restricting who can change these settings (for example, an SCP or a narrower IAM policy).

**Verify.** `terraform plan` reports no changes, and `get-public-access-block` shows all four settings `true`.

**Defense in depth.** The account-level Block Public Access setting is independent of the bucket-level one, so it remains a second layer while the bucket-level setting is off.

---

## R6. S3 access over plain HTTP

**Risk.** Data and credentials can be intercepted in transit.

**Detection.** Bucket policy review. No Checkov check for this was observed in this project's scan output.

**Fix.** The module's bucket policy has an explicit `Deny` on `s3:*` when `aws:SecureTransport` is `false` (statement `DenyInsecureTransport`).

**Verify.**
```powershell
curl.exe -I http://<bucket>.s3.amazonaws.com/
```
Expect a denial or a redirect, never object access over HTTP. The deployed policy is shown in `10-s3-tls-policy.JPG`.

---

## General remediation workflow

1. Create a branch and make the fix in code, never in the console.
2. Run `terraform fmt`, `terraform validate` and `checkov --config-file .checkov.yaml` locally.
3. Open a pull request and wait for both required checks to pass.
4. Merge, then `terraform plan` and `terraform apply`.
5. Capture verification evidence and record it in `compliance-evidence.md`.
