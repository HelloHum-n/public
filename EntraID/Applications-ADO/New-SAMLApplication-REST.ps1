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
    # Json file containing the application details (Hint: Create one in staging folder)
    [Parameter(mandatory=$true)]
    [string]$JsonFile,
    [Parameter(mandatory=$true)]
    [string]$tenantID,
    # Client ID of the Service Principal to be used for authentication
    [Parameter(mandatory=$true)]
    [string]$ClientID,
    # Certificate of the Service Principal to be used for authentication
    [Parameter(mandatory=$true)]
    [string]$certFile,
    # Password of the certificate to be used for authentication
    [Parameter(mandatory=$true)]
    [string]$CertPwd,
    # Environment (IST,Prod)
    [Parameter(mandatory=$true)]
    [string]$Environment
)
<#
# Install PS modules
$modulesRequired = @('Microsoft.Graph.Authentication')
foreach( $moduleName in $modulesRequired){
    $module = Get-InstalledModule -Name $moduleName -erroraction 'silentlycontinue'
 
    if ( $module -eq $null) {
        Write-Output "Installing PowerShell Module: $moduleName"
        Install-Module -Name $moduleName -Force -AllowClobber
    }else{
        Write-Output "Found installed PowerShell Module: $moduleName"
    }
}
#>

$scopes = 'Application.ReadWrite.All'
$graphThrottleRetry = 20

function MSGraphRequest{
    param($URI,$Method,$Body)
    $i = 0
    do{
        if ($body -eq $null){    
            $fn_result = Invoke-MGGraphRequest -Method $method -Uri $URI -ErrorAction SilentlyContinue -ErrorVariable Err
        }else{
            $fn_result = Invoke-MGGraphRequest -Method $method -Uri $URI -Body $body -Headers  @{'Content-type' = 'application/json' }  -ErrorAction SilentlyContinue -ErrorVariable Err
        }
        if($err -contains "TooManyRequests") {
            # Pausing to avoid Graph throttle 
            Start-Sleep -Seconds 30
        }
        $i++
    }while ( ($err -contains "TooManyRequests") -and ($i -lt $graphThrottleRetry) )
    if ($fn_result -eq $null){$fn_result = $Err}
    return $fn_result
}

$pwdSecure = ConvertTo-SecureString -String $CertPwd -Force -AsPlainText
$connectionCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certFile,$pwdSecure)

Write-Host "Connecting to MS Graph....." -ForegroundColor Green
Connect-MgGraph -TenantId $tenantID -ClientID $ClientID -Certificate $connectionCert

<#
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if ($JsonFile -like ".\*"){
    $JsonFile = $scriptPath+$JsonFile.substring(1) 
}
#>

$bodyObj = Get-content -Path $JsonFile -RAW | ConvertFrom-Json
$bodyObj.PSObject.Properties.Remove('@odata.context')
$json = $bodyObj | ConvertTo-Json -Depth 8

$URI = "https://graph.microsoft.com/beta/applicationTemplates?`$filter=displayName eq 'Custom'"
$appTemplate = MSGraphRequest -Method Get -URI $URI
$appTemplateId = $appTemplate.value[0].id
$URI = "https://graph.microsoft.com/beta/applicationTemplates/$appTemplateId/instantiate"
$body =@"
{
    "displayName": "$($bodyObj.displayName)"
}
"@

Write-Host "Creating New Application from app template id: $appTemplateId ..." -ForegroundColor Green
$AppObj = MSGraphRequest -Method Post -URI $URI -Body $json
$URI = "https://graph.microsoft.com/beta/applications/$($app.application.id)"

$($AppObj.application) | Format-List id, DisplayName, AppId, SignInAudience
Write-host "Application object created successfully" -ForegroundColor Green
$OutPutJson = $($AppObj.application) | Sort-Object | ConvertTo-Json -Depth 20
$AppObj.PSObject.Properties.Remove('@odata.context')
$fileName = ".\EntraID\Applications-ADO\$Environment\Apps-States\"+$($AppObj.application.displayName)+"_"+$($AppObj.application.appid)+"_Application.json"
Write-Host "##vso[task.setvariable variable=newAppJsonFilePath;]$fileName"
$OutPutJson | Out-File -FilePath $fileName 
Write-host "Application manifest output to - $fileName" -ForegroundColor Green

$($AppObj.ServicePrincipal) | Format-List id, DisplayName, AppId, SignInAudience
Write-host "Service Principal object created successfully" -ForegroundColor Green
$OutPutJson = $($AppObj.ServicePrincipal) | Sort-Object | ConvertTo-Json -Depth 20
$AppObj.PSObject.Properties.Remove('@odata.context')
$fileName = ".\EntraID\Applications-ADO\$Environment\Apps-States\"+$($AppObj.ServicePrincipal.displayName)+"_"+$($AppObj.ServicePrincipal.appid)+"_ServicePrincipal.json"
Write-Host "##vso[task.setvariable variable=newSPJsonFilePath;]$fileName"
$OutPutJson | Out-File -FilePath $fileName
Write-host "Service Principal detail output to - $fileName" -ForegroundColor Green
Disconnect-mggraph
Write-host "Disconnected from MS Graph" -ForegroundColor Green