# CloudFormation Parameters

Parameter files follow this naming convention:

```text
<environment>-<stack>.json
```

For example, production network parameters are in `prod-network.json` and
production certificate parameters are in `prod-certificates.json`.

Do not pass one environment-wide file to every stack. CloudFormation rejects
parameters that are not declared by the selected template.

The deployment script supplies values produced by earlier stacks at runtime,
including VPC IDs, subnet IDs, security-group IDs, database endpoints, and DNS
targets. Files containing `REPLACE_WITH_*` values require account-specific
configuration before deployment. Never commit real database passwords or
other secrets to these files.

`prod-observability.json` accepts an optional `AlertEmail`. Set it to a real
email address and confirm the SNS subscription to receive alarm notifications.
`prod-frontend.json` keeps Shield Advanced disabled by default because it
requires a separate AWS Shield Advanced subscription.
