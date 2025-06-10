
# How to use the script

This script can help you to bulk add connected organizations in entitlement management.

### What it can do:  
It will Create a new Organization and add the domain to it in **configured state**.  
If a Connected Organization already exists then it will add to that instead of trying to create a new Org.  
It will record an error if domain is already added in any organization.  

### Requirements:
You will need access to MS Graph with the following scopes:  
EntitlementManagement.ReadWrite.All  
CrossTenantInformation.ReadBasic.All

The script will try in install the following PS Modules for you (running PowerShell in Admin) if not found:  
Microsoft.Graph.Authentication  


## Input
The script will take a CSV file as input with following information:  
**Domain Name** (Mandatory) - It can either be the Tenant domain name or Tenant ID  
**Organization Name** (Optional) - If empty the script will try to create the Org Name with "Domain Name + Organization"  
**Description**md (Optional) - Description of the Organization

TenantID - A paramenter is needed for which tenant you want to add the Organizations to   

addNonTenantDomain - A siwtch can be used to add Domain Name that is not associated with any Tenant  
**Note:**  
If Domain name is of a Tenant then it will be added as *azureActiveDirectoryTenant*, if not it will be added as *domainIdentitySource*  
Please refer to here: https://learn.microsoft.com/en-us/graph/api/resources/connectedorganization?view=graph-rest-1.0#properties


## Example
Add-ConnectedOrgs -tenantID 6e7367b6-f9a5-4c86-a3d3-7a5991ea1f38 -inputCSV .\orgsToAdd.csv  

## Output
The script will output two files with timestamp:  
A log file with more detail  
A CSV file of the result of each domain from the input  