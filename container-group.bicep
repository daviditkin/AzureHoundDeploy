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

resource DeploymentScriptManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: DEPLOYMENT_SCRIPT_MANAGED_IDENTITY
}

resource MyManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'AzureHoundManagedIdentity'
  location: resourceGroup().location
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'AzureHoundEnterpriseDeploymentScript'
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${DeploymentScriptManagedIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: '1'
    azCliVersion: '2.40.0'
    environmentVariables: [
      {
        name: 'AzureADApplicationName'
        value: APPLICATION_NAME
      }
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name // Should be ID????
      }
      {
        name: 'ClientId'
        value: MyManagedIdentity.properties.clientId
      }
    ]
    scriptContent: loadTextContent('scripts/managed-identity-permissions.sh')
    timeout: 'PT30M'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
  }
  dependsOn: [
    MyManagedIdentity
  ]
}


// Create a container group with the managed identity
resource AzureHoundContainerInstance 'Microsoft.ContainerInstance/containerGroups@2024-10-01-preview' = {
  name: 'azurehoundcontainer-group-${uniqueString(resourceGroup().id)}'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${MyManagedIdentity.id}': {}
    }

  }
  properties: {
    containers: [
      {
        name: 'azurehoundenterprise-1'  // TODO: Change this to a unique name
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


