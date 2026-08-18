# CloudFormation Console Deployment Guide

Complete step-by-step instructions for deploying Book Manager infrastructure via AWS CloudFormation Console.

**IMPORTANT:** Start the **Certificates stack immediately after Network** to let validation happen in parallel. This saves 5-30 minutes!

---

## Prerequisites

- AWS Account with appropriate permissions
- Access to CloudFormation Console
- CloudFormation templates uploaded to S3 or local machine
- Parameter files (dev.json, staging.json, prod.json) ready

---

## Step 1: Network Layer (01-network.yaml)

### 1.1 Open CloudFormation Console
1. Go to **AWS Console** → **CloudFormation**
2. Click **Create stack** → **With new resources (standard)**

### 1.2 Specify Template
1. Choose **Upload a template file**
2. Click **Choose file** and select `cloudformation/01-network.yaml`
3. Click **Next**

### 1.3 Configure Stack Details
1. **Stack name:** `book-manager-dev-network` (or `prod-network` for production)
2. **Parameters:**
   - `EnvironmentName`: `dev` (or `prod`/`staging`)
   - `VpcCIDR`: `10.0.0.0/16`
   - `PublicSubnet1CIDR`: `10.0.1.0/24`
   - `PublicSubnet2CIDR`: `10.0.2.0/24`
   - `PrivateSubnet1CIDR`: `10.0.3.0/24`
   - `PrivateSubnet2CIDR`: `10.0.4.0/24`
3. Click **Next**

### 1.4 Configure Stack Options
1. Leave defaults (tags are optional)
2. Click **Next**

### 1.5 Review and Create
1. Review all details
2. Check **"I acknowledge that AWS CloudFormation might create IAM resources"** *(only if prompted)*
3. Click **Create stack**

### 1.6 Monitor Deployment
- Status page shows: **CREATE_IN_PROGRESS** → **CREATE_COMPLETE**
- Takes ~3-5 minutes
- **DO NOT WAIT** — Proceed to Step 1b (Certificates) immediately while Network deploys

---

## Step 1b: ACM Certificates (07-certificates.yaml) — START IMMEDIATELY

**Start this right away while Network is deploying. Certificates have no dependencies and need 5-30 minutes to validate.**

### 1b.1 Create Stack
1. Click **Create stack** → **With new resources (standard)**
2. Upload `cloudformation/07-certificates.yaml`
3. Click **Next**

### 1b.2 Configure Stack Details
1. **Stack name:** `book-manager-dev-certificates`
2. **Parameters:**
   - `EnvironmentName`: `dev`
   - `DomainName`: `alixblu.site`
   - `ApiDomainName`: `api.alixblu.site`
3. Click **Next**

### 1b.3 Review and Create
1. Review details
2. Click **Create stack**
3. ⏳ **Validation starts immediately** — continue to Step 2 while this validates

---

## Step 2: Security Layer (02-security.yaml)

**Wait for Network stack to complete, then proceed.**

### 2.1 Create Stack
1. Click **Create stack** → **With new resources (standard)**
2. Upload `cloudformation/02-security.yaml`
3. Click **Next**

### 2.2 Configure Stack Details
1. **Stack name:** `book-manager-dev-security`
2. **Parameters:**
   - `EnvironmentName`: `dev`
   - `VpcId`: Copy from **Step 1 Outputs** → `VpcId` field
3. Click **Next**

### 2.3 Review and Create
1. Review details
2. Click **Create stack**
3. ✅ **Wait for completion** (~2-3 minutes)

---

## Step 3: Database Layer (03-database.yaml)

### 3.1 Create Stack
1. Click **Create stack** → **With new resources (standard)**
2. Upload `cloudformation/03-database.yaml`
3. Click **Next**

### 3.2 Configure Stack Details
1. **Stack name:** `book-manager-dev-database`
2. **Parameters:**
   - `EnvironmentName`: `dev`
   - `DBUsername`: `bookadmin`
   - `DBPassword`: `[STRONG_PASSWORD]` (26+ chars, special chars)
   - `DBInstanceClass`: `db.t3.small` (dev) or `db.t3.medium` (prod)
   - `DBStorageGB`: `20` (dev) or `100` (prod)
   - `PrivateSubnetIds`: Copy from **Step 1 Outputs** → `PrivateSubnetIds`
   - `RDSecurityGroupId`: Copy from **Step 2 Outputs** → `DatabaseSecurityGroupId`
3. Click **Next**

### 3.3 Review and Create
1. Review details
2. Click **Create stack**
3. ⏳ **WAIT 5-10 MINUTES** for RDS instance to provision

---

## Step 4: Certificate Validation Check (07-certificates.yaml)

**Check if your certificates are validated yet.**

### 4.1 Check Certificates Status
1. Go back to **CloudFormation** → Find `book-manager-dev-certificates` stack
2. Click the stack → **Outputs** tab
3. Copy the `ALBCertificateArn`
4. Go to **AWS Certificate Manager** in current region
5. Find the certificate with that ARN
6. Check **Status:**
   - 🟢 **ISSUED** → Great! Proceed to Step 5
   - 🟡 **Pending validation** → Continue to Step 5 anyway, check again later

### 4.2 CloudFront Certificate (MANUAL - REQUIRED IN us-east-1)
1. Go to **AWS Certificate Manager**
2. **Switch region to us-east-1** (top-right corner)
3. Click **Request a certificate**
4. **Certificate type:** Request a public certificate
5. **Domain names:**
   - `alixblu.site`
   - `*.alixblu.site`
6. **Validation method:** DNS
7. Click **Request**
8. Click on the certificate to open it
9. Under **Domains**, click **Create records in Route53**
   - This auto-validates via DNS
10. Wait for **Status: ISSUED**
11. Copy the **Certificate ARN** (looks like: `arn:aws:acm:us-east-1:123456789012:certificate/abc123...`)

---

## Step 5: Backend Layer (04-backend.yaml)

**Proceed when:**
- ✅ Network stack complete
- ✅ Security stack complete  
- ✅ Database stack complete
- ✅ ALB Certificate status: ISSUED (or at least validating)

### 5.1 Create Stack
1. Click **Create stack** → **With new resources (standard)**
2. Upload `cloudformation/04-backend.yaml`
3. Click **Next**

### 5.2 Configure Stack Details
1. **Stack name:** `book-manager-dev-backend`
2. **Parameters:**
   - `EnvironmentName`: `dev`
   - `DomainName`: `alixblu.site`
   - `ApiDomainName`: `api.alixblu.site`
   - `ECSContainerPort`: `8000`
   - `ECRRepositoryName`: `book-manager-backend`
   - `ECSContainerName`: `book-manager-backend`
   - `DesiredTaskCount`: `2` (dev) or `3` (prod)
   - `ECRImageTag`: `latest`
   - `PublicSubnetIds`: Copy from **Step 1 Outputs**
   - `PrivateSubnetIds`: Copy from **Step 1 Outputs**
   - `ALBSecurityGroupId`: Copy from **Step 2 Outputs**
   - `ECSSecurityGroupId`: Copy from **Step 2 Outputs**
   - `DBEndpoint`: Copy from **Step 3 Outputs** → `DBEndpoint`
   - `DBName`: `book_manager`
   - `DBUsername`: `bookadmin` (same as Step 3)
   - `DBPassword`: `[SAME_PASSWORD_AS_STEP_3]`
   - `GitHubOwner`: Your GitHub username
   - `GitHubRepo`: `fcaj-lab`
   - `GitHubBranch`: `main`
   - `GitHubConnectionName`: `bookmanager-github-connection`
3. Click **Next**

### 5.3 Configure Stack Options
1. Check **"I acknowledge that AWS CloudFormation might create IAM resources"**
2. Click **Next**

### 5.3 Review and Create
1. Review IAM resources being created:
   - ECS Task Execution Role
   - ECS Task Role
   - CodeBuild Role
   - CodePipeline Role
   - CodeDeploy Role
2. Check the acknowledgment box
3. Click **Create stack**

⏳ **WAIT 10-15 MINUTES** for ECS, ALB, and CodePipeline creation

### 5.4 GitHub Connection Authorization
1. Go to **Developer Tools** → **Connections**
2. Find the newly created connection (pending authorization)
3. Click it
4. Click **Authorize with GitHub**
5. Sign in to GitHub and grant AWS access
6. Select your repository
7. Click **Connect**

---

## Step 6: Frontend Layer (05-frontend.yaml)

### 6.1 Create Stack
1. Click **Create stack** → **With new resources (standard)**
2. Upload `cloudformation/05-frontend.yaml`
3. Click **Next**

### 6.2 Configure Stack Details
1. **Stack name:** `book-manager-dev-frontend`
2. **Parameters:**
   - `EnvironmentName`: `dev`
   - `DomainName`: `alixblu.site`
   - `FrontendBucketName`: `book-manager-frontend-dev-[ACCOUNT_ID]` (must be unique)
   - `WebACLArn`: Copy from **Step 2 Outputs** → `WebACLArn`
3. Click **Next**

### 6.3 Review and Create
1. Review details
2. Click **Create stack**

⏳ **WAIT 5-10 MINUTES** for CloudFront distribution

---

## Step 7: DNS Layer (06-dns.yaml)

### 7.1 Create Stack
1. Click **Create stack** → **With new resources (standard)**
2. Upload `cloudformation/06-dns.yaml`
3. Click **Next**

### 7.2 Configure Stack Details
1. **Stack name:** `book-manager-dev-dns`
2. **Parameters:**
   - `EnvironmentName`: `dev`
   - `DomainName`: `alixblu.site`
   - `ApiDomainName`: `api.alixblu.site`
   - `HostedZoneId`: Your Route53 hosted zone ID (from Route53 console)
   - `ALBDNSName`: Copy from **Step 5 Outputs** → `ALBEndpoint`
   - `CloudFrontDomainName`: Copy from **Step 6 Outputs** → `CloudFrontDomainName`
3. Click **Next**

### 7.3 Review and Create
1. Review details
2. Click **Create stack**

✅ **DNS records now point to ALB and CloudFront**

---

## Verification Checklist

After all stacks complete:

### ✅ Check ECS Health
1. Go to **ECS** → **Clusters**
2. Click `book-manager-dev-cluster`
3. Click **Services** → `book-manager-dev-service`
4. Check **Running count** = Desired count
5. View **Task** tab to confirm tasks are **RUNNING**

### ✅ Check ALB
1. Go to **EC2** → **Load Balancers**
2. Click `book-manager-dev-alb`
3. Go to **Target Groups**
4. Check **Healthy targets** > 0 for both blue and green groups

### ✅ Check CloudFront
1. Go to **CloudFront** → **Distributions**
2. Click the distribution
3. Check **Status: Deployed** and **State: Enabled**

### ✅ Check S3 Bucket Policy
1. Go to **S3** → Click frontend bucket
2. Go to **Permissions** → **Bucket policy**
3. Verify CloudFront OAC has `s3:GetObject` permission

### ✅ Test API
```bash
# Test ALB directly
curl https://api.alixblu.site/health

# Or use ALB DNS name
curl -H "Host: api.alixblu.site" https://[ALB_DNS_NAME]/health
```

### ✅ Test Frontend
```bash
# CloudFront URL
curl https://alixblu.site/

# Or via domain
curl https://alixblu.site/
```

### ✅ Check CodePipeline
1. Go to **CodePipeline** → Pipelines
2. Click `book-manager-dev-pipeline`
3. Verify **Source** stage connected to GitHub
4. Check for successful deployments

### ✅ Check RDS Database
1. Go to **RDS** → **Databases**
2. Click the database instance
3. Verify:
   - **Multi-AZ: Yes**
   - **Status: available**
   - **Backup retention: 7 days**

---

## Troubleshooting

### Certificate Status Stuck on "Pending Validation"
- Go to ACM → Find the certificate
- Click **Create records in Route53** manually
- Wait 5-10 minutes for validation

### ALB Targets Unhealthy
1. Go to **ECS** → Check task logs
2. Go to **EC2** → **Target Groups** → Check health check details
3. Common issues:
   - Django app not listening on port 8000
   - DJANGO_ALLOWED_HOSTS mismatch
   - Security group blocking traffic

### CloudFront 403 Error
1. Go to **S3** → Frontend bucket → **Permissions** → **Bucket policy**
2. Verify CloudFront OAC has permission
3. Check **Block Public Access** settings (should all be enabled)

### GitHub Connection Fails
1. Go to **Developer Tools** → **Connections**
2. Check connection status
3. Re-authorize if needed
4. Verify repository access in GitHub settings

### CodePipeline Fails at Build
1. Go to **CodeBuild** → **Build history**
2. Click failed build to see logs
3. Check **buildspec.yml** syntax
4. Verify ECR repository exists

---

## Cleanup (Delete Infrastructure)

**DELETE IN REVERSE ORDER:**

1. **Delete DNS Stack**
   - CloudFormation → Find `book-manager-dev-dns` → **Delete**

2. **Delete Frontend Stack**
   - CloudFormation → Find `book-manager-dev-frontend` → **Delete**
   - ⏳ CloudFront distribution takes 10-15 min to delete

3. **Delete Backend Stack**
   - CloudFormation → Find `book-manager-dev-backend` → **Delete**
   - Wait for completion

4. **Delete Database Stack**
   - ⚠️ If deletion protection is enabled:
     - Go to **RDS** → Database instance → **Modify**
     - Uncheck **Deletion Protection**
     - Click **Modify**
   - CloudFormation → Find `book-manager-dev-database` → **Delete**
   - ⏳ Takes 5-10 minutes

5. **Delete Security Stack**
   - CloudFormation → Find `book-manager-dev-security` → **Delete**

6. **Delete Certificates Stack**
   - CloudFormation → Find `book-manager-dev-certificates` → **Delete**
   - ⚠️ Manually delete CloudFront certificate from ACM (us-east-1)

7. **Delete Network Stack**
   - CloudFormation → Find `book-manager-dev-network` → **Delete**
   - ✅ All infrastructure removed

---

## Summary Table

| Stack | Depends On | Time | Key Resources |
|-------|-----------|------|----------------|
| Network | None (start first) | 3-5 min | VPC, Subnets, NAT, S3 Endpoint |
| **Certificates** | **None (start immediately in parallel)** | **5-30 min (validates in parallel)** | **ACM Certificates (ALB + CloudFront)** |
| Security | Network | 2-3 min | Security Groups, WAF |
| Database | Security | 5-10 min | RDS Multi-AZ PostgreSQL |
| Backend | Network, Security, Certs | 10-15 min | ECR, ECS, ALB, CodePipeline |
| Frontend | Security, Certs | 5-10 min | S3, CloudFront, OAC |
| DNS | Backend, Frontend | 1-2 min | Route53 A Records |
| **TOTAL** | | **~37 min** | Complete application stack |

---

## Notes

- **Start Network and Certificates in parallel** — saves 5-30 minutes!
- **GitHub connection must be authorized** before CodePipeline can run
- **Database password** must be stored securely (consider AWS Secrets Manager)
- **CloudFront certificate must be in us-east-1** (automatic region requirement)
- **Multi-AZ RDS is enabled** for production resilience
- **S3 VPC endpoint** reduces NAT Gateway costs for private subnet traffic
