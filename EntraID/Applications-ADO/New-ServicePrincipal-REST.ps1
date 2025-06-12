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
    # Json file containing the Application details
    [Parameter(mandatory=$true)]
    [string]$AppJsonFile,
    # Json file containing the Staging Service Principal details (optional)
    [Parameter(mandatory=$false)]
    [string]$SPJsonFile,
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
if ($SPJsonFile -like ".\*"){
    $SPJsonFile = $scriptPath+$SPJsonFile.substring(1) 
}
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if ($AppJsonFile -like ".\*"){
    $AppJsonFile = $scriptPath+$AppJsonFile.substring(1) 
}
#>

write-host "Creating Service Principal from app manifest json file path- $AppJsonFile" -ForegroundColor Green

$spObj = Get-content -Path $SPJsonFile -RAW | ConvertFrom-Json
$appObj = Get-content -Path $AppJsonFile -RAW | ConvertFrom-Json
$spObj | Add-Member -MemberType NoteProperty -Name "appId"  -Value $($appObj.appId)
$spObj | Add-Member -MemberType NoteProperty -Name "appRoleAssignmentRequired"  -Value "true"

$json = $spObj | ConvertTo-Json -Depth 8

$URI = 'https://graph.microsoft.com/beta/servicePrincipals'
$SP = MSGraphRequest -Method Post -URI $URI -Body $json

$SP| Format-List id, DisplayName, AppId, SignInAudience
Write-host "Service Principal created successfully" -ForegroundColor Green
$OutPutJson = $SP | ConvertTo-Json -Depth 20
$fileName =  ".\EntraID\Applications-ADO\$Environment\Apps-States\"+$($SP.displayName)+"_"+$($SP.appid)+"_ServicePrincipal.json"
Write-Host "##vso[task.setvariable variable=newSPJsonFilePath;]$fileName"
$OutPutJson | Out-File -FilePath $fileName
Write-host "Service Principal detail output to - $fileName" -ForegroundColor Green

Disconnect-mggraph
Write-host "Disconnected from MS Graph" -ForegroundColor Green
<#
Write-Host "Service Principal object ID: $($result.id)" -ForegroundColor Green
write-host "Service Principal App ID: $($result.appId)" -ForegroundColor Green
write-host "Service Principal Display Name: $($result.displayName)" -ForegroundColor Green
write-host "Service Principal Sign In Audience: $($result.signInAudience)" -ForegroundColor Green
#>