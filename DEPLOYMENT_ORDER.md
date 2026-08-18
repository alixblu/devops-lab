# CloudFormation Deployment Order

Deploy stacks in this order, but **START CERTIFICATES IMMEDIATELY** (they have no dependencies and take 5-30 min to validate).

## Step 1a: Network Layer (Start First)
```bash
aws cloudformation create-stack \
  --stack-name book-manager-dev-network \
  --template-body file://cloudformation/01-network.yaml \
  --parameters file://cloudformation/parameters/dev.json
```

**Do NOT wait.** Proceed to Step 1b while this deploys.

---

## Step 1b: ACM Certificates (Start Immediately - NO DEPENDENCIES)
**Start this right away to begin certificate validation in parallel:**

```bash
aws cloudformation create-stack \
  --stack-name book-manager-dev-certificates \
  --template-body file://cloudformation/07-certificates.yaml \
  --parameters file://cloudformation/parameters/dev.json
```

This has **no dependencies** on other stacks, so validation can proceed in parallel.

---

## Step 2: Security Layer (After Network Complete)
```bash
aws cloudformation create-stack \
  --stack-name book-manager-dev-security \
  --template-body file://cloudformation/02-security.yaml \
  --parameters file://cloudformation/parameters/dev.json
```

**Wait for completion** before proceeding to Step 3.

---

## Step 3: Database Layer (After Security Complete)
```bash
aws cloudformation create-stack \
  --stack-name book-manager-dev-database \
  --template-body file://cloudformation/03-database.yaml \
  --parameters file://cloudformation/parameters/dev.json
```

**Wait for completion**. RDS provisioning takes 5-10 minutes.

---

## Step 4: ACM Certificates (Validation Check)

**Check if certificates are validated yet:**

```bash
aws acm describe-certificate \
  --certificate-arn $(aws cloudformation describe-stacks \
    --stack-name book-manager-dev-certificates \
    --query 'Stacks[0].Outputs[?OutputKey==`ALBCertificateArn`].OutputValue' \
    --output text)
```

Look for `Status: ISSUED`. If still validating, continue to Step 5 and check again later.

---

## Step 5: Backend Layer (After Certificates ISSUED & All Prerequisites Complete)
```bash
aws cloudformation create-stack \
  --stack-name book-manager-dev-backend \
  --template-body file://cloudformation/04-backend.yaml \
  --parameters file://cloudformation/parameters/dev.json \
  --capabilities CAPABILITY_NAMED_IAM
```

**Wait for completion**. This creates:
- ECR repository
- ECS cluster and task definition
- Application Load Balancer
- CodePipeline and CodeBuild
- CodeDeploy for blue/green deployments

---

## Step 6: Frontend Layer (S3 + CloudFront + OAC)
```bash
aws cloudformation create-stack \
  --stack-name book-manager-dev-frontend \
  --template-body file://cloudformation/05-frontend.yaml \
  --parameters file://cloudformation/parameters/dev.json
```

**Wait for completion**. CloudFront distribution takes 5-10 minutes to deploy.

---

## Step 7: DNS Layer (Route53 Records)
```bash
aws cloudformation create-stack \
  --stack-name book-manager-dev-dns \
  --template-body file://cloudformation/06-dns.yaml \
  --parameters file://cloudformation/parameters/dev.json
```

**Note:** Route53 records creation requires the hosted zone to exist in the DNS account. If cross-account, you must:
1. Create records manually in the DNS account's hosted zone, OR
2. Set up a cross-account Route53 delegation setup

---

## Timeline Visualization

```
Time 0:00    Network Start → Network Complete (3-5 min)
             Certs Start  → Certs Validate In Parallel (5-30 min)
             
Time 0:05    Security Start → Security Complete (2-3 min)
             
Time 0:08    Database Start → Database Complete (5-10 min)
             
Time 0:13    Backend Start (waits for Certs ISSUED)
             Frontend Start (waits for Certs ISSUED)
             
Time 0:25    Backend Complete (10-15 min)
             Frontend Complete (5-10 min)
             
Time 0:35    DNS Start → DNS Complete (1-2 min)
             
TIME 0:37    ✅ FULL DEPLOYMENT COMPLETE (~37 minutes total)
```

**Key:** By starting certificates immediately, you save 5-30 minutes of waiting!

---

## Verification Checklist

After all stacks are deployed:

- [ ] Certificates status: **ISSUED**
- [ ] ALB health checks passing (check ECS service)
- [ ] CloudFront distribution is deployed and enabled
- [ ] S3 bucket policy allows CloudFront OAC access
- [ ] API accessible at `https://api.alixblu.site/health`
- [ ] Frontend accessible at `https://alixblu.site`
- [ ] CodePipeline can access GitHub repo
- [ ] RDS Multi-AZ replication confirmed in AWS Console

---

## Rollback / Cleanup

Delete stacks in **reverse order**:
```bash
aws cloudformation delete-stack --stack-name book-manager-dev-dns
aws cloudformation delete-stack --stack-name book-manager-dev-frontend
aws cloudformation delete-stack --stack-name book-manager-dev-backend
aws cloudformation delete-stack --stack-name book-manager-dev-database
aws cloudformation delete-stack --stack-name book-manager-dev-security
aws cloudformation delete-stack --stack-name book-manager-dev-network
aws cloudformation delete-stack --stack-name book-manager-dev-certificates
```

**Important:** Delete RDS stack manually if DeletionProtection is enabled.

---

## Notes

- **Secrets Manager:** The backend stack auto-generates `DJANGO_SECRET_KEY` and stores it in Secrets Manager
- **ECS Environment Variables:** Non-sensitive config (DB_HOST, DJANGO_DEBUG, etc.) are set via ECS Environment
- **VPC Endpoint:** S3 traffic from private subnets uses the S3 gateway endpoint (no NAT charges)
- **Multi-AZ Database:** RDS is configured for Multi-AZ with automatic failover
- **Blue/Green Deployments:** CodeDeploy handles zero-downtime updates
- **Parallel Deployment:** Network and Certificates can start simultaneously for fastest deployment
