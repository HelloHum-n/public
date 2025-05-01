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

# This script converts the claims mapping policy object JSON file to just the Claims Mapping defintion json file for editing.

param(
    # Json file containing the Claim mapping Object
    [Parameter(Position=0,mandatory=$true)]
    [string]$inputJsonFile
)

$obj = $inputJsonFile | ConvertFrom-Json
$def = $obj.definition  | ConvertFrom-Json
$json_formatted = $def | ConvertTo-Json -Depth 10

$fileName = "ClaimsPolicyDefinition-"+$($ClaimsPolicy.displayName)+"-"+$($ClaimsPolicy.Id)+".json"
$json_formatted | Out-File -FilePath $fileName 
Write-host "Claims Mapping Definition output to - $fileName" -ForegroundColor Green