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
    # Json file containing the Service Principal details
    [Parameter(Position=1,mandatory=$true)]
    [string]$SPJsonFile,
    # Json file containing the Service Principal details
    [Parameter(Position=2,mandatory=$true)]
    [string]$ClaimsMappingObjectJsonFile,
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
#$tenantID = "d6efb6af-13e5-4903-bf0b-b6e5dc81aae3"
$graphThrottleRetry = 20

function MSGraphRequest{
    param($URI,$Method,$Body)
    $i = 0
    do{
        if ($body -eq $null){    
            $fn_result = Invoke-MGGraphRequest -Method $method -Uri $URI -OutputType PSObject -ErrorAction SilentlyContinue -ErrorVariable Err
        }else{
            $fn_result = Invoke-MGGraphRequest -Method $method -Uri $URI -Body $body -OutputType PSObject -Headers  @{'ConsistencyLevel' = 'eventual' ; 'Content-type' = 'application/json' }  -ErrorAction SilentlyContinue -ErrorVariable Err
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

Write-Host "Connecting to MS Graph, please sign in via the pop up browser window." -ForegroundColor Green
Connect-MgGraph -TenantId $tenantID -ClientID $ClientID -Certificate $connectionCert

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if ($ClaimsMappingObjectJsonFile -like ".\*"){
    $ClaimsMappingObjectJsonFile = $scriptPath+$ClaimsMappingObjectJsonFile.substring(1) 
}
if ($SPJsonFile -like ".\*"){
    $SPJsonFile = $scriptPath+$SPJsonFile.substring(1) 
}

$CMPobj = Get-content -Path $ClaimsMappingObjectJsonFile -RAW | ConvertFrom-Json
$CMPobj.id

$SPobj = Get-content -Path $SPJsonFile -RAW | ConvertFrom-Json
$SPobj.id

$URI = "https://graph.microsoft.com/beta/servicePrincipals/$($SPobj.id)/claimsMappingPolicies/`$ref"

$body =@"
    {
        "@odata.id": "https://graph.microsoft.com/beta/policies/claimsMappingPolicies/$($CMPobj.id)"
    }
"@

MSGraphRequest -Method Post -URI $URI -Body $body
write-host "Claims Mapping Policy assigned to Service Principal" -ForegroundColor Green

Disconnect-mggraph
Write-host "Disconnected from MS Graph" -ForegroundColor Green