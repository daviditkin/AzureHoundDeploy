# AzureHoundDeploy

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https://raw.githubusercontent.com/daviditkin/AzureHound/feature-azure-deployment/deploy/main.json)


Notes:
ManagedIdentities can be assigned permissions just like App Registration (Enterprise Applications), however you are assigning the permissions to 
the managed identity's application object id.  After creation of a Managed Identity it takes some amount of time before the application id is associated with the managed identity.  Therefore we add retry logic.

The `managed-identity-permissions.sh` script will require [TBD] permissions to be assigned to a managed identity.
From an SO but uses ps.  

```powershell
Connect-AzureAD

$TenantID="6c12b0b0-b2cc-4a73-8252-0b94bfca2145"
$GraphAppId = "00000003-0000-0000-c000-000000000000" # (Dont change this value)
$DisplayNameOfMSI="ditkin-test-app"
$PermissionName = "Directory.Read.All"

# $MSI = (Get-AzADServicePrincipal -Filter "displayName eq '$NameOfMSI'")

$applicationId = "8962401f-09de-417c-8192-e6406ebce071"
# $sp = Get-AzureADServicePrincipal | Where-Object{$_.AppId -eq "00000000-c4e2-40cb-96a7-ac90df92685c"}
# $sp = Get-AzADServicePrincipal -ApplicationId $applicationId
     
Start-Sleep -Seconds 10
$GraphServicePrincipal = Get-AzADServicePrincipal -Filter "appId eq '$GraphAppId'"

# Shorter way to get the app role, but not working currently
 Get-AzADServicePrincipal -ApplicationId "$GraphAppId"
$AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"}

# orig
# New-AzureAdServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId -ResourceId $GraphServicePrincipal.ObjectId -Id $AppRole.Id
New-AzADServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -ResourceId $GraphServicePrincipal.Id -AppRoleId $AppRole.Id
```
