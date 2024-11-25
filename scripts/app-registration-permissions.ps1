
$tenantId = (Get-AzContext).Tenant.Id

# Script to create an app registration, add permissions, grant admin consent, and assign "Directory Readers" role

# Connect to Microsoft Graph with the required scopes
# Scopes:
# - Application.ReadWrite.All: Allows creation and management of app registrations
# - RoleManagement.ReadWrite.Directory: Allows management of directory roles
# - Directory.ReadWrite.All: Allows reading and writing directory data
$scopes = @(
    "Application.ReadWrite.All",
    "RoleManagement.ReadWrite.Directory",
    "Directory.ReadWrite.All"
)

Write-Host "Connecting to Microsoft Graph..."
Connect-MgGraph -NoWelcome -Scopes $scopes -TenantId $tenantId

# Step 1: Create an App Registration
$appName = "ditkin-azhound-test1"
Write-Host "Creating app registration: $appName..."
$application = New-MgApplication -DisplayName $appName

# Output the application ID
$appId = $application.AppId
Write-Host "Created application with AppId: $appId"

# Step 2: Create a Service Principal for the Application
Write-Host "Creating service principal for the application..."
$servicePrincipal = New-MgServicePrincipal -AppId $appId

# Get the service principal ID
$servicePrincipalId = $servicePrincipal.Id
Write-Host "Created service principal with Id: $servicePrincipalId"

# Step 3: Add API Permissions to the Application
Write-Host "Adding API permissions to the application..."

# Get the service principal for Microsoft Graph
$graphAppId = "00000003-0000-0000-c000-000000000000"
$graphServicePrincipal = Get-MgServicePrincipal -Filter "AppId eq '$graphAppId'"

# Get the AppRoles (application permissions) and OAuth2PermissionScopes (delegated permissions)
$appRoles = $graphServicePrincipal.AppRoles
$oauth2Permissions = $graphServicePrincipal.Oauth2PermissionScopes

# Find Directory.Read.All application permission
$directoryReadAllAppPermission = $appRoles | Where-Object { $_.Value -eq "Directory.Read.All" -and $_.IsEnabled -eq $true }

# Find User.Read delegated permission
$userReadDelegatedPermission = $oauth2Permissions | Where-Object { $_.Value -eq "User.Read" -and $_.IsEnabled -eq $true }

# Get the permission IDs
$directoryReadAllAppPermissionId = $directoryReadAllAppPermission.Id
$userReadDelegatedPermissionId = $userReadDelegatedPermission.Id

# Create required resource access entries
$requiredResourceAccess = @(
    @{
        "ResourceAppId"   = $graphAppId
        "ResourceAccess" = @(
            @{
                "Id"   = $directoryReadAllAppPermissionId
                "Type" = "Role"  # Application permission
            },
            @{
                "Id"   = $userReadDelegatedPermissionId
                "Type" = "Scope" # Delegated permission
            }
        )
    }
)

# Update the application with the required permissions
Write-Host "Updating the application with required permissions..."
Update-MgApplication -ApplicationId $application.Id -RequiredResourceAccess $requiredResourceAccess

Write-Host "Added required permissions to the application."

# Step 4: Grant Admin Consent Programmatically
Write-Host "Granting admin consent programmatically..."

# Grant consent for application permissions (AppRoleAssignments)
# Create an AppRoleAssignment for the service principal
$appRoleAssignmentBody = @{
    principalId = $servicePrincipalId
    resourceId  = $graphServicePrincipal.Id
    appRoleId   = $directoryReadAllAppPermissionId
}

# TODO: should I assign the result and check for errors?
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $servicePrincipalId -BodyParameter $appRoleAssignmentBody

Write-Host "Granted admin consent for application permissions."

# Step 4b: Grant Admin Consent for Delegated Permissions
$params = @{
    "ClientId" = $servicePrincipalId
    "ConsentType" = "AllPrincipals"
    "ResourceId" = $graphServicePrincipal.Id
    "Scope" = "User.Read"
}

# Grant Consent for Delegated Permissions and format the output (format not really needed)
New-MgOauth2PermissionGrant -BodyParameter $params |
   Format-List Id, ClientId, ConsentType, ExpiryTime, PrincipalId, ResourceId, Scope

Write-Host "Granted admin consent for delegated permissions."

#
# Step 5: Assign the "Directory Readers" Role to the Service Principal
#
Write-Host "Assigning 'Directory Readers' role to the service principal..."

# Check if the Directory Role is already activated
$directoryRole = Get-MgDirectoryRoleByRoleTemplateId -RoleTemplateId $directoryReadersRoleTemplateId


if (-not $directoryRole) {
    Write-Host "Enabling Directory Readers role..."
    $directoryRole = Enable-MgDirectoryRole -RoleTemplateId $directoryReadersRoleTemplateId
    if (-not $directoryRole) {
        Write-Error "Failed to enable Directory Readers role."
        # exit
    }
}

Write-Host "Directory Readers role ID: $($directoryRole.Id)"

New-MgDirectoryRoleMemberByReference -DirectoryRoleId $directoryRole.Id -PrincipalId $servicePrincipalId

$DirObject = @{
    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/3d939dc2-d0a0-4d4d-b3f4-6bb75ce6ff6e"
    }

$odataidurl = "https://graph.microsoft.com/v1.0/directoryObjects/$servicePrincipalId"

New-MgDirectoryRoleMemberByRef -DirectoryRoleId $directoryRole.Id -OdataId $odataidurl

Disconnect-MgGraph

