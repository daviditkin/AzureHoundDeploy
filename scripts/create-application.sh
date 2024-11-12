# Create the Azure AD application.
application=$(az ad app create --display-name $AzureADApplicationName)
applicationObjectId=$(jq -r '.id' <<< "$application")
applicationClientId=$(jq -r '.appId' <<< "$application")

# Upload the certificate to the application.

# # - Create a self-signed certificate
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout mycert.pem -out mycert.pem -subj "/CN=$AzureADApplicationName"
# openssl pkcs12 -export -out mycert.pfx -in mycert.pem -passout pass:$AzureADApplicationPassword

# # - Upload the certificate to the application
# az ad app credential reset --id $applicationObjectId --cert @mycert.pem --keyvault $KeyVaultName


echo $outputJson > $AZ_SCRIPTS_OUTPUT_PATH
