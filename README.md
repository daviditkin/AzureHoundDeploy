# AzureHoundDeploy

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https://raw.githubusercontent.com/daviditkin/AzureHound/feature-azure-deployment/deploy/main.json)


## Notes About Approach
ManagedIdentities can be assigned permissions just like App Registration (Enterprise Applications), however you are assigning the permissions to 
the managed identity's application object id.  After creation of a Managed Identity it takes some amount of time before the application id is associated with the managed identity.  Therefore we add retry logic.

## Permissions DeploymentScript requires
The `managed-identity-permissions.sh` script will require 
the following permissions to be assigned to a managed identity.  The following `az cli` script will assign the appropriate permissions to a managed identity that can be used for deployment.

```az
 # Assign Application.ReadWrite.All and Directory.Read.All to the managed identity
az ad app permission add --id <ManagedIdentityClientId> \
   --api 00000003-0000-0000-c000-000000000000 --api-permissions \
   06da0dbc-49e2-44d2-8312-53f166ab848a=Role

az ad app permission add --id <ManagedIdentityClientId> --api 00000003-0000-0000-c000-000000000000 --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Role

# Grant admin consent for the permissions
az ad app permission admin-consent --id <ManagedIdentityClientId>

# Assign Managed Identity Contributor role to the managed identity
az role assignment create --assignee <ManagedIdentityPrincipalId> --role "Managed Identity Contributor" --scope /subscriptions/<SubscriptionId>/resourceGroups/<ResourceGroupName>

# Assign Contributor role to the managed identity for the resource group
az role assignment create --assignee <ManagedIdentityPrincipalId> --role "Contributor" --scope /subscriptions/<SubscriptionId>/resourceGroups/<ResourceGroupName>
```

