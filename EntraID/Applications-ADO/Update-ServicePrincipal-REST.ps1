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
    # Json file containing the existing Service Principal details
    [Parameter(Position=1,mandatory=$true)]
    [string]$JsonFile,
    # Json file containing the new Service Principal details (OPTIONAL)
    [Parameter(Position=2,mandatory=$false)]
    [string]$newJsonFile
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
            $fn_result = Invoke-MGGraphRequest -Method $method -Uri $URI -OutputType PSObject -Headers @{'ConsistencyLevel' = 'eventual' }  -ErrorAction SilentlyContinue -ErrorVariable Err
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

Write-Host "Connecting to MS Graph, please sign in via the pop up browser window." -ForegroundColor Green
Connect-MgGraph -TenantId $tenantID -Scopes $scopes

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
if ($JsonFile -like ".\*"){
    $JsonFile = $scriptPath+$JsonFile.substring(1) 
}


if ($JsonFile -like ".\*"){
    $JsonFile = $scriptPath+$JsonFile.substring(1) 
}


$inputObj = Get-content -Path $JsonFile -RAW | ConvertFrom-Json
$inputObj.PSObject.Properties.Remove('@odata.context')
$json = $inputObj | ConvertTo-Json -Depth 20     
$URI = 'https://graph.microsoft.com/v1.0/servicePrincipals'+"/$($inputObj.id)"

if ($newJsonFile -ne $null){
    if ($newJsonFile -like ".\*"){
        $newJsonFile = $scriptPath+$newJsonFile.substring(1) 
    }
    $inputObj = Get-content -Path $newJsonFile -RAW | ConvertFrom-Json
    $inputObj.PSObject.Properties.Remove('@odata.context')
    $json = $inputObj | ConvertTo-Json -Depth 20   
}
# Get the Service Principal properties in Json
#$SPobj = MSGraphRequest -Method GET -URI $URI
#$SPobj.PSObject.Properties.Remove('@odata.context')

<#
Insert comparing json file codes here
https://github.com/orenshatech/PowerShell-Scripts/blob/main/CompareNestedJsonFiles.ps1
#>

$SP = MSGraphRequest -Method PATCH -URI $URI -Body $json
$SP | Format-List id, DisplayName, AppId
Write-host "Service Principal updated successfully" -ForegroundColor Green  
$OutPutJson = $SP | ConvertTo-Json -Depth 20
$fileName = "Apps-States\ServicePrincipal-"+$($SP.displayName)+"-"+$($SP.Id)+".json"
$OutPutJson | Out-File -FilePath $fileName -Force
Write-host "ServicePrincipal detail output to - $fileName" -ForegroundColor Green

Disconnect-mggraph
Write-host "Disconnected from MS Graph" -ForegroundColor Green