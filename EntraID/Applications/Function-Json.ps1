


$json = Get-content -Path "EntraID/Applications/Function-Json.ps1" -RAW | ConvertFrom-Json

$Json | ConvertTo-Json -Depth 4 