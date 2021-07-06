[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)] [string]$chartName,
	[Parameter(Mandatory=$true)] [string]$valuesFilePath,
	[Parameter(Mandatory=$true)] [string]$serviceName,
	[Parameter(Mandatory=$true)] [string]$namespace,
	[Parameter(Mandatory=$true)] [string]$dockerImageTag,
	[Parameter(Mandatory=$true)] [string]$url,
	[Parameter(Mandatory=$true)] [string]$tlsSecretName,
	[Parameter()] [string]$whitelistSourceRange = '{}',
	[Parameter()][ValidateSet('Off', 'On', 'DetectionOnly')][string]$firewallMode='Off'
) 

$json = helm list -n $namespace -o json | ConvertFrom-Json
$helmReleases = $json | where { ($_.name -eq "$serviceName-blue") -or ($_.name -eq "$serviceName-green")} | select -ExpandProperty name
Write-Host "Helm blue/green releases found with prefix ""$serviceName-"":"
foreach ($helmRelease in $helmReleases)
{ 
	Write-Host $helmRelease 
}

$slot = 'blue'
$slotInUse = 'blue'
if ($helmReleases.count -gt 1)
{
	Write-Error "There are more than one releases with name prefix $serviceName. Please remove the unused ones manually to continue."
	exit 1
}
elseif ($helmReleases.count -eq 1)
{
	$slotInUse = $helmReleases -replace "$serviceName-", ''
	if($slotInUse -eq 'blue')
	{
		$slot = 'green'
	}
}

(Get-Content .\charts\ingress\values.yaml) -replace 'whitelistSourceRange: {}', "whitelistSourceRange: ""$whitelistSourceRange""" | Out-File .\charts\ingress\values.yaml
(Get-Content .\charts\ingress\values.yaml) -replace 'SecRuleEngine Off', "SecRuleEngine $firewallMode" | Out-File .\charts\ingress\values.yaml

Write-Host "Upgrading $serviceName-ingress ingress."
helm upgrade --install "$serviceName-ingress" ./charts/ingress --namespace $namespace --set service.name=$serviceName,service.selectorLabels.app=$serviceName,service.selectorLabels.slot=$slotInUse,service.selectorCanaryLabels.app=$serviceName,service.selectorCanaryLabels.slot=$slot,ingress.name="$serviceName-ingress",ingress.hosts[0]=$url,ingress.tls[0].hosts[0]=$url,ingress.tls[0].secretName=$tlsSecretName

Write-Host "New release will be deployed to $slot slot."
helm upgrade --install "$serviceName-$slot" "./charts/$chartName" --namespace $namespace -f $valuesFilePath --set image.tag=$dockerImageTag,slot=$slot

Set-Variable -Name 'slot' -Value $slot -Scope 1


