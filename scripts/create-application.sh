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

# Upload the certificate to the application.

# # - Create a self-signed certificate
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout mycert.pem -out mycert.pem -subj "/CN=$AzureADApplicationName"
# openssl pkcs12 -export -out mycert.pfx -in mycert.pem -passout pass:$AzureADApplicationPassword

# # - Upload the certificate to the application
# az ad app credential reset --id $applicationObjectId --cert @mycert.pem --keyvault $KeyVaultName

echo $outputJson > $AZ_SCRIPTS_OUTPUT_PATH
