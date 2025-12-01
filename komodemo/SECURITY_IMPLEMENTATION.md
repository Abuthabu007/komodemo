# Enterprise-Level Security Implementation for Video Platform

## Overview
This document outlines the comprehensive enterprise-grade security architecture implemented for the video platform infrastructure on GCP.

## Security Architecture Components

### 1. Network Security (VPC Module)

#### Features Implemented:
- **VPC Network**: Isolated custom VPC with no auto-created subnets
- **Private Subnets**: Restricted CIDR ranges (10.0.1.0/24) for backend services
- **Cloud NAT**: Outbound-only traffic with automatic IP management
- **VPC Connector**: Serverless connectivity for Cloud Run to access VPC resources
- **Flow Logs**: Network traffic logging with sampling at 50% for cost optimization
- **Cloud Armor**: DDoS protection and WAF with:
  - Rate limiting (100 requests/minute per IP)
  - XSS protection (evaluatePreconfiguredExpr)
  - SQL injection protection
  - Geographic blocking (configurable for restricted countries)
  - Custom security policies

#### Files:
- `modules/security/main.tf` - VPC, NAT, Cloud Armor, and firewall rules
- `modules/security/variables.tf` - Configuration variables
- `modules/security/outputs.tf` - Resource outputs

---

### 2. Identity & Access Management (IAM Module)

#### Custom Roles Created:

**Super Admin Role** (`videoplatform_super_admin`)
- Full platform access
- Video management (list, get, create, delete, update)
- IAM role management
- Logging and monitoring access

**Video Editor Role** (`videoplatform_video_editor`)
- Upload videos
- Edit video metadata
- Manage video permissions
- Delete owned videos
- Storage object manipulation

**Video Viewer Role** (`videoplatform_video_viewer`)
- View public videos
- Download available content
- View bucket metadata
- Read-only access

#### Service Accounts:

1. **API Gateway SA** (`{project-id}-api-gateway`)
   - Manages user authentication
   - Controls API access
   - Audit logging
   - Permissions: Storage viewer, Logging writer

2. **Video Processor SA** (`{project-id}-video-processor`)
   - Transcoding and processing
   - Storage management
   - Signed URL generation
   - Permissions: Storage admin, Logging writer

3. **Analytics SA** (`{project-id}-analytics`)
   - Data collection and analysis
   - BigQuery integration
   - Permissions: Logging viewer, BigQuery data editor

#### Workload Identity:
- Workload Identity Pool for external authentication
- OAuth2 provider configuration
- Attribute mapping for user identity verification

---

### 3. Data Encryption & Key Management (KMS)

#### Key Configuration:
- **Keyring**: Centralized key management (`{project-id}-keyring`)
- **Storage Encryption Key**: 90-day rotation for video data
- **Database Encryption Key**: 90-day rotation for metadata
- **Key Lifecycle**: Automatic key rotation every 7,776,000 seconds (90 days)

#### Implementation:
```
KMS Keys are lifecycle-protected (prevent_destroy = true)
All keys automatically rotated every 90 days
Audit logs track all key usage
```

---

### 4. Cloud Storage Security

#### Bucket Configuration:
- **Uniform Bucket-Level Access**: Enabled (no ACLs)
- **Encryption**: Customer-managed encryption keys (CMEK)
- **Versioning**: Enabled for data recovery and compliance
- **Public Access Prevention**: Enforced
- **Force Destroy**: Disabled (prevents accidental deletion)

#### Lifecycle Policies:
- 90 days: Transition to NEARLINE storage
- 365 days: Transition to COLDLINE storage
- 2555 days (7 years): Delete (compliance retention period)

#### Access Control:
- Signed URLs for secure sharing (time-limited)
- Service account-specific permissions
- Audit bucket with event-based hold (immutable logs)
- Logging enabled with prefix organization

#### CORS Configuration:
- Restricted to specific origins
- Allowed methods: GET, PUT, POST, DELETE
- Max age: 3600 seconds

---

### 5. Cloud Run Security

#### Configuration:
- **Ingress**: `INGRESS_TRAFFIC_INTERNAL_ONLY` (no public internet)
- **Deletion Protection**: Enabled
- **VPC Connector**: Private network access via VPC
- **Min/Max Instances**: Auto-scaling with boundaries
- **Container Security**:
  - Non-root user execution
  - Read-only root filesystem
  - No privilege escalation
  - Resource limits (CPU, memory)

#### Health Checks:
- **Liveness Probe**: Restarts unhealthy containers
- **Startup Probe**: Delays traffic until ready
- Path: `/health` endpoint

#### IAM:
- Authenticated users only (no anonymous access)
- API Gateway service account has specific invoker role
- Role-based access control

---

### 6. Secret Management

#### Secret Manager Configuration:
- **Secret Name**: `{project-id}-api-keys`
- **Replication**: Automatic global replication
- **Access**: Service account restricted
- **Rotation**: Manual rotation policy

#### Usage:
- Store API keys, credentials, OAuth tokens
- Automatic encryption with Google-managed keys
- Audit logging for all access

---

### 7. Logging & Audit

#### Cloud Logging:
- **Audit Sink**: Collects API and resource logs
- **Flow Logs**: Network traffic analysis
- **Cloud Armor Logs**: DDoS/WAF events
- **Service Logs**: Application-level logging

#### Log Retention:
- Audit logs: Indefinite (immutable)
- Flow logs: 90 days
- Application logs: 30 days

---

### 8. Firewall Rules

#### Default Deny:
- All ingress traffic denied by default (priority 65534)
- Explicit allow for health checks only

#### Health Check Rule:
- Allows TCP 8080, 8443 from Google health check IPs
- Source ranges: 35.191.0.0/16, 130.211.0.0/22

---

## Security Features by User Role

### Super Admin
- ✅ Create/manage users
- ✅ View all videos and metadata
- ✅ Configure system settings
- ✅ Access audit logs
- ✅ Manage encryption keys
- ✅ User role assignments

### Video Editors
- ✅ Upload videos
- ✅ Edit metadata
- ✅ Mark private/public
- ✅ Manage download restrictions
- ✅ Generate sharing links (signed URLs)
- ❌ Delete others' videos
- ❌ Access other users' data (except shared)

### Video Viewers
- ✅ View public videos
- ✅ Download available videos
- ✅ Access shared links
- ❌ Upload videos
- ❌ Delete videos
- ❌ View private content

---

## Compliance & Standards

### Implemented Standards:
- **HTTPS Only**: Cloud Armor enforces TLS
- **Encryption in Transit**: TLS 1.3 for all connections
- **Encryption at Rest**: CMEK with 90-day rotation
- **Audit Logging**: All access logged and immutable
- **Data Retention**: 7-year retention policy
- **Access Control**: Least privilege principle
- **Network Isolation**: Private VPC with no public endpoints

### Compliance Frameworks:
- **GDPR**: Data encryption, audit logs, user consent
- **SOC 2**: Access controls, encryption, logging
- **HIPAA**: Encryption, audit trails (if applicable)
- **PCI-DSS**: Network isolation, encryption, access controls

---

## Deployment Variables

Update your `dev.auto.tfvars` with:

```hcl
# Security Module
private_subnet_cidr  = "10.0.1.0/24"
vpc_connector_cidr   = "10.8.0.0/28"

# Storage Module
kms_key                     = "projects/PROJECT_ID/locations/REGION/keyRings/PROJECT_ID-keyring/cryptoKeys/PROJECT_ID-storage-key"
project_number              = "YOUR_PROJECT_NUMBER"
video_processor_sa_email    = "PROJECT_ID-video-processor@PROJECT_ID.iam.gserviceaccount.com"
cors_origins                = ["https://yourdomain.com", "https://app.yourdomain.com"]

# Cloud Run Module
vpc_connector_name          = "PROJECT_ID-vpc-connector"
api_gateway_sa_email        = "PROJECT_ID-api-gateway@PROJECT_ID.iam.gserviceaccount.com"
storage_encryption_key      = "projects/PROJECT_ID/locations/REGION/keyRings/PROJECT_ID-keyring/cryptoKeys/PROJECT_ID-storage-key"
min_instances               = 1
max_instances               = 100
```

---

## Next Steps

1. **Deploy Security Module**: Creates VPC, KMS, Cloud Armor
2. **Deploy Identity Module**: Creates custom roles and service accounts
3. **Update Cloud Run**: Enable VPC connector and authentication
4. **Update Storage**: Enable CMEK encryption
5. **Configure Eventarc**: Add signed URL generation and audit logging
6. **User Onboarding**: Assign custom roles to users
7. **Testing**: Validate security policies and access controls

---

## Monitoring & Maintenance

### Security Monitoring:
- Cloud Logging dashboard for audit events
- Cloud Armor metrics for DDoS attempts
- KMS key rotation calendar
- Service account key rotation (90 days)

### Regular Reviews:
- Monthly access control audit
- Quarterly security policy review
- Annual compliance certification
- Incident response drills

---

## Support & Documentation

For questions or issues:
1. Check GCP documentation: cloud.google.com
2. Review terraform modules
3. Check audit logs for errors
4. Test in staging environment first

