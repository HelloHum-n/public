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
    [Parameter(mandatory=$true)]
    [string]$tenantID,
    # Json file containing the application details (Hint: Create one in staging folder)
    [Parameter(mandatory=$true)]
    [string]$JsonFile,
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
            $fn_result = Invoke-MGGraphRequest -Method $method -Uri $URI -OutputType PSObject -ErrorAction SilentlyContinue -ErrorVariable Err
        }else{
            $fn_result = Invoke-MGGraphRequest -Method $method -Uri $URI -Body $body -OutputType PSObject -Headers @{'ConsistencyLevel' = 'eventual' }  -ErrorAction SilentlyContinue -ErrorVariable Err
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

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if ($JsonFile -like ".\*"){
    $JsonFile = $scriptPath+$JsonFile.substring(1) 
}

$bodyObj = Get-content -Path $JsonFile -RAW | ConvertFrom-Json

#Modify json property
#$bodyObj.displayName = "New App 03"
#$bodyObj.description = "New application Description"
$json = $bodyObj | ConvertTo-Json -Depth 8

$URI = 'https://graph.microsoft.com/v1.0/applications'
$app = MSGraphRequest -Method Post -URI $URI -Body $json
$app | Format-List id, DisplayName, AppId, SignInAudience
$app.PSObject.Properties.Remove('@odata.context')
Write-host "Application created successfully" -ForegroundColor Green
$OutPutJson = $app | ConvertTo-Json -Depth 8

$fileName = "$Environment\Apps-States\Application-"+$($app.displayName)+"-"+$($app.Id)+".json"
Write-Host "##vso[task.setvariable variable=newAppJsonFilePath;]$fileName"
$OutPutJson | Out-File -FilePath $fileName 
Write-host "Application manifest output to - $fileName" -ForegroundColor Green
Disconnect-mggraph
Write-host "Disconnected from MS Graph" -ForegroundColor Green