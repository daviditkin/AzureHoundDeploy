targetScope = 'resourceGroup'

@description('The name of the managed identity used by the deployment script. It must have the following permissions: [TBD]')
param DEPLOYMENT_SCRIPT_MANAGED_IDENTITY string

@description('The display name of the application to create in Azure AD.')
param APPLICATION_NAME string = 'AzureHoundEnterprise'

@description('The BloodHound Enterprise instance URL.')
@secure()
param AZUREHOUND_INSTANCE string

@description('BloodHound Enterprise token ID.')
@secure()
param AZUREHOUND_TOKENID string

@description('BloodHound Enterprise token BASE64 encoded.')
@secure()
param AZUREHOUND_TOKEN string

// This needs to provide permissions for the deployment script to create the application in Azure AD
resource DeploymentScriptManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: DEPLOYMENT_SCRIPT_MANAGED_IDENTITY
}

// Create App Registration with permissions
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'AzureHoundEnterpriseDeploymentScript'
  location: resourceGroup().location
  kind: 'PowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${DeploymentScriptManagedIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: '1'
    powerShellVersion: '7.0'
    environmentVariables: [
      {
        name: 'AzureADApplicationName'
        value: APPLICATION_NAME
      }
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
    ]
    scriptContent: loadTextContent('scripts/app-registration-permissions.ps1')
    timeout: 'PT30M'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
  }
  dependsOn: [
  ]
}

// Create a container group with the managed identity
resource AzureHoundContainerInstance 'Microsoft.ContainerInstance/containerGroups@2024-10-01-preview' = {
  name: 'azurehoundcontainer-group-${uniqueString(resourceGroup().id)}'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    containers: [
      {
        name: APPLICATION_NAME  // TODO: Change this to a unique name
        properties: {
          image: 'ghcr.io/bloodhoundad/azurehound:latest'
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
          command: [
            '/azurehound','list'
          ]
          volumeMounts: [
            {
              name: 'azurehound-volume'
              mountPath: '/etc/azurehound'
            }
          ]
          environmentVariables: [
            // Azure Configuration
            {
              name: 'AZUREHOUND_INSTANCE'
              value: AZUREHOUND_INSTANCE
            }
            {
              name: 'AZUREHOUND_TOKENID'
              value: AZUREHOUND_TOKENID
            }
            {
              name: 'AZUREHOUND_TOKEN'
              value: AZUREHOUND_TOKEN
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Never'
    volumes: [
      {
        name: 'azurehound-volume'
        secret: {
          'bloodhound-token-id': AZUREHOUND_TOKENID
          'bloodhound-token': AZUREHOUND_TOKEN
        }
      }
    ]
  }
  dependsOn: [
    deploymentScript
  ]
}

output AzureHoundContainerInstanceName string = AzureHoundContainerInstance.name


