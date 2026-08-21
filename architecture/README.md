# Production Architecture

The infrastructure is deployed as independent CloudFormation stacks:

```text
Network -> Security -> Database -> Backend -> Frontend -> DNS
              ^          ^          ^          ^
              |          |          |          |
       VPC and subnet outputs are passed between stacks

Certificates and global resources are deployed separately:
- ALB certificate: the application region
- CloudFront certificate and CloudFront WAF: `us-east-1`
- The deployment runner passes the global outputs to the frontend stack
```

The stack templates live in `cloudformation/templates/`. Production parameter
files live in `cloudformation/parameters/`, one file per stack. Deployment
commands and helper scripts live in `cloudformation/scripts/`.