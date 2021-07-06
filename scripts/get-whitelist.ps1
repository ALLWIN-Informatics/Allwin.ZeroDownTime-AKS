[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)] [string]$whitelistJsonPath
) 
$results = @()
cat $whitelistJsonPath | ConvertFrom-Json | %{ $results += $_.ranges }
return [system.String]::Join(", ", $results)