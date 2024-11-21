targetScope = 'subscription'

@description('The name of the managed identity used by the deployment script. It must have the following permissions: [TBD]')
param DeploymentScriptManagedIdentity string

@description('The name of the resource group to create that will hold the Container Instance and Managed Identity.')
param ResourceGroupName string = 'AzureHoundEnterprise'

@description('The location that the Azure resources should be deployed to.')
param location string = 'eastus'

@description('The display name of the application to create in Azure AD.')
param AzureADApplicationName string = 'AzureHoundEnterprise'

@description('The BloodHound Enterprise instance URL.')
@secure()
param AZUREHOUND_INSTANCE string

@description('BloodHound Enterprise token ID.')
@secure()
param AZUREHOUND_TOKENID string

@description('BloodHound Enterprise token BASE64 encoded.')
@secure()
param AZUREHOUND_TOKEN string

// Create the resource group at the subscription level
resource AppResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ResourceGroupName
  location: location
} 

// Deploy the resources (app registration, managed identity, container group ...) in the resource group
module resourceGroupDeployment 'container-group.bicep' = {
  name: 'DeployResourcesInRG'
  scope: resourceGroup(ResourceGroupName)
  params: {
    APPLICATION_NAME: AzureADApplicationName
    AZUREHOUND_INSTANCE: AZUREHOUND_INSTANCE
    AZUREHOUND_TOKENID: AZUREHOUND_TOKENID
    AZUREHOUND_TOKEN: AZUREHOUND_TOKEN
    DEPLOYMENT_SCRIPT_MANAGED_IDENTITY: DeploymentScriptManagedIdentity
  }
}

