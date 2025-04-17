<#

=========================================================================================================================

 Disclaimer:

 This sample script is not supported under any Microsoft standard support program or service. 
 The sample script is provided AS IS without warranty of any kind. Microsoft further disclaims 
 all implied warranties including, without limitation, any implied warranties of merchantability 
 or of fitness for a particular purpose. The entire risk arising out of the use or performance of 
 the sample scripts and documentation remains with you. In no event shall Microsoft, its authors, 
 or anyone else involved in the creation, production, or delivery of the scripts be liable for any 
 damages whatsoever (including, without limitation, damages for loss of business profits, business 
 interruption, loss of business information, or other pecuniary loss) arising out of the use of or 
 inability to use the sample scripts or documentation, even if Microsoft has been advised of the 
 possibility of such damages

 =========================================================================================================================

 Name:   Timothy Mui
 email:  timothy.mui@microsoft.com
#>

param(
    [Parameter(Position=0,mandatory=$true)]
    [string]$tenantID,
    # Json file containing the application details
    [Parameter(Position=1,mandatory=$true)]
    [string]$JsonFile
)

# Install PS modules
$modulesRequired = @('Microsoft.Graph.Authentication','Microsoft.Graph.Applications')
foreach( $moduleName in $modulesRequired){
    $module = Get-InstalledModule -Name $moduleName -erroraction 'silentlycontinue'
 
    if ( $module -eq $null) {
        Write-Output "Installing PowerShell Module: $moduleName"
        Install-Module -Name $moduleName -Force -AllowClobber
    }else{
        Write-Output "Found installed PowerShell Module: $moduleName"
    }
}

$scopes = 'Application.Read.All'
#$tenantID = "d6efb6af-13e5-4903-bf0b-b6e5dc81aae3"

Write-Host "Connecting to MS Graph, please sign in via the pop up browser window." -ForegroundColor Green
Connect-MgGraph -TenantId $tenantID -Scopes $scopes


$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if ($JsonFile -like ".\*"){
    $JsonFile = $scriptPath+$JsonFile.substring(1) 
}
$inputObj = Get-content -Path $JsonFile -RAW | ConvertFrom-Json

$bodyParam = @{
    "appId"= "$($inputObj.appId)"
    "appRoleAssignmentRequired"= "$($inputObj.appRoleAssignmentRequired)"
}


$SP = New-MgServicePrincipal -BodyParameter $bodyParam 
$SP | Format-List id, DisplayName, AppId, SignInAudience
$SP.PSObject.Properties.Remove('@odata.context')
Write-host "Service Principal created successfully" -ForegroundColor Green
$OutPutJson = $SP | ConvertTo-Json -Depth 8
$fileName = "ServicePrincipal-"+$($SP.DisplayName)+".json"
$OutPutJson | Out-File -FilePath $fileName 
Write-host "ServicePrincipal detail output to - $fileName" -ForegroundColor Green

Disconnect-mggraph
Write-host "Disconnected from MS Graph" -ForegroundColor Green