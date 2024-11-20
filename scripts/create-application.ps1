# Variables (ensure these are set in your environment or passed to the script)
$AzureADApplicationName = "YourAppName"
$ResourceGroupName = "YourResourceGroupName"

# Connect to Azure account (if not already connected)
Connect-AzAccount

# Create the Azure AD application with required permissions
$graphResourceAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph API App ID

# Define the required permissions
$directoryReadAll = New-Object -TypeName Microsoft.Azure.Commands.ActiveDirectory.ResourceAccess
$directoryReadAll.Id = "7ab1d382-f21e-4acd-a863-ba3e13f7da61" # Directory.Read.All
$directoryReadAll.Type = "Role"

$userReadAll = New-Object -TypeName Microsoft.Azure.Commands.ActiveDirectory.ResourceAccess
$userReadAll.Id = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All
$userReadAll.Type = "Role"

# Define the required resource access
$graphRequiredResourceAccess = New-Object -TypeName Microsoft.Azure.Commands.ActiveDirectory.RequiredResourceAccess
$graphRequiredResourceAccess.ResourceAppId = $graphResourceAppId
$graphRequiredResourceAccess.ResourceAccess = @($directoryReadAll, $userReadAll)

# Create the Azure AD application with the required permissions
$app = New-AzADApplication -DisplayName $AzureADApplicationName -RequiredResourceAccess @($graphRequiredResourceAccess)

$applicationObjectId = $app.Id
$applicationClientId = $app.ApplicationId

Write-Host "Azure AD Application created:"
Write-Host "Object ID: $applicationObjectId"
Write-Host "Client ID: $applicationClientId"

# Create a service principal for the application
$sp = New-AzADServicePrincipal -ApplicationId $applicationClientId

Write-Host "Service Principal created:"
Write-Host "Object ID: $($sp.Id)"

# Grant admin consent for the permissions
# Install the Microsoft Graph PowerShell SDK if not already installed
# Install-Module Microsoft.Graph -Scope CurrentUser

# Connect to Microsoft Graph with the necessary scopes
Connect-MgGraph -Scopes "Application.ReadWrite.All","Directory.AccessAsUser.All"

# Grant admin consent
$consentParams = @{
    "clientId"     = $sp.Id
    "consentType"  = "AllPrincipals"
    "principalId"  = $null
    "resourceId"   = $graphResourceAppId
    "scope"        = "Directory.Read.All User.Read.All"
}

# Create the OAuth2PermissionGrant object
New-MgOauth2PermissionGrant -BodyParameter $consentParams

Write-Host "Admin consent granted for the application permissions."

# Disconnect from Microsoft Graph
Disconnect-MgGraph

# Create a managed identity for the application
$identity = New-AzUserAssignedIdentity -Name $AzureADApplicationName -ResourceGroupName $ResourceGroupName

$identityClientId = $identity.ClientId
$identityObjectId = $identity.Id

Write-Host "Managed Identity created:"
Write-Host "Client ID: $identityClientId"
Write-Host "Object ID: $identityObjectId"

# Assign the managed identity to the application
$sp = Get-AzADServicePrincipal -ApplicationId $applicationClientId
$sp.Add("ServicePrincipalNames", $identityClientId)
