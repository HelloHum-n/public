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

# Install PS modules
$modulesRequired = @('Microsoft.Graph.Authentication','Microsoft.Graph.Applications','Microsoft.Graph.Users','Microsoft.Graph.Groups')
foreach( $moduleName in $modulesRequired){
    $module = Get-InstalledModule -Name $moduleName -erroraction 'silentlycontinue'
 
    if ( $module -eq $null) {
        Write-Output "Installing PowerShell Module: $moduleName"
        Install-Module -Name $moduleName -Force -AllowClobber
    }else{
        Write-Output "Found installed PowerShell Module: $moduleName"
    }
}

$appId = "4dc939c2-c38d-4abf-8b6a-35cb76b3e78a"
$scopes = 'Application.Read.All'
$tenantID = "d6efb6af-13e5-4903-bf0b-b6e5dc81aae3"

Write-Host "Connecting to MS Graph, please sign in via the pop up browser window." -ForegroundColor Green
Connect-MgGraph -TenantId $tenantID -Scopes $scopes


$servicePrincipal = Get-MgServicePrincipal -Filter "appId eq `'$appId`'"
$servicePrincipalId = $servicePrincipal.id


##### Add User to Role Assignment ##### 
# Current Assignments
Write-Host "Current Assignments" -ForegroundColor Green
Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $servicePrincipalId

$userPrincipalName = "admin@entraidlab.com"
$user = Get-MgUser -Filter "userPrincipalName eq `'$userPrincipalName`'"
$userPrincipalId = $user.id
$params = @{
	principalId = "$userPrincipalId"
	resourceId = "$servicePrincipalId"
	appRoleId = "00000000-0000-0000-0000-000000000000"
}
New-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $servicePrincipalId -BodyParameter $params

# Current Assignments
Write-Host "Assignments after adding $userPrincipalName" -ForegroundColor Green
Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $servicePrincipalId

##### Add Group to Role Assignment ##### 
# Current Assignments
Write-Host "Current Assignments" -ForegroundColor Green
Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $servicePrincipalId

$groupDisplayName = "g-test"
$group = Get-MgGroup -Filter "displayName eq `'$groupDisplayName`'"
$groupId = $group.id
$params = @{
    principalId = "$groupId"
    resourceId = "$servicePrincipalId"
    appRoleId = "00000000-0000-0000-0000-000000000000"
}

New-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $servicePrincipalId -BodyParameter $params

# Current Assignments
Write-Host "Assignments after adding $userPrincipalName" -ForegroundColor Green
Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $servicePrincipalId