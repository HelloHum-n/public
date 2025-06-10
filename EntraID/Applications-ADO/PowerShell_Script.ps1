param(
    # Application ID of the Application to be retrieved
    #[Parameter(mandatory=$true)]
    #[string]$ApplicationID,
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


#Write-Host "ApplicationID $ApplicationID"
Write-Host "tenantID $tenantID"
Write-Host "ClientID $ClientID"
Write-Host "certFile $certFile"
Write-Host "CertPwd $CertPwd"
Write-Host "Environment $Environment"