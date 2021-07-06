[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)] [string]$serviceName,
	[Parameter(Mandatory=$true)] [string]$namespace,
	[Parameter(Mandatory=$true)] [string]$url,
	[Parameter(Mandatory=$true)] [string]$tlsSecretName,
	[Parameter()] [string]$whitelistSourceRange = '{}',
	[Parameter(Mandatory=$true)] [string]$slot,
	[Parameter()][ValidateSet('Off', 'On', 'DetectionOnly')][string]$firewallMode='Off'
) 

$originalSlot = 'blue'

if($slot -eq 'blue')
{
	$originalSlot = 'green'
}

(Get-Content .\charts\ingress\values.yaml) -replace 'whitelistSourceRange: {}', "whitelistSourceRange: ""$whitelistSourceRange""" | Out-File .\charts\ingress\values.yaml
(Get-Content .\charts\ingress\values.yaml) -replace 'SecRuleEngine Off', "SecRuleEngine $firewallMode" | Out-File .\charts\ingress\values.yaml

Write-Host "Upgrading $serviceName-ingress ingress."
helm upgrade --install "$serviceName-ingress" ./charts/ingress --namespace $namespace --set service.name=$serviceName,service.selectorLabels.app=$serviceName,service.selectorLabels.slot=$originalSlot,service.selectorCanaryLabels.app=$serviceName,service.selectorCanaryLabels.slot=$originalSlot,ingress.name="$serviceName-ingress",ingress.hosts[0]=$url,ingress.tls[0].hosts[0]=$url,ingress.tls[0].secretName=$tlsSecretName

$json = helm list -n $namespace -o json | ConvertFrom-Json
$helmReleases = $json | where { $_.name -eq "$serviceName-$slot" } | select -ExpandProperty name

if ($helmReleases.count -eq 0)
{
	Write-Host "There is no $serviceName release on $slot slot."
	exit 0
}

Write-Host "Uninstalling $serviceName release from $slot slot."
helm uninstall "$serviceName-$slot" --namespace $namespace