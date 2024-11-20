# Create the Azure AD application.
application=$(az ad app create --display-name $AzureADApplicationName)
applicationObjectId=$(jq -r '.id' <<< "$application")
applicationClientId=$(jq -r '.appId' <<< "$application")

#
# Add Microsoft Graph API permissions to the application.
permission=$(az ad app permission add --id $applicationObjectId --api 00000003-0000-0000-c000-000000000000 --api-permissions 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role)

# Add User.Read permission
permission2=$(az ad app permission add --id $applicationObjectId --api 00000003-0000-0000-c000-000000000000 --api-permissions df021288-bdef-4463-88db-98f22de89214=Role)

# Admin consent
az ad app permission admin-consent --id $applicationObjectId

# Create a managed identity for the application
identity=$(az identity create --name $AzureADApplicationName --resource-group $ResourceGroupName)
identityClientId=$(jq -r '.clientId' <<< "$identity")
identityObjectId=$(jq -r '.id' <<< "$identity")

# TODO: This is wrong fix it
# Assign the managed identity to the application or the service principal of the application
# Assign the managed identity to the service principal of the application
servicePrincipal=$(az ad sp create --id $applicationClientId)
servicePrincipalObjectId=$(jq -r '.id' <<< "$servicePrincipal")

# # Assign the managed identity to the service principal
# az role assignment create --assignee $identityClientId --role Contributor --scope /subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName

echo $outputJson > $AZ_SCRIPTS_OUTPUT_PATH
