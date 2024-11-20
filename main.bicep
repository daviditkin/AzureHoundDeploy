extension microsoftGraphV1

// @description('The name of the user-assigned managed identity that has permission to create Azure AD applications.')
// param managedIdentityName string

// @description('The name of the resource group that contains the user-assigned managed identity.')
// param managedIdentityResourceGroupName string = resourceGroup().name

// @description('The display name of the application to create in Azure AD.')
// param azureADApplicationName string = 'AzureHoundEnterprise'

@description('The directory tenant that you want to request permission from. This can be in GUID or friendly name format.')
param azurehoundTenant string

@description('The Application (client) Id that the Azure app registration portal assigned when the app was registered.')
param azurehoundApp string

@description('The location that the Azure resources should be deployed to.')
param location string = resourceGroup().location

@secure()
@description('The secret value for the certificate. base64 encoded')
param certificateSecret string

@secure()
@description('The secret value of the key.pem certificate. base64 encoded')
param keySecret string

@description('The BloodHound Enterprise instance URL.')
@secure()
param AZUREHOUND_INSTANCE string

@description('BloodHound Enterprise token ID.')
@secure()
param AZUREHOUND_TOKENID string

@description('BloodHound Enterprise token.')
@secure()
param AZUREHOUND_TOKEN string


// resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
//   name: managedIdentityName
//   scope: resourceGroup(managedIdentityResourceGroupName)
// }

// resource createAzureADApplicationScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
//   // create unique name
//   name: '${azureADApplicationName}-${uniqueString(resourceGroup().id)}'
//   location: location
//   kind: 'AzureCLI'
//   identity: {
//     type: 'UserAssigned'
//     userAssignedIdentities: {
//       '${managedIdentity.id}': {}
//     }
//   }
//   properties: {
//     forceUpdateTag: '1'
//     azCliVersion: '2.40.0'
//     environmentVariables: [
//       {
//         name: 'AzureADApplicationName'
//         value: azureADApplicationName
//       }
//     ]
//     scriptContent: loadTextContent('scripts/create-application.sh')
//     timeout: 'PT30M'
//     cleanupPreference: 'Always'
//     retentionInterval: 'PT1H'
//   }
// }

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'AzureHoundEnterpriseDeploymentScript'
  location: location
  kind: 'AzureCLI'
  properties: {
    forceUpdateTag: '1'
    azCliVersion: '2.40.0'
    environmentVariables: [
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
    scriptContent: loadTextContent('scripts/create-application.sh')
    timeout: 'PT30M'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
  }
}

resource myManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: 'myManagedIdentity'
  location: location
}

// TODO: Set up managed identity on container group
// https://learn.microsoft.com/en-us/azure/container-instances/container-instances-managed-identity
//
resource AzureHoundContainerInstance 'Microsoft.ContainerInstance/containerGroups@2024-10-01-preview' = {
  name: 'azurehoundcontainer-group-${uniqueString(resourceGroup().id)}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${myManagedIdentity.id}': {}
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
              name: 'AZUREHOUND_APP'
              value: azurehoundApp
            }
            {
              name: 'AZUREHOUND_CERT'
              value: '/etc/azurehound/tls.crt'
            }
            {
              name: 'AZUREHOUND_KEY'
              value: '/etc/azurehound/tls.key'
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
          'tls.crt': certificateSecret
          'tls.key': keySecret
        }
      }
    ]
  }
  // dependsOn: [
  //   createAzureADApplicationScript
  // ]
}

resource roleAssignment1 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, 'Microsoft.Authorization', 'roleAssignments', 'myRoleAssignment')
  properties: {
    principalId: AzureHoundContainerInstance.properties.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9') // Role ID for User.Read.All
  }
}

// Assign Role to the system assigned identity of the container group
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2021-04-01-preview' = {
  name: 'AzureHoundContainerInstanceRoleAssignment'
  scope: AzureHoundContainerInstance
  properties: {
    principalId: AzureHoundContainerInstance.properties.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')  // Should this be subscriptionResourceId or resourceId? TODO: Check
  }
}

// output applicationObjectId string = createAzureADApplicationScript.properties.outputs.applicationObjectId
// output applicationClientId string = createAzureADApplicationScript.properties.outputs.applicationClientId
// output servicePrincipalObjectId string = createAzureADApplicationScript.properties.outputs.servicePrincipalObjectId
