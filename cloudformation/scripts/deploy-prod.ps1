$ErrorActionPreference = 'Stop'

$Region = if ($env:AWS_REGION) { $env:AWS_REGION } else { (aws configure get region).Trim() }
$GlobalRegion = 'us-east-1'
if ([string]::IsNullOrWhiteSpace($Region)) {
    throw 'Set AWS_REGION or configure an AWS default region before running this script.'
}
if ($Region -eq $GlobalRegion) {
    throw 'AWS_REGION must be the application region, not us-east-1. The script deploys global resources in us-east-1 automatically.'
}

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$CloudFormationRoot = Resolve-Path (Join-Path $ScriptRoot '..')
$TemplateRoot = Join-Path $CloudFormationRoot 'templates'
$ParameterRoot = Join-Path $CloudFormationRoot 'parameters'

Get-ChildItem (Join-Path $ParameterRoot 'prod-*.json') | ForEach-Object {
    $unconfigured = (Get-Content $_.FullName -Raw | ConvertFrom-Json) | Where-Object {
        $_.ParameterValue -like 'REPLACE_WITH_*'
    }
    if ($unconfigured) {
        $names = ($unconfigured | ForEach-Object ParameterKey) -join ', '
        throw "Configure these parameters in $($_.Name) before deployment: $names"
    }
}

function Get-ParameterOverrides([string] $FileName) {
    $filePath = Join-Path $ParameterRoot $FileName
    return @((Get-Content $filePath -Raw | ConvertFrom-Json) | ForEach-Object {
        "$($_.ParameterKey)=$($_.ParameterValue)"
    })
}

function Get-StackOutput([string] $StackName, [string] $OutputKey, [string] $StackRegion) {
    $value = & aws cloudformation describe-stacks --region $StackRegion --stack-name $StackName --query "Stacks[0].Outputs[?OutputKey=='$OutputKey'].OutputValue" --output text
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value) -or $value -eq 'None') {
        throw "Could not read output '$OutputKey' from stack '$StackName' in '$StackRegion'."
    }
    return $value.Trim()
}

function Get-HostedZoneId([string] $DomainName) {
    $lookupName = "$($DomainName.TrimEnd('.'))."
    $value = & aws route53 list-hosted-zones-by-name --dns-name $lookupName --query "HostedZones[?Name=='$lookupName' && Config.PrivateZone==\`false\`]|[0].Id" --output text
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value) -or $value -eq 'None') {
        throw "Could not find a public Route 53 hosted zone for '$DomainName'."
    }
    return ($value.Trim() -split '/')[-1]
}

function Deploy-Stack([string] $StackName, [string] $TemplateName, [string] $ParameterFile, [string] $StackRegion, [string[]] $ExtraParameters, [switch] $UseIamCapabilities) {
    $templatePath = Join-Path $TemplateRoot $TemplateName
    $overrides = @(Get-ParameterOverrides $ParameterFile) + @($ExtraParameters)
    $arguments = @(
        'cloudformation', 'deploy',
        '--region', $StackRegion,
        '--stack-name', $StackName,
        '--template-file', $templatePath,
        '--parameter-overrides'
    ) + $overrides + @('--no-fail-on-empty-changeset')
    if ($UseIamCapabilities) {
        $arguments += @('--capabilities', 'CAPABILITY_NAMED_IAM')
    }

    Write-Host "Deploying $StackName in $StackRegion..."
    & aws @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Deployment failed for stack '$StackName'."
    }
}

$networkStack = 'book-manager-prod-network'
$certificateStack = 'book-manager-prod-certificates'
$securityStack = 'book-manager-prod-security'
$databaseStack = 'book-manager-prod-database'
$globalStack = 'book-manager-prod-global'
$backendStack = 'book-manager-prod-backend'
$observabilityStack = 'book-manager-prod-observability'
$frontendStack = 'book-manager-prod-frontend'
$dnsStack = 'book-manager-prod-dns'
$domainName = (Get-ParameterOverrides 'prod-global.json' | Where-Object { $_ -like 'DomainName=*' }).Substring(11)
$hostedZoneId = Get-HostedZoneId $domainName

Deploy-Stack $networkStack '01-network.yaml' 'prod-network.json' $Region @()
$vpcId = Get-StackOutput $networkStack 'VpcId' $Region
$publicSubnetIds = Get-StackOutput $networkStack 'PublicSubnetIds' $Region
$databasePrivateSubnetIds = Get-StackOutput $networkStack 'DatabasePrivateSubnetIds' $Region
$ecsPrivateSubnetIds = Get-StackOutput $networkStack 'ECSPrivateSubnetIds' $Region

Deploy-Stack $certificateStack '07-certificates.yaml' 'prod-certificates.json' $Region @()
$albCertificateArn = Get-StackOutput $certificateStack 'ALBCertificateArn' $Region
& aws acm wait certificate-validated --region $Region --certificate-arn $albCertificateArn
if ($LASTEXITCODE -ne 0) { throw 'ALB certificate validation did not complete successfully.' }

Deploy-Stack $globalStack '09-global.yaml' 'prod-global.json' $GlobalRegion @("HostedZoneId=$hostedZoneId")
$cloudFrontCertificateArn = Get-StackOutput $globalStack 'CloudFrontCertificateArn' $GlobalRegion
$webAclArn = Get-StackOutput $globalStack 'WebACLArn' $GlobalRegion
& aws acm wait certificate-validated --region $GlobalRegion --certificate-arn $cloudFrontCertificateArn
if ($LASTEXITCODE -ne 0) { throw 'CloudFront certificate validation did not complete successfully.' }

Deploy-Stack $securityStack '02-security.yaml' 'prod-security.json' $Region @("VpcId=$vpcId")
$albSecurityGroupId = Get-StackOutput $securityStack 'ALBSecurityGroupId' $Region
$ecsSecurityGroupId = Get-StackOutput $securityStack 'ECSSecurityGroupId' $Region
$rdsSecurityGroupId = Get-StackOutput $securityStack 'RDSecurityGroupId' $Region

Deploy-Stack $databaseStack '03-database.yaml' 'prod-database.json' $Region @("DatabasePrivateSubnetIds=$databasePrivateSubnetIds", "RDSecurityGroupId=$rdsSecurityGroupId")
$dbEndpoint = Get-StackOutput $databaseStack 'DBEndpoint' $Region
$dbSecretArn = Get-StackOutput $databaseStack 'DBSecretArn' $Region
$dbInstanceIdentifier = Get-StackOutput $databaseStack 'DBInstanceIdentifier' $Region

Deploy-Stack $backendStack '04-backend.yaml' 'prod-backend.json' $Region @(
    "PublicSubnetIds=$publicSubnetIds",
    "ECSPrivateSubnetIds=$ecsPrivateSubnetIds",
    "ALBSecurityGroupId=$albSecurityGroupId",
    "ECSSecurityGroupId=$ecsSecurityGroupId",
    "DBEndpoint=$dbEndpoint",
    "DBSecretArn=$dbSecretArn"
) -UseIamCapabilities
$albDnsName = Get-StackOutput $backendStack 'ALBEndpoint' $Region
$albHostedZoneId = Get-StackOutput $backendStack 'ALBCanonicalHostedZoneID' $Region
$albFullName = Get-StackOutput $backendStack 'ALBFullName' $Region
$ecsClusterName = Get-StackOutput $backendStack 'ECSClusterName' $Region
$ecsServiceName = Get-StackOutput $backendStack 'ECSServiceName' $Region

Deploy-Stack $observabilityStack '08-observability.yaml' 'prod-observability.json' $Region @(
    "VpcId=$vpcId",
    "ALBFullName=$albFullName",
    "ECSClusterName=$ecsClusterName",
    "ECSServiceName=$ecsServiceName",
    "DBInstanceIdentifier=$dbInstanceIdentifier"
) -UseIamCapabilities

Deploy-Stack $frontendStack '05-frontend.yaml' 'prod-frontend.json' $Region @(
    "WebACLArn=$webAclArn",
    "CloudFrontCertificateArn=$cloudFrontCertificateArn"
)
$cloudFrontDomainName = Get-StackOutput $frontendStack 'CloudFrontDomainName' $Region

Deploy-Stack $dnsStack '06-dns.yaml' 'prod-dns.json' $Region @(
    "HostedZoneId=$hostedZoneId",
    "CloudFrontDomainName=$cloudFrontDomainName",
    "ALBDNSName=$albDnsName",
    "ALBCanonicalHostedZoneID=$albHostedZoneId"
)

Write-Host 'Production deployment completed successfully.'
