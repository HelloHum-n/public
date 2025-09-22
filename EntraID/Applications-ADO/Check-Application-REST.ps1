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
    # Application ID of the Application to be retrieved
    [Parameter(mandatory=$false)]
    [string]$ApplicationID = "00000000-0000-0000-0000-000000000000",
    # Application Name of the Application to be retrieved
    [Parameter(mandatory=$true)]
    [string]$ApplicationName,
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

#$scopes = 'Application.ReadWrite.All'
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

if ( $ApplicationID -ne "00000000-0000-0000-0000-000000000000"){
    $URI = "https://graph.microsoft.com/beta/applications(appId=`'{$ApplicationID}`')"
    #$URI = "https://graph.microsoft.com/v1.0/applications?`$filter=appId+eq+`'$ApplicationID`'"
    $AppObjFromID = MSGraphRequest -Method GET -URI $URI
}else{
    $AppObjFromID = $null
}
$URI = "https://graph.microsoft.com/v1.0/applications?`$filter=displayName+eq+`'$ApplicationName`'"
$AppObjFromName = MSGraphRequest -Method GET -URI $URI
Disconnect-mggraph
Write-host "Disconnected from MS Graph" -ForegroundColor Green

if ( ($AppObjFromName.value.count) -gt 1 ){
    $result = "Multiple apps found with provided App Name on Entra" 
}elseif( ($AppObjFromName.value.count) -eq 1 -and ($AppObjFromName.value.AppId) -eq $ApplicationID ){
    $result = "Application found with matching Name and ID on Entra"
}elseif( ($AppObjFromName.value.count) -eq 1 -and ($AppObjFromName.value.AppId) -ne $ApplicationID ){
    $result = "Application found with matching Name but doesn't match the provided AppId on Entra"
}elseif( ($AppObjFromName.value.count) -eq 0 -and $AppObjFromID -like '*{"error"*'){
    $result = "Both provided Application ID and Appication name not found on Entra"
}else{
    $result = "Application found with matching ID but doesn't match the provided App Name on Entra"
} 

Write-Host $result 
Write-Host "##vso[task.setvariable variable=appCheckResult]$result" 
