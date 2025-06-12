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
    [string]$JsonFile,
    # Public Key cer file to be uploaded
    [Parameter(mandatory=$true)]
    [string]$cerCertFile,
    # Indicate the usage of the certificate (Encrypt,Verify)
    [ValidateSet("Encrypt", "Verify")]
    [Parameter(mandatory=$true)]
    [string]$Usage,
    # Overwrite the current certificates if exists
    [Parameter(mandatory=$false)]
    [string]$certOverwrite = "false",
    # Make the new key to be active ***for token encryption only***
    [Parameter(mandatory=$false)]
    [string]$makeActive = "false",
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

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if ($JsonFile -like ".\*"){
    $JsonFile = $scriptPath+$JsonFile.substring(1) 
}
if ($CertFile -like ".\*"){
    $CertFile = $scriptPath+$CertFile.substring(1) 
}
if ($cerCertFile -like ".\*"){
    $cerCertFile = $scriptPath+$cerCertFile.substring(1) 
}

$pwdSecure = ConvertTo-SecureString -String $CertPwd -Force -AsPlainText
$connectionCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certFile,$pwdSecure)

Write-Host "Connecting to MS Graph....." -ForegroundColor Green
Connect-MgGraph -TenantId $tenantID -ClientID $ClientID -Certificate $connectionCert



$inputObj = Get-content -Path $JsonFile -RAW | ConvertFrom-Json
$inputObj.PSObject.Properties.Remove('@odata.context')
#$json = $inputObj | ConvertTo-Json -Depth 20     

# Get the keys from the certificate file (cer file)
if ( $($PSVersionTable.PSVersion.Major) -eq 7 ){
    $publicKey = [convert]::ToBase64String((Get-Content $cerCertFile -AsByteStream Raw))
}else{
    $publicKey = [convert]::ToBase64String((Get-Content $cerCertFile -Encoding Byte)) 
}
# Get the Thumbprint,subject and timestampes of the certificate
$CERobj = Get-PfxCertificate -Filepath $cerCertFile 
$Thumbprint = $CERobj.Thumbprint
$subject = $CERobj.Subject
$certStartTime = $CERobj.NotBefore.ToUniversalTime().ToString("o")
$certEndTime = $CERobj.NotAfter.ToUniversalTime().ToString("o")
$certStartTime = $certStartTime -replace '\..*', ''
$certStartTime = $certStartTime+"z"
$certEndTime = $certEndTime -replace '\..*', ''
$certEndTime = $certEndTime+"z"
$publicKey = $publicKey.Replace("`n","")
$encryptKeyGUID = $(New-Guid).Guid

# Construct the body for the PATCH request
if ($certOverwrite -eq "true"){

    if ($makeActive -eq "true" -and $Usage -eq "Encrypt"){
$body = @"
{
    "keyCredentials": [
        {
            "customKeyIdentifier": "$Thumbprint",
            "endDateTime": "$certEndTime",
            "keyId": "$encryptKeyGUID ",
            "startDateTime": "$certStartTime",
            "type": "AsymmetricX509Cert",
            "usage": "$Usage",
            "key": "$publicKey",
            "displayName": "$subject"
        }
    ],
    "tokenEncryptionKeyId": "$encryptKeyGUID"
}
"@
    }else{
$body = @"
{
    "keyCredentials": [
        {
            "customKeyIdentifier": "$Thumbprint",
            "endDateTime": "$certEndTime",
            "keyId": "$encryptKeyGUID",
            "startDateTime": "$certStartTime",
            "type": "AsymmetricX509Cert",
            "usage": "$Usage",
            "key": "$publicKey",
            "displayName": "$subject"
        }
    ]
}
"@
    }
    


    #Write-Host "Patching the following body for certificate upload"
    #$body 
    $URI = 'https://graph.microsoft.com/beta/applications'+"/$($inputObj.id)"
    $output = MSGraphRequest -Method PATCH -URI $URI -Body $body

}else{

    # Get the existing keyCredentials
    $URI = "https://graph.microsoft.com/beta/applications/$($inputObj.id)?`$select=keyCredentials"
    $AppObj = MSGraphRequest -Method GET -URI $URI
    $AppObj  = $AppObj | ConvertTo-Json -Depth 20 | ConvertFrom-Json 
    $AppObj.PSObject.Properties.Remove('@odata.context')
    $AppObj.keyCredentials | foreach {$_.key = $null}
    foreach ( $obj in $($AppObj.keyCredentials)) {
        $startTime = $($obj.startDateTime).ToUniversalTime().ToString("o")
        $startTime = $startTime -replace '\..*', ''
        $startTime = $startTime+"z"
        $obj.startDateTime = $startTime
        $endTime = $($obj.endDateTime).ToUniversalTime().ToString("o")
        $endTime = $endTime -replace '\..*', ''
        $endTime = $endTime+"z"
        $obj.endDateTime = $endTime
    }
    
    $newObj = New-Object PSObject
    $newObj | Add-Member -MemberType NoteProperty -Name "customKeyIdentifier"  -Value "$Thumbprint"
    $newObj | Add-Member -MemberType NoteProperty -Name "endDateTime"  -Value "$certEndTime"
    $newObj | Add-Member -MemberType NoteProperty -Name "keyId"  -Value "$encryptKeyGUID"
    $newObj | Add-Member -MemberType NoteProperty -Name "startDateTime"  -Value "$certStartTime"
    $newObj | Add-Member -MemberType NoteProperty -Name "type"  -Value "AsymmetricX509Cert"
    $newObj | Add-Member -MemberType NoteProperty -Name "key"  -Value "$publicKey"
    $newObj | Add-Member -MemberType NoteProperty -Name "displayName"  -Value "$subject"
    $newObj | Add-Member -MemberType NoteProperty -Name "usage"  -Value "$usage"
    $AppObj.keyCredentials += $newObj

    if ($makeActive -eq "true -and $Usage -eq "Encrypt"){
        $AppObj  | Add-Member -MemberType NoteProperty -Name 'tokenEncryptionKeyId' -Value $encryptKeyGUID
    }
    $SpKeyCredJson = $AppObj | ConvertTo-Json -Depth 20
    #Write-Host "Patching the following body for certificate upload"
    #Write-Host "$SpKeyCredJson"
    #pause
    $URI = 'https://graph.microsoft.com/beta/applications/'+"$($inputObj.id)"
    #MSGraphRequest -Method PATCH -URI $URI -Body $body
    Invoke-MGGraphRequest -Method PATCH -Uri $URI -Body $SpKeyCredJson
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
}while( (-not $AppObj.keyCredentials.keyId.Contains("$encryptKeyGUID")) -and $i -lt $maxRetry)

if ($i -eq $maxRetry){
    Write-host "Application update failed (timed out)" -ForegroundColor Red
    exit 1
}

Write-host "Application updated successfully" -ForegroundColor Green  
$OutPutJson = $AppObj | ConvertTo-Json -Depth 20
$fileName = "$Environment\Apps-States\"+$($AppObj.displayName)+"_"+$($AppObj.appId)+"_Application.json"
Write-Host "##vso[task.setvariable variable=customClaimsJson;issecret=true]$fileName"
$OutPutJson | Out-File -FilePath $fileName -Force
Write-host "AppObj detail output to - $fileName" -ForegroundColor Green
Disconnect-mggraph
Write-host "Disconnected from MS Graph" -ForegroundColor Green
