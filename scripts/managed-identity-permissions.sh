
# Retry loop to get the application object ID
retry_count=0
max_retries=5
delay=5

while [ $retry_count -lt $max_retries ]; do
    applicationObjectId=$(az ad app list --filter "appId eq '$ClientId'" --query '[0].id' -o tsv)
    if [ -n "$APP_OBJECT_ID" ]; then
        break
    fi
    retry_count=$((retry_count + 1))
    echo "Retry $retry_count/$max_retries: Waiting for $delay seconds before retrying..."
    sleep $delay
done

if [ -z "$applicationObjectId" ]; then
    log_error "Failed to get the application object ID after $max_retries attempts."
    exit 1
fi

#
# Add Microsoft Graph API permissions to the managed identities appliation.
permission=$(az ad app permission add --id $applicationObjectId --api 00000003-0000-0000-c000-000000000000 --api-permissions 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role)
echo "Added Microsoft Graph API permissions to the managed identity application."

# Add User.Read permission
permission2=$(az ad app permission add --id $applicationObjectId --api 00000003-0000-0000-c000-000000000000 --api-permissions df021288-bdef-4463-88db-98f22de89214=Role)
echo "Added User.Read permission to the managed identity application."

# Admin consent for all permissions
az ad app permission admin-consent --id $applicationObjectId
echo "Admin consent granted for all permissions."

