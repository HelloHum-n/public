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
    # Json file containing the existing Application details
    [Parameter(mandatory=$true)]
    [string]$JsonFile,
    # Json file containing the new SApplication details (OPTIONAL)
    [Parameter(mandatory=$false)]
    [string]$newJsonFile,
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
if ($JsonFile -like ".\*"){
    $JsonFile = $scriptPath+$JsonFile.substring(1) 
}
if ($newJsonFile -like ".\*"){
    $newJsonFile = $scriptPath+$newJsonFile.substring(1) 
}
#>

Write-Host "path $JsonFile"
$existingStateJson = Get-content -Path $JsonFile -RAW
$existingStateObj = $existingStateJson | ConvertFrom-Json
$existingStateObj.PSObject.Properties.Remove('@odata.context')
write-host "Json content of the input file:"
Write-host $existingStateJson
$GUID = $(New-Guid).Guid
write-host "Using $GUID for Service Principal's notes property for verification" -ForegroundColor Green
$newAppStateObj = Get-content -Path $newJsonFile -RAW | ConvertFrom-Json

# Get the Service Principal properties in Json
#$SPobj = MSGraphRequest -Method GET -URI $URI
#$SPobj.PSObject.Properties.Remove('@odata.context')

<#
Insert comparing json file codes here
https://github.com/orenshatech/PowerShell-Scripts/blob/main/CompareNestedJsonFiles.ps1
#>


$newAppStateObj | Add-Member -MemberType NoteProperty -Name "notes"  -Value $GUID
$json = $newAppStateObj | ConvertTo-Json -Depth 20  


# Update the Application properties
write-host "Updating Application via URI $URI and json body: $json" -ForegroundColor Green
MSGraphRequest -Method PATCH -URI $URI -Body $json
$i=0
$maxRetry = 5
while($err){
    $err = $null
    write-host "Updating Service Prinicapl via URI $URI ...  # of retry: $i" -ForegroundColor Green
    Start-Sleep -Seconds 30
    MSGraphRequest -Method PATCH -URI $URI -Body $json
}

Write-Host "Application update in progress, please wait..." -ForegroundColor Green
$maxRetry = 5
$i=0
do {
    Write-Host "Application update in progress, please wait for fetching new properties... # of retry: $i" -ForegroundColor Green
    $AppObj = MSGraphRequest -Method GET -URI $URI
    if ($i -ne 0){
        Start-Sleep -Seconds 30
    }
    $i++
}while($AppObj.notes.ToString() -ne $GUID -and $i -lt $maxRetry)

if ($i -eq $maxRetry){
    Write-host "Application update failed (timed out)" -ForegroundColor Red
    exit 1
}

$AppObj | Format-List id, DisplayName, AppId, notes
Write-host "Application updated successfully" -ForegroundColor Green  
$OutPutJson = $AppObj | ConvertTo-Json -Depth 20
#$fileName = "$Environment\Apps-States\Application_"+$($AppObj.displayName)+"_"+$($AppObj.Id)+".json"
$OutPutJson | Out-File -FilePath $JsonFile -Force
Write-host "Application detail output to - $JsonFile" -ForegroundColor Green

Disconnect-mggraph
Write-host "Disconnected from MS Graph" -ForegroundColor Green