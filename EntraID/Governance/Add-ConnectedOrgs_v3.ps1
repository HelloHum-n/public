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
 Date:   2025-03-18
 Name:   Timothy Mui
 email:  timothy.mui@microsoft.com
#>

<#
Flow

1. Check if orgnaization exists by Name
2. if yes, add domain 
3. if no , create Organization, add domain
4. if domain exists, throw error
5. Add Sponsors
#>

param(
    [Parameter(Position=0,mandatory=$true)]
    [string]$tenantID,
    # Input text file contains all the domain
    [Parameter(Position=1,mandatory=$true)]
    [string]$inputCSV,
    # determine if domain should be added if not associated with any tenant (domainIdentitySource)
    [Parameter(Position=2,mandatory=$false)]
    [switch]$addNonTenantDomain
)


$StartTime = $(get-date)
$timeStamp = Get-Date -Format yyyy-MM-dd_HHmm
$fileName = "AddedOrganizations_$timeStamp.csv"
$logFileName = "Log_AddedOrganizations_$timeStamp.log"
$ActivityString = "Fetching Connected Organizations In Activities:"
$PageSize = "100"
$scopes = "EntitlementManagement.ReadWrite.All,CrossTenantInformation.ReadBasic.All"

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

function MSGraphRequest{
    param($fn_URI,$fn_method,$fn_body)
    $i = 0
    do{
        if ($body -eq $null){    
            $fn_result = Invoke-MGGraphRequest -Method $fn_method -Uri $fn_URI -OutputType PSObject -Headers @{'ConsistencyLevel' = 'eventual' }  -ErrorAction SilentlyContinue -ErrorVariable Err
        }else{
            $fn_result = Invoke-MGGraphRequest -Method $fn_method -Uri $fn_URI -Body $fn_body -OutputType PSObject -Headers @{'ConsistencyLevel' = 'eventual' }  -ErrorAction SilentlyContinue -ErrorVariable Err
        }
        if($err -contains "TooManyRequests") {
            # Pausing to avoid Graph throttle 
            Start-Sleep -Seconds 30
        }
        $i++
    }while ( ($err -contains "TooManyRequests") -and ($i -lt 20) )
    if ($fn_result -eq $null){$fn_result = $Err}
    <#
    Write-Host $Err -ForegroundColor Cyan
    Write-Host $body -ForegroundColor Cyan
    Write-Host $URI -ForegroundColor Cyan
    Write-Host $method -ForegroundColor Cyan
    pause
    #>
    return $fn_result
}

#debug
$tenantID = "d6efb6af-13e5-4903-bf0b-b6e5dc81aae3"
Write-Host "Connecting to MS Graph, please sign in via the pop up browser window." -ForegroundColor Green
Connect-MgGraph -TenantId $tenantID -Scopes $scopes

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if ($inputCSV -like ".\*"){
    $inputCSV = $scriptPath+$inputCSV.substring(1) 
}

# Read Input File
Write-Host "Reading Domain list from file: $inputCSV" -ForegroundColor Green
Write-Output "$(Get-Date -Format yyyy-MM-dd_HHmmss) - Reading Domain list from file: $inputCSV" | Out-File -Append -FilePath $logFileName
$domainsObjs = Import-Csv -LiteralPath $inputCSV
$CSV2Export = @()

# Loop through the list to create Connected Organization
foreach ($obj in $domainsObjs){
    $orgName = $obj.'Organization Name'
    $description = $obj.description
    $domain =  $obj.'Domain Name'
    $domain = $domain.Trim()
    $domain = $domain.TrimEnd()
    $identitySources = $null   
    $organization = $null
    $errorMsg = "invalid domain"

    # check if domain is in a valid domain format
    if ( $domain.Contains(".") ){
        # Fetch Tenant ID for domain
        $URI = 'https://graph.microsoft.com/v1.0/tenantRelationships/findTenantInformationByDomainName(domainName='''+$domain+''')'
        $result = $null
        $result = MSGraphRequest -fn_Method Get -fn_URI $URI
        $varTenantId = $result.tenantId
        # Check if it's a valid Entra ID Tenant
        if ( $varTenantId -match '\b[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\b'){
            Write-Host "$domain is a valid domain and with Tenant ID: $varTenantId" -ForegroundColor Green
            Write-Output "$(Get-Date -Format yyyy-MM-dd_HHmmss) - $domain is a valid domain and with Tenant ID: $varTenantId"  | Out-File -Append -FilePath $logFileName
            $identitySources = "azureActiveDirectoryTenant"
            $domainName = $result.defaultDomainName
            $DisplayName = $result.displayName
        }else{
            if ($addNonTenantDomain){
                $identitySources = "domainIdentitySource"
            }else{
                $errorMsg = "Please use switch to add domainIdentitySource"
            }
            $varTenantId = $null
            $DisplayName = $result.displayName
            $domain = $domainName = $result.defaultDomainName
        }
    }elseif($domain -match '\b[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\b'){ #if ( $domain.Contains(".") ){
        # If domain is in tenant ID format, check for it's an actual Entra ID Tenant
        $URI = 'https://graph.microsoft.com/v1.0/tenantRelationships/findTenantInformationByTenantId(tenantId='''+$domain+''')'
        $result = $null
        $result = MSGraphRequest -fn_Method Get -fn_URI $URI
        $varTenantId = $result.tenantId
        if ( -not ($varTenantId -match '\b[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\b')){
            Write-Host "$domain is not a valid Entra ID Tenant" -ForegroundColor Green
            Write-Output "$(Get-Date -Format yyyy-MM-dd_HHmmss) - $domain is not a valid Entra ID Tenant"  | Out-File -Append -FilePath $logFileName
            $errorMsg = "Invalid Tenant ID"
        }else{
            Write-Host "$domain is not a FQDN format but a valid Entra ID Tenant" -ForegroundColor Green
            Write-Output "$(Get-Date -Format yyyy-MM-dd_HHmmss) - $domain is not a FQDN format but a valid Entra ID Tenant"  | Out-File -Append -FilePath $logFileName
            $identitySources = "azureActiveDirectoryTenant"
            $DisplayName = $result.displayName
            $domainName = $result.defaultDomainName
            #debug
            Write-Host "Domainname $domainName" -ForegroundColor Yellow
            Write-Host "DisplayName $DisplayName" -ForegroundColor Yellow
        }
    } #if ( $domain.Contains(".") ){
    
    # If it's a valid domain input
    if ($identitySources -ne $null){

        if ($orgName -ne $null){
            $orgname
            "+++"
            pause
            $URI = 'https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/connectedOrganizations?$filter=displayName eq '''+$orgName+''''
            Write-Host "Fetching Connected Orgranization: link $URI " -ForegroundColor Green
            Write-Output "$(Get-Date -Format yyyy-MM-dd_HHmmss) - Fetching Connected Orgranization: link $URI"  | Out-File -Append -FilePath $logFileName
            $organization =  Invoke-MGGraphRequest -Method GET -Uri $URI -OutputType PSObject -Headers @{'ConsistencyLevel' = 'eventual' }  -ErrorAction SilentlyContinue -ErrorVariable Err
 
        }
           "!0"
            write-host $organization
            write-host $orgName
            write-host $URI
            pause
        # If Organization doesn't exists
        if ($organization.id -eq $null){
            # Create a new Organization and add tenant to it

            Write-Host "Connected Organization doesn't exist, trying to create a new Organization" -ForegroundColor Green
            Write-Output "$(Get-Date -Format yyyy-MM-dd_HHmmss) - Connected Organization doesn't exist, trying to create a new Organization"  | Out-File -Append -FilePath $logFileName
            if ($orgName -eq $null){ 
                $orgName = $DisplayName + " Organization"
            }
$json = @"
{
    "displayName":"$orgName",
    "description":"$Description",
    "identitySources": [
    {

"@
            if ( $identitySources -eq "azureActiveDirectoryTenant"){
            $json = $json + @"
        "@odata.type": "#microsoft.graph.azureActiveDirectoryTenant",
        "tenantId": "$varTenantId",
"@
            }else{
            $json = $json + @"
        "@odata.type": "#microsoft.graph.domainIdentitySource",
        "domainName": "$domainName",
"@
            }
            $json = $json + @"

        "displayName": "$domain"
    }
  ],
  "state":"configured"
}
"@

            #debug
            Write-Host $json -ForegroundColor Magenta
            # Create Organization
            $URI = 'https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/connectedOrganizations/'
            $result = $null
            $result = MSGraphRequest -fn_method Post -fn_URI $URI -fn_body $json
            #debug
            $result
            "POST:  "
            if($result -like "*ConnectedOrganizationAlreadyExists*" -or $result -like "*IdentityProviderAlreadyConfigured*"){
                $errorMsg = "ConnectedOrganizationAlreadyExists"
            }else{
                $errorMsg = "Failed, please see log"
            }
            pause
        }else{  #if ($organization.value.id -eq $null){
            # Add tenant to existing Organization
            Write-Host "Connected Organization exists, trying to add domain to the Organization" -ForegroundColor Green
            Write-Output "$(Get-Date -Format yyyy-MM-dd_HHmmss) - Connected Organization exists, trying to add domain to the Organization"  | Out-File -Append -FilePath $logFileName
            if ( $organization.identitySources.tenantID -contains $varTenantId){
                $errorMsg = "ConnectedOrganizationAlreadyExists"
                "!1"
                Write-host $organization.identitySources.tenantID
                Write-host $varTenantId
                pause
            }else{
                "!2"
                Write-host $organization.identitySources.tenantID
                Write-host $varTenantId
                pause
                $i=0
$json = @"
{
    "identitySources": [
"@

            
                foreach ( $dir in $organization.value.identitySources){
                    if ($i -eq 0){
                    $json = $json + "`r`n"
                    $json = $json + "{"
                    }else{
                    $json = $json + ","
                    $json = $json + "`r`n"
                    $json = $json + "{"
                    }
                    $i++
                    $json = $json + "`r`n"
                    $json = $json + '"@odata.type": "' + $dir.'@odata.type' + '",'
                    $json = $json + "`r`n"
                    if ( $dir.'@odata.type' -eq "#microsoft.graph.domainIdentitySource" ){
                        $json = $json + '"domainName": "' + $dir.displayName + '",'
                    }else{
                        $json = $json + '"tenantId": "' + $dir.tenantId + '",'
                    }

                    $json = $json + "`r`n"
                    $json = $json + '"displayName": "' + $dir.displayName + '"'
                    $json = $json + "`r`n"
                    $json = $json + "}"
                } #end foreach

                $json = $json + ","
                $json = $json + "`r`n"
                $json = $json + "{"
                $json = $json + "`r`n"
                if ( $identitySources -eq "azureActiveDirectoryTenant"){
                    $json = $json + '"@odata.type": "#microsoft.graph.azureActiveDirectoryTenant",'
                    $json = $json + "`r`n"
                    $json = $json + '"tenantId": "' + $varTenantId + '",'
                    $json = $json + "`r`n"
                }else{
                    $json = $json + '"@odata.type": "#microsoft.graph.domainIdentitySource",'
                    $json = $json + "`r`n"
                    $json = $json + '"domainName": "' + $domainName + '",'
                    $json = $json + "`r`n"
                }

                $json = $json + '"displayName": "' + $DisplayName + '"'
                $json = $json + "`r`n"
                $json = $json + "}"
                $json = $json + "`r`n"
                $json = $json + "]"
                $json = $json + "`r`n"
                $json = $json + "}"

            
                # Add Domain to existing Organization
                $URI = 'https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/connectedOrganizations/'+$($organization.value.id)
                $result = $null
                $result = MSGraphRequest -method Patch -URI $URI -body $json
            }
            #debug
            Write-Host $json -ForegroundColor Magenta
            $domainName
            $URI
            $result
            "PATCHING:"
            "orgname $orgName"
            "error $errorMsg"
            "Existing:  $($organization.value.tenantId)"
            "new $varTenantId"
            pause
        } #if ($organization.value.id -eq $null){

        # Validate result
        $exportObj = New-Object PSObject
        if ( $result.id -match '\b[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\b'){
            if ($organization.value.id -eq $null){
                Write-Host "$domainName was successfully added to a newly created Connected Organization" -ForegroundColor Green
                Write-Output "$(Get-Date -Format yyyy-MM-dd_HHmmss) - $domainName was successfully added to a newly created Connected Organization"  | Out-File -Append -FilePath $logFileName
                $exportObj | Add-Member -MemberType NoteProperty -Name "Domain Name"  -Value $domainName 
                $exportObj | Add-Member -MemberType NoteProperty -Name "Tenant ID"  -Value $varTenantId
                $exportObj | Add-Member -MemberType NoteProperty -Name "Result"  -Value "Added to a new Organization" 
            }else{
                Write-Host "$domainName was successfully added to an existing Connected Organization" -ForegroundColor Green
                Write-Output "$(Get-Date -Format yyyy-MM-dd_HHmmss) - $domainName was successfully added to a newly created Connected Organization"  | Out-File -Append -FilePath $logFileName
                $exportObj | Add-Member -MemberType NoteProperty -Name "Domain Name"  -Value $domainName 
                $exportObj | Add-Member -MemberType NoteProperty -Name "Tenant ID"  -Value $varTenantId
                $exportObj | Add-Member -MemberType NoteProperty -Name "Result"  -Value "Added to an existing Organization"
            }
            # Output CSV 
            $CSV2Export += $exportObj
            $ConnectedOrgTenantIDs += $varTenantId
        }else{
            Write-Host "$domain failed to be added to Connected Organizations" -ForegroundColor Red
            #debug
            Write-Host "$domain failed : $result" -ForegroundColor Yellow
            Write-Output "$(Get-Date -Format yyyy-MM-dd_HHmmss) - $domain failed to be added to Connected Organizations - $result"  | Out-File -Append -FilePath $logFileName
            # Output CSV 
            $exportObj | Add-Member -MemberType NoteProperty -Name "Domain Name"  -Value $domainName 
            $exportObj | Add-Member -MemberType NoteProperty -Name "Tenant ID"  -Value $varTenantId
            $exportObj | Add-Member -MemberType NoteProperty -Name "Result"  -Value $errorMsg


        }

    }else{ #if ($identitySources -ne $null){
            $exportObj | Add-Member -MemberType NoteProperty -Name "Domain Name"  -Value $domainName 
            $exportObj | Add-Member -MemberType NoteProperty -Name "Tenant ID"  -Value $varTenantId
            $exportObj | Add-Member -MemberType NoteProperty -Name "Result"  -Value $errorMsg
    }
    $exportObj | Export-Csv -Path $fileName -Append -NoTypeInformation
}
$elapsedTime = $(get-date) - $StartTime
$totalTime = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
Write-Output "Script completed in $totalTime and results output to file $fileName"
Write-Output "$(Get-Date -Format yyyy-MM-dd_HHmmss) - Script completed in $totalTime"  | Out-File -Append -FilePath $logFileName

Disconnect-MgGraph