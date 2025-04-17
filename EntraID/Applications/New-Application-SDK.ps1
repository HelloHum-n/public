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

#$tenantID = "d6efb6af-13e5-4903-bf0b-b6e5dc81aae3"
$scopes = 'Application.ReadWrite.All'

Write-Host "Connecting to MS Graph, please sign in via the pop up browser window." -ForegroundColor Green
Connect-MgGraph -TenantId $tenantID -Scopes $scopes

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if ($JsonFile -like ".\*"){
    $JsonFile = $scriptPath+$JsonFile.substring(1) 
}

$bodyObj = Get-content -Path $JsonFile -RAW | ConvertFrom-Json

$DisplayName = $bodyObj.displayName
$Description = $bodyObj.description
$SigninAudience = $bodyObj.signInAudience 


#IMicrosoftGraphInformationalUrl
$InfoUrl = @{}
$key = "marketingUrl"
$value = $bodyObj.info.marketingUrl
$InfoUrl.Add($key,$value)
$key = "privacyStatementUrl"
$value = $bodyObj.info.privacyStatementUrl
$InfoUrl.Add($key,$value)
$key = "termsOfServiceUrl"
$value = $bodyObj.info.termsOfServiceUrl
$InfoUrl.Add($key,$value)
$key = "supportUrl"
$value = $bodyObj.info.supportUrl
$InfoUrl.Add($key,$value)

#IMicrosoftGraphApiApplication 
$APIHash = @{}
$key = "acceptMappedClaims"
$value = $bodyObj.api.acceptMappedClaims
$APIHash.Add($key,$value)
$key = "requestedAccessTokenVersion"
$value = $bodyObj.api.requestedAccessTokenVersion
$APIHash.Add($key,$value)

#IMicrosoftGraphServicePrincipalLockConfiguration
$servicePrincipalLockConfiguration = @{}
$key = "isEnabled"
$value = $bodyObj.servicePrincipalLockConfiguration.isEnabled
$servicePrincipalLockConfiguration.Add($key,$value)
$key = "allProperties"
$value = $bodyObj.servicePrincipalLockConfiguration.allProperties
$servicePrincipalLockConfiguration.Add($key,$value)
$key = "credentialsWithUsageVerify"
$value = $bodyObj.servicePrincipalLockConfiguration.credentialsWithUsageVerify
$servicePrincipalLockConfiguration.Add($key,$value)
$key = "credentialsWithUsageSign"
$value = $bodyObj.servicePrincipalLockConfiguration.credentialsWithUsageSign
$servicePrincipalLockConfiguration.Add($key,$value)
$key = "identifierUris"
$value = $bodyObj.servicePrincipalLockConfiguration.identifierUris
$servicePrincipalLockConfiguration.Add($key,$value)
$key = "tokenEncryptionKeyId"
$value = $bodyObj.servicePrincipalLockConfiguration.tokenEncryptionKeyId
$servicePrincipalLockConfiguration.Add($key,$value)

#Create New Application
$app = New-MgApplication -DisplayName $DisplayName -Description $Description -SignInAudience $SigninAudience -Info $InfoUrl -Api $APIHash -ServicePrincipalLockConfiguration $servicePrincipalLockConfiguration
$app | Format-List id, DisplayName, AppId, SignInAudience
$app.PSObject.Properties.Remove('@odata.context')
Write-host "Application created successfully" -ForegroundColor Green
$OutPutJson = $app | ConvertTo-Json -Depth 8
$fileName = "App-"+$($app.DisplayName)+".json"
$OutPutJson | Out-File -FilePath $fileName 
Write-host "Application manifest output to - $fileName" -ForegroundColor Green
Disconnect-mggraph -Verbose     
Write-host "Disconnected from MS Graph" -ForegroundColor Green