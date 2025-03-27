POST https://graph.microsoft.com/v1.0/applications/
{
    "displayName": "Tenant 1 - Multi Value app"
}
#Create the SP via UI


GET https://graph.microsoft.com/v1.0/applications/51f81a1a-c86b-4f5e-a2ac-cb583d4e5000


POST https://graph.microsoft.com/v1.0/applications/51f81a1a-c86b-4f5e-a2ac-cb583d4e5000/extensionProperties


{    
    "name": "Tenant_1_Multi_Value",
    "dataType": "string",
    "isMultiValued": true,
    "targetObjects": [
        "User",
        "Group"
    ]
}

{
    "name": "Single_Value",
    "dataType": "string",
    "isMultiValued": false,
    "targetObjects": [
        "User"
    ]
}


PATCH https://graph.microsoft.com/v1.0/users/b7a6974b-3fff-40fe-bc37-377fc6084a56

{
    "extension_3112dfcff0c14ba8ab52196ce0a5b83c_Multi_Value": ["Value1","Value2"]
}

GET https://graph.microsoft.com/v1.0/users/b7a6974b-3fff-40fe-bc37-377fc6084a56?$select=extension_3112dfcff0c14ba8ab52196ce0a5b83c_Multi_Value