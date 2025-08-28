param (
    [Parameter(Mandatory = $true)]
    [string]$AppName,
 
    [Parameter(Mandatory = $true)]
    [string]$TenantId,
 
    [Parameter(Mandatory = $true)]
    [string]$ClientId,
 
    [Parameter(Mandatory = $true)]
    [string]$CertFile,
 
    [Parameter(Mandatory = $true)]
    [string]$CertPwd,
 
    [Parameter(mandatory=$true)]
    [string]$Environment
)
 
$scopes = 'Application.ReadWrite.All'
$graphThrottleRetry = 20
 
 
# Constants
$graphAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph App id
$openidScopeId = "37f7f235-527c-4136-accd-4a02d197296e" # OpenID scope
$graphSPId = "6ce8151c-c18e-4292-b823-d97a43c94710" # Microsoft Graph SP id
 
# Secure certificate
$pwdSecure = ConvertTo-SecureString -String $CertPwd -Force -AsPlainText
$connectionCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertFile, $pwdSecure)
 
# Connect to Graph
Write-Host "Connecting to MS Graph..." -ForegroundColor Green
Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Certificate $connectionCert
 

 
# Get app object id and App id using app display name
$appResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications?$filter=displayName eq '$AppName'" -Headers @{ "Content-Type" = "application/json" }
 
$ApplicationID = $appResponse.value[0].appId
$AppObjectId   = $appResponse.value[0].id
Write-Host "App id is $ApplicationID"
Write-Host "app objectid is $AppObjectId"
 
#Get Service Principal by App ID
$spResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?$filter=appId eq '$ApplicationID'" -Headers @{ "Content-Type" = "application/json" }
$ServicePrincipalObjId = $spResponse.value[0].id
Write-Host "SP objectid is $ServicePrincipalObjId"

# Add OpenID permission
Write-Host "Adding OpenID permission to application..." -ForegroundColor Green
$permissionBody = @{
    requiredResourceAccess = @(
        @{
            resourceAppId = $graphAppId
            resourceAccess = @(
                @{
                    id = $openidScopeId
                    type = "Scope"
                }
            )
        }
    )
} | ConvertTo-Json -Depth 10
 
$uri = "https://graph.microsoft.com/v1.0/applications/$AppObjectId"
Write-Host "Patching through this URI $uri"
Invoke-MgGraphRequest -Method PATCH -Uri $uri -Body $permissionBody -Headers @{ "Content-Type" = "application/json" }
 
 
# Grant admin consent using oauth2PermissionGrants
Write-Host "Granting admin consent using oauth2PermissionGrants..." -ForegroundColor Green
$expiryTime = (Get-Date).AddYears(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
 
$consentBody = @{
    clientId = $ServicePrincipalObjId
    consentType = "AllPrincipals"
    principalId = $null
    resourceId = $graphSPId
    scope = "openid"
} | ConvertTo-Json
 
 
Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants" -Body $consentBody -Headers @{ "Content-Type" = "application/json" }
 
Disconnect-MgGraph
Write-Host "Disconnected from MS Graph" -ForegroundColor Green