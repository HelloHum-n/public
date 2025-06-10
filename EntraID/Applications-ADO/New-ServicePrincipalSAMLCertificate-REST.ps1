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
    # Json file containing the Service Principal details
    [Parameter(mandatory=$true)]
    [string]$JsonFile,
    # Private Key pfx file to be uploaded (Private Key)
    [Parameter(mandatory=$true)]
    [string]$PfxCertFile,
    # Priate Key password 
    [Parameter(mandatory=$true)]
    [string]$privateKeyPwd,
    # Overwrite the current certificates if exists (String true or false)
    [Parameter(mandatory=$false)]
    [string]$certOverwrite = "false",
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

<#
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if ($JsonFile -like ".\*"){
    $JsonFile = $scriptPath+$JsonFile.substring(1) 
}
if ($CertFile -like ".\*"){
    $CertFile = $scriptPath+$CertFile.substring(1) 
}
if ($PfxCertFile -like ".\*"){
    $PfxCertFile = $scriptPath+$PfxCertFile.substring(1) 
}
#>

$pwdSecure = ConvertTo-SecureString -String $CertPwd -Force -AsPlainText
$connectionCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certFile,$pwdSecure)

Write-Host "Connecting to MS Graph....." -ForegroundColor Green
Connect-MgGraph -TenantId $tenantID -ClientID $ClientID -Certificate $connectionCert



$inputObj = Get-content -Path $JsonFile -RAW | ConvertFrom-Json
$inputObj.PSObject.Properties.Remove('@odata.context')
#$json = $inputObj | ConvertTo-Json -Depth 20     

# Get the keys from the certificate file (pfx file)
$privatePwdSecure = ConvertTo-SecureString -String $privateKeyPwd -Force -AsPlainText
$pfxCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($pfxCertFile,$privatePwdSecure)
#$tmpPubCertFile = ".\"+$((New-Guid).Guid)+".tmp"
$tmpPubCertFile = ".\tempPublickey.cer"
# .\openssl.exe pkcs12 -in "C:\Certificates\abc.com.pfx" -out C:\temp\testing.cer -nokeys -passin pass:"abcde12345" 
#$openSSLcmd = ".\EntraID\Applications-ADO\OpenSSL\openssl.exe pkcs12 -in `'$pfxCertFile`' -out `'$tmpPubCertFile`' -nokeys -passin pass:$privateKeyPwd"
#Invoke-Expression -Command $openSSLcmd
#$exefilePath = ".\EntraID\Applications-ADO\OpenSSL\openssl.exe"
#$args =  " pkcs12 -in $pfxCertFile -out $tmpPubCertFile -nokeys -passin pass:$privateKeyPwd"
#Start-Process -FilePath "$exefilePath" -argumentList $args -Verb RunAs #-WorkingDirectory ".\EntraID\Applications-ADO\Staging\"
#Import-Module -Name ".\EntraID\Applications-ADO\pki.psd1"
$pfxCert | Export-Certificate -FilePath $tmpPubCertFile -Type CERT
if ( $($PSVersionTable.PSVersion.Major) -eq 7 ){
    $publicKey = [convert]::ToBase64String((Get-Content $tmpPubCertFile -AsByteStream -Raw))
    $privateKey = [convert]::ToBase64String((Get-Content $PfxCertFile -AsByteStream -Raw)) 
}else{
    $publicKey = [convert]::ToBase64String((Get-Content $tmpPubCertFile -Encoding Byte))
    $privateKey = [convert]::ToBase64String((Get-Content $PfxCertFile -Encoding Byte))  
}
# Get the Thumbprint,subject and timestampes of the certificate
$CERobj = Get-PfxCertificate -Filepath $tmpPubCertFile 
$Thumbprint = $CERobj.Thumbprint
$subject = $CERobj.Subject
$certStartTime = $CERobj.NotBefore.ToUniversalTime().ToString("o")
$certEndTime = $CERobj.NotAfter.ToUniversalTime().ToString("o")
$certStartTime = $certStartTime -replace '\..*', ''
$certStartTime = $certStartTime+"z"
$certEndTime = $certEndTime -replace '\..*', ''
$certEndTime = $certEndTime+"z"
$privateKey = $privateKey.Replace("`n","")
$publicKey = $publicKey.Replace("`n","")
Remove-Item -Path $tmpPubCertFile -Force

# Construct the body for the PATCH request
if ($certOverwrite -eq "true"){

$signKeyGUID = $(New-Guid).Guid
$body = @"
{
    "keyCredentials": [
        {
            "customKeyIdentifier": "$Thumbprint",
            "endDateTime": "$certEndTime",
            "keyId": "$signKeyGUID",
            "startDateTime": "$certStartTime",
            "type": "AsymmetricX509Cert",
            "usage": "Sign",
            "key": "$privateKey",
            "displayName": "$subject"
        },
        {
            "customKeyIdentifier": "$Thumbprint",
            "endDateTime": "$certEndTime",
            "keyId": "$((New-Guid).Guid)",
            "startDateTime": "$certStartTime",
            "type": "AsymmetricX509Cert",
            "usage": "Verify",
            "key": "$publicKey",
            "displayName": "$subject"
        }
    ],
    "passwordCredentials": [
        {
            "customKeyIdentifier": "$Thumbprint",
            "keyId": "$signKeyGUID",
            "endDateTime": "$certEndTime",
            "startDateTime": "$certStartTime",
            "secretText": "$privateKeyPwd"
        }
    ]
}
"@

    #Write-Host "Patching the following body for certificate upload"
    #$body 
    $URI = 'https://graph.microsoft.com/v1.0/servicePrincipals'+"/$($inputObj.id)"
    $output = MSGraphRequest -Method PATCH -URI $URI -Body $body

}else{

    # Get the existing keyCredentials
    $URI = "https://graph.microsoft.com/beta/servicePrincipals/$($inputObj.id)?`$select=keyCredentials"
    $SpKeyCred = MSGraphRequest -Method GET -URI $URI
    $SpKeyCred  = $SpKeyCred | ConvertTo-Json -Depth 20 | ConvertFrom-Json 
    $SpKeyCred.PSObject.Properties.Remove('@odata.context')
    $SpKeyCred.keyCredentials | foreach {$_.key = $null}
    foreach ( $obj in $($SpKeyCred.keyCredentials)) {
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
    $newObj | Add-Member -MemberType NoteProperty -Name "keyId"  -Value "$((New-Guid).Guid)"
    $newObj | Add-Member -MemberType NoteProperty -Name "startDateTime"  -Value "$certStartTime"
    $newObj | Add-Member -MemberType NoteProperty -Name "type"  -Value "AsymmetricX509Cert"
    $newObj | Add-Member -MemberType NoteProperty -Name "usage"  -Value "Verify"
    $newObj | Add-Member -MemberType NoteProperty -Name "key"  -Value "$publicKey"
    $newObj | Add-Member -MemberType NoteProperty -Name "displayName"  -Value "$subject"
    #$newObj | Add-Member -MemberType NoteProperty -Name "hasExtendedValue"  -Value "false"
    $SpKeyCred.keyCredentials += $newObj

    $signKeyGUID = $(New-Guid).Guid
    $newObj = New-Object PSObject
    $newObj | Add-Member -MemberType NoteProperty -Name "customKeyIdentifier"  -Value "$Thumbprint"
    $newObj | Add-Member -MemberType NoteProperty -Name "endDateTime"  -Value "$certEndTime"
    $newObj | Add-Member -MemberType NoteProperty -Name "keyId"  -Value "$signKeyGUID"
    $newObj | Add-Member -MemberType NoteProperty -Name "startDateTime"  -Value "$certStartTime"
    $newObj | Add-Member -MemberType NoteProperty -Name "type"  -Value "AsymmetricX509Cert"
    $newObj | Add-Member -MemberType NoteProperty -Name "usage"  -Value "Sign"
    $newObj | Add-Member -MemberType NoteProperty -Name "key"  -Value "$privateKey"
    $newObj | Add-Member -MemberType NoteProperty -Name "displayName"  -Value "$subject"
    #$newObj | Add-Member -MemberType NoteProperty -Name "hasExtendedValue"  -Value "false"
    $SpKeyCred.keyCredentials += $newObj

    $URI = "https://graph.microsoft.com/beta/servicePrincipals/$($inputObj.id)?`$select=passwordCredentials"
    $SpPwdCred = MSGraphRequest -Method GET -URI $URI
    $SpPwdCred= $SpPwdCred | ConvertTo-Json -Depth 20 | ConvertFrom-Json 
    if($null -eq $($SpPwdCred.passwordCredentials)){
        $modifyJson = $true    
    }else{
        $modifyJson = $false  
    }
    $SpPwdCred.PSObject.Properties.Remove('@odata.context')
    foreach ( $obj in $($SpPwdCred.passwordCredentials)) {
        $startTime = $null
        $endTime = $null
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
    $newObj | Add-Member -MemberType NoteProperty -Name "keyId"  -Value "$signKeyGUID"
    $newObj | Add-Member -MemberType NoteProperty -Name "startDateTime"  -Value "$certStartTime"
    $newObj | Add-Member -MemberType NoteProperty -Name "secretText"  -Value "$privateKeyPwd"
    $SpPwdCred.passwordCredentials += $newObj

    $SpKeyCred  | Add-Member -MemberType NoteProperty -Name 'passwordCredentials' -Value $($SpPwdCred.passwordCredentials)   
    $SpKeyCredJson = $SpKeyCred | ConvertTo-Json -Depth 20 -Compress

    if($modifyJson){
        $SpKeyCredJson 
        $SpKeyCredJson = $SpKeyCredJson.Replace('"passwordCredentials":','"passwordCredentials":[')
        $SpKeyCredJson = $SpKeyCredJson.Substring(0,$($SpKeyCredJson.Length-1))
        $SpKeyCredJson += "]}"
    }

    Write-Host "Patching the following body for certificate upload"
    Write-Host "$SpKeyCredJson"
    #$SpKeyCredJson |  Out-File -FilePath C:\temp\body.txt -Force
    #$body = Get-Content -Path C:\Temp\body.txt -Raw
    #pause
    $URI = 'https://graph.microsoft.com/beta/servicePrincipals/'+"$($inputObj.id)"
    #MSGraphRequest -Method PATCH -URI $URI -Body $body
    Invoke-MGGraphRequest -Method PATCH -Uri $URI -Body $SpKeyCredJson
}


Write-Host "Service Principal update in progress, please wait..." -ForegroundColor Green
$maxRetry = 5
$i=0
do {
    Write-Host "Service Principal update in progress, please wait for fetching new properties... # of retry: $i" -ForegroundColor Green
    $SPobj = MSGraphRequest -Method GET -URI $URI
    if ($i -ne 0){
        Start-Sleep -Seconds 30
    }
    $i++
}while( (-not $SPobj.passwordCredentials.keyId.Contains("$signKeyGUID")) -and $i -lt $maxRetry)

if ($i -eq $maxRetry){
    Write-host "Service Principal update failed (timed out)" -ForegroundColor Red
    exit 1
}

Write-host "Service Principal updated successfully" -ForegroundColor Green  
$OutPutJson = $SPobj | ConvertTo-Json -Depth 20
#$fileName = ".\EntraID\Applications-ADO\$Environment\Apps-States\"+$($SPobj.displayName)+"_"+$($SPobj.appId)+"_ServicePrincipal.json"
Write-Host "##vso[task.setvariable variable=customClaimsJson;issecret=true]$JsonFile"

$OutPutJson | Out-File -FilePath $JsonFile -Force
Write-host "ServicePrincipal detail output to - $fileName" -ForegroundColor Green

Disconnect-mggraph
Write-host "Disconnected from MS Graph" -ForegroundColor Green
