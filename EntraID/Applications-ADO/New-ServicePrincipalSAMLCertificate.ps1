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
    [string]$JsonFile,
    # CER certificate file (Public Key)
    [Parameter(Position=2,mandatory=$true)]
    [string]$cerCertFile,
    # Private Key pfx file (Private Key)
    [Parameter(Position=3,mandatory=$true)]
    [string]$PfxFile,
    # Priate Key password file
    [Parameter(Position=4,mandatory=$true)]
    [string]$privateKeyPwd,
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

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if ($JsonFile -like ".\*"){
    $JsonFile = $scriptPath+$JsonFile.substring(1) 
}
if ($CertFile -like ".\*"){
    $CertFile = $scriptPath+$CertFile.substring(1) 
}
if ($PfxFile -like ".\*"){
    $PfxFile = $scriptPath+$PfxFile.substring(1) 
}

$inputObj = Get-content -Path $JsonFile -RAW | ConvertFrom-Json
$inputObj.PSObject.Properties.Remove('@odata.context')
$json = $inputObj | ConvertTo-Json -Depth 20     
$URI = 'https://graph.microsoft.com/v1.0/servicePrincipals'+"/$($inputObj.id)"

# Get the Thumbprint,subject and timestampes of the certificate
$CERobj = Get-PfxCertificate -Filepath $cerCertFile 
$Thumbprint = $CERobj.Thumbprint
$subject = $CERobj.Subject
$startTime = $CERobj.NotBefore.ToUniversalTime().ToString("o")
$endTime = $CERobj.NotAfter.ToUniversalTime().ToString("o")
#$startTime = $startTime.Replace(".0000000","")
#$endTime = $endTime.Replace(".0000000","")
$startTime = $startTime -replace '\..*', ''
$startTime = $startTime+"z"
$endTime = $endTime -replace '\..*', ''
$endTime = $endTime+"z"

# Get the public key from the certificate file (CER file)

if ( $($PSVersionTable.PSVersion.Major) -eq 7 ){
    $publicKey = [convert]::ToBase64String((Get-Content $cerCertFile -AsByteStream -Raw)) 
    $privateKey = [convert]::ToBase64String((Get-Content $PfxFile -AsByteStream -Raw)) 
}else{
    $publicKey = [convert]::ToBase64String((Get-Content $cerCertFile -Encoding Byte))
    $privateKey = [convert]::ToBase64String((Get-Content $PfxFile -Encoding Byte))  
}

# Get the private key from the PEM file (PEM file)
<#
$pemContent = Get-Content -Path $PemFile -Raw
$privateKeyStart = "-----BEGIN PRIVATE KEY-----"
$privateKeyEnd = "-----END PRIVATE KEY-----"
$startIndex = $pemContent.IndexOf($privateKeyStart)
$endIndex = $pemContent.IndexOf($privateKeyEnd) + $privateKeyEnd.Length
if ($startIndex -ge 0 -and $endIndex -gt $startIndex) {
    $privateKey = $pemContent.Substring($startIndex, $endIndex - $startIndex)
    $privateKey = $privateKey.Replace("-----BEGIN PRIVATE KEY-----","")
    $privateKey = $privateKey.Replace("-----END PRIVATE KEY-----","")
    $privateKey = $privateKey.Replace("`n","")
    Write-Host "Private key extracted successfully"
} else {
    Write-Host "Could not find private key block in the PEM file."
}
#>
$privateKey = $privateKey.Replace("`n","")
$publicKey = $publicKey.Replace("`n","")
# Construct the body for the PATCH request
$GUID = $(New-Guid).Guid

$body = @"
{
    "keyCredentials": [
        {
            "customKeyIdentifier": "$Thumbprint",
            "endDateTime": "$endTime",
            "keyId": "$GUID",
            "startDateTime": "$startTime",
            "type": "AsymmetricX509Cert",
            "usage": "Sign",
            "key": "$privateKey",
            "displayName": "$subject"
        },
        {
            "customKeyIdentifier": "$Thumbprint",
            "endDateTime": "$endTime",
            "keyId": "$((New-Guid).Guid)",
            "startDateTime": "$startTime",
            "type": "AsymmetricX509Cert",
            "usage": "Verify",
            "key": "$publicKey",
            "displayName": "$subject"
        }
    ],
    "passwordCredentials": [
        {
            "customKeyIdentifier": "$Thumbprint",
            "keyId": "$GUID",
            "endDateTime": "$endTime",
            "startDateTime": "$startTime",
            "secretText": "$privateKeyPwd"
        }
    ]
}
"@


Write-Host "Patching the following body for certificate upload"
$body 
#$body |  Out-File -FilePath body.txt -Force
#exit


$SP = MSGraphRequest -Method PATCH -URI $URI -Body $body
$SP | Format-List id, DisplayName, AppId
Write-host "Service Principal updated successfully" -ForegroundColor Green  
$OutPutJson = $SP | ConvertTo-Json -Depth 20
$fileName = "$Environment\Apps-States\ServicePrincipal-"+$($SP.displayName)+"-"+$($SP.Id)+".json"
Write-Host "##vso[task.setvariable variable=customClaimsJson;issecret=true]$fileName"
$OutPutJson | Out-File -FilePath $fileName -Force
Write-host "ServicePrincipal detail output to - $fileName" -ForegroundColor Green

Disconnect-mggraph
Write-host "Disconnected from MS Graph" -ForegroundColor Green
