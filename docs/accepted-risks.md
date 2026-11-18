# Accepted Risks

Every Checkov check excluded in `.checkov.yaml` is listed here with a reason, a compensating control, and a note on what would be done in production. Skipping a check without a written justification is not allowed in this repository.

| Field | Meaning |
|---|---|
| Decision | Accept (knowingly not implemented) or Defer (planned for production) |
| Compensating control | What reduces the risk in the meantime |
| Review trigger | The event that should make us revisit the decision |

---

## Global skips (`.checkov.yaml`)

### CKV_AWS_18: S3 bucket access logging disabled

- **Decision:** Accept for the lab.
- **Reason:** Access logging needs a third bucket whose own logging would raise the same check, creating a chain. It adds cost and clutter with no learning value for this scope.
- **Compensating controls:** CloudTrail records management events for both buckets. Block Public Access and the TLS-only policy limit exposure.
- **Production note:** Enable server access logging, or CloudTrail S3 data events, for sensitive buckets, delivered to a separate log-archive account.
- **Review trigger:** Any bucket holding real data.

### CKV_AWS_144: S3 cross-region replication not enabled

- **Decision:** Accept for the lab.
- **Reason:** Replication requires a second bucket in another region, a replication role and extra storage and transfer charges. The project goal is a low-cost lab.
- **Compensating controls:** Versioning is enabled. Data is non-production and disposable.
- **Production note:** Enable replication on the audit-log bucket for disaster recovery and regulatory retention.
- **Review trigger:** Any retention or availability requirement for the data.

### CKV2_AWS_62: S3 event notifications not enabled

- **Decision:** Accept.
- **Reason:** There is no workload consuming bucket events. Adding a notification target would create unused infrastructure.
- **Compensating controls:** None required.
- **Review trigger:** Introduction of an application that processes S3 objects.

### CKV2_AWS_10: CloudTrail not integrated with CloudWatch Logs

- **Decision:** Defer.
- **Reason:** CloudWatch Logs ingestion and storage adds cost, and the metric filters and alarms behind it are out of scope.
- **Compensating controls:** Logs are retained in S3 with integrity validation and KMS encryption and can be queried on demand.
- **Production note:** Stream CloudTrail to CloudWatch Logs with metric filters and alarms for the CIS monitoring controls (root login, console login without MFA, IAM policy changes, CloudTrail configuration changes).
- **Review trigger:** Any move toward real-time alerting requirements.

### CKV_AWS_252: CloudTrail has no SNS topic

- **Decision:** Defer.
- **Reason:** No consumer is subscribed to notifications, and an SNS topic would be unused.
- **Compensating controls:** As for CKV2_AWS_10.
- **Production note:** Use SNS or EventBridge for log-delivery notifications into a SIEM or ticketing workflow.
- **Review trigger:** Introduction of a monitoring or SIEM integration.

---

## Inline skips

### CKV_AWS_109 on `data.aws_iam_policy_document.kms`

- **File and line:** main.tf:12
- **Decision:** Accept
- **Reason:** The `EnableAccountAdmin` statement grants the account root `kms:*` on `Resource: "*"`. This is the AWS-documented default key policy that lets IAM policies delegate key access. In a key policy, `"*"` refers only to this key, so the finding is a false positive. Removing the statement risks making the key unmanageable.
- **Compensating controls:** The principal is the account root, so actual access to the key is governed by IAM policies. The only other statement is limited to `cloudtrail.amazonaws.com` and conditioned on `aws:SourceArn` matching the project's trail. The key is used only for the CloudTrail logs. Key rotation is enabled.
- **Review trigger:** Any change to the key policy, a new principal or service granted access to the key, or Checkov changing how it evaluates KMS key policies.

### CKV_AWS_111 on `data.aws_iam_policy_document.kms`

- **File and line:** main.tf:12
- **Decision:** Accept
- **Reason:** The `EnableAccountAdmin` statement allows `kms:*` (including write actions) for the account root on `Resource: "*"`, which means this key only. This is the AWS default, and write access is delegated through IAM rather than granted to any individual principal here.
- **Compensating controls:** As for CKV_AWS_109.
- **Review trigger:** Same as CKV_AWS_109.

### CKV_AWS_356 on `data.aws_iam_policy_document.kms`

- **File and line:** main.tf:12
- **Decision:** Accept
- **Reason:** Both statements use `Resource: "*"`, which in a key policy means "this key". AWS requires this form. The `AllowCloudTrailEncrypt` statement is further restricted to `kms:GenerateDataKey*` and `kms:DescribeKey`, the CloudTrail service principal, and an `aws:SourceArn` condition for the project's trail.
- **Compensating controls:** As for CKV_AWS_109.
- **Review trigger:** Same as CKV_AWS_109.

---

## Deliberate lab-only settings (not Checkov skips)

These are not scanner exceptions, but a reviewer should know about them.

| Setting | Where | Why | Production change |
|---|---|---|---|
| `force_destroy = true` on buckets | `modules/secure_bucket` | Allows clean teardown of non-empty buckets | Remove, so a destroy cannot wipe audit logs |
| `AdministratorAccess` on the deploy user | IAM user `TF-Admin` | Simplicity for a single-person lab | Replace with a scoped deploy role assumed via SSO or OIDC |
| Local Terraform state | Local file | Avoids backend setup and cost | S3 backend with native locking and a restricted state bucket |
| KMS `deletion_window_in_days = 7` | `main.tf` | Shortest allowed window, for fast cleanup | 30 days, to leave time to recover from mistakes |
| Single account | Whole project | Cost and simplicity | Separate workload, security and log-archive accounts under Organizations with SCPs |
| Expiry on audit-log objects (90 days) | `modules/secure_bucket` | Prevents lab data lingering | Set to the organization's retention requirement, often one year or more, with Object Lock |

---

## Review process

1. Any new skip needs a pull request that updates both `.checkov.yaml` (or the inline comment) and this file.
2. Reviewers confirm the reason is specific and a compensating control is named.
3. Revisit this file when scanner rules change or the project scope grows.
