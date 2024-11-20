targetScope = 'resourceGroup'

@description('The display name of the application to create in Azure AD.')
param AzureADApplicationName string = 'AzureHoundEnterprise'

@description('The Azure AD tenant ID.')
param azurehoundTenant string

@description('The BloodHound Enterprise instance URL.')
@secure()
param AZUREHOUND_INSTANCE string

@description('BloodHound Enterprise token ID.')
@secure()
param AZUREHOUND_TOKENID string

@description('BloodHound Enterprise token BASE64 encoded.')
@secure()
param AZUREHOUND_TOKEN string

resource MyManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-04-01-preview' = {
  name: 'AzureHoundManagedIdentity'
  location: resourceGroup().location
}

// resource deploymentScriptPWSH 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
//   name: 'AzureHoundEnterpriseDeploymentScriptPWSH'
//   location: resourceGroup().location
//   kind: 'AzurePowerShell'
//   properties: {
//     forceUpdateTag: '1'
//     azPowerShellVersion: '7.0'
//     environmentVariables: [
//       {
//         name: 'AzureADApplicationName'
//         value: AzureADApplicationName
//       }
//       {
//         name: 'ResourceGroupName'
//         value: resourceGroup().name // Should be ID????
//       }
//       {
//         name: 'MyManagedIdentityID'
//         value: MyManagedIdentity.id
//       }
//     ]
//     scriptContent: loadTextContent('scripts/create-application.ps1')
//     timeout: 'PT30M'
//     cleanupPreference: 'Always'
//     retentionInterval: 'PT1H'
//   }
// }

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'AzureHoundEnterpriseDeploymentScript'
  location: resourceGroup().location
  kind: 'AzureCLI'
  properties: {
    forceUpdateTag: '1'
    azCliVersion: '2.40.0'
    environmentVariables: [
      {
        name: 'AzureADApplicationName'
        value: AzureADApplicationName
      }
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name // Should be ID????
      }
      {
        name: 'MyManagedIdentityID'
        value: MyManagedIdentity.id
      }
    ]
    scriptContent: loadTextContent('scripts/create-application.sh')
    timeout: 'PT30M'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
  }
}

// Create a container group with the managed identity
// https://learn.microsoft.com/en-us/azure/container-instances/container-instances-managed-identity
//
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
              name: 'AZUREHOUND_TENANT' 
              value: azurehoundTenant
            }
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
  // dependsOn: [
  //   createAzureADApplicationScript
  // ]
}

output AzureHoundContainerInstanceName string = AzureHoundContainerInstance.name


