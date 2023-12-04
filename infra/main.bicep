targetScope = 'subscription'

@minLength(2)
@maxLength(4)
@description('2-4 chars to prefix the Azure resources, NOTE: no number or symbols')
param prefix string = 'rs'

@minValue(1)
@maxValue(99)
@description('An integer to prefix the Azure resources belonging to a team')
param teamNumber int = 1

var uniqueSubString = uniqueString(guid(subscription().subscriptionId))
var uString = '${prefix}${uniqueSubString}'

var storageAccountName = '${substring(uString, 0, 10)}stg01'
var keyVaultName = '${substring(uString, 0, 6)}-${teamNumber}-akv00'
var resourceGroupName = '${substring(uString, 0, 6)}-${teamNumber}-rg'
var adbWorkspaceName = '${substring(uString, 0, 6)}-${teamNumber}-AdbWksp'
var nsgName = '${substring(uString, 0, 6)}-${teamNumber}-nsg'
var fwRoutingTable = '${substring(uString, 0, 6)}-${teamNumber}-AdbRoutingTbl'
var eHNameSpace = '${substring(uString, 0, 6)}-${teamNumber}-eh'
var adbAkvLinkName = '${substring(uString, 0, 6)}-${teamNumber}-SecretScope'
var managedIdentityName = '${substring(uString, 0, 6)}-${teamNumber}-Identity'

@description('Default location of the resources')
param location string = 'southeastasia'
@description('')
param teamVnetName string = 'team${teamNumber}vnet'
@description('')
param TeamVnetCidr string = '10.179.${teamNumber}.0/24'
@description('')
param PrivateSubnetCidr string = '10.179.${teamNumber}.0/26'
@description('')
param PublicSubnetCidr string = '10.179.${teamNumber}.64/26'
@description('')
param PrivateLinkSubnetCidr string = '10.179.${teamNumber}.192/26'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module myIdentity './other/managedIdentity.template.bicep' = {
  scope: rg
  name: 'ManagedIdentity'
  params: {
    managedIdentityName: managedIdentityName
    location: location
  }
}

module nsg './network/securitygroup.template.bicep' = {
  scope: rg
  name: 'NetworkSecurityGroup'
  #disable-next-line explicit-values-for-loc-params  
  params: {
    securityGroupName: nsgName
  }
}

module routeTable './network/routetable.template.bicep' = {
  scope: rg
  name: 'RouteTable'
  #disable-next-line explicit-values-for-loc-params  
  params: {
    routeTableName: fwRoutingTable
  }
}

module vnets './network/vnet.template.bicep' = {
  scope: rg
  name: 'TeamVnets'
  #disable-next-line explicit-values-for-loc-params  
  params: {
    teamVnetName: teamVnetName
    routeTableName: routeTable.outputs.routeTblName
    securityGroupName: nsg.outputs.nsgName
    teamVnetCidr: TeamVnetCidr
    publicSubnetCidr: PublicSubnetCidr
    privateSubnetCidr: PrivateSubnetCidr
    privatelinkSubnetCidr: PrivateLinkSubnetCidr
  }
}

module adlsGen2 './storage/storageaccount.template.bicep' = {
  scope: rg
  name: 'StorageAccount'
  params: {
    storageAccountName: storageAccountName
    databricksPublicSubnetId: vnets.outputs.databricksPublicSubnetId
  }
}
module adb './databricks/workspace.template.bicep' = {
  scope: rg
  name: 'DatabricksWorkspace'
#disable-next-line explicit-values-for-loc-params
  params: {
    vnetName: vnets.outputs.teamVnetName
    adbWorkspaceSkuTier: 'premium'
    adbWorkspaceName: adbWorkspaceName
  }
}

module keyVault './keyvault/keyvault.template.bicep' = {
  scope: rg
  name: 'KeyVault'
#disable-next-line explicit-values-for-loc-params
  params: {
    keyVaultName: keyVaultName
    objectId: myIdentity.outputs.mIdentityClientId
  }
}

#disable-next-line explicit-values-for-loc-params
module loganalytics './monitor/loganalytics.template.bicep' = {
  scope: rg
  name: 'LogAnalytics'
}

module eventHubLogging './monitor/eventhub.template.bicep' = {
  scope: rg
  name: 'EventHub'
#disable-next-line explicit-values-for-loc-params
  params: {
    namespaceName: eHNameSpace
  }
}

module privateEndPoints './network/privateendpoint.template.bicep' = {
  scope: rg
  name: 'PrivateEndPoints'
#disable-next-line explicit-values-for-loc-params
  params: {
    keyvaultName: keyVault.name
    keyvaultPrivateLinkResource: keyVault.outputs.keyvault_id
    privateLinkSubnetId: vnets.outputs.privatelinksubnet_id
    storageAccountName: adlsGen2.name
    storageAccountPrivateLinkResource: adlsGen2.outputs.storageaccount_id
    eventHubName: eventHubLogging.outputs.eHName
    eventHubPrivateLinkResource: eventHubLogging.outputs.eHNamespaceId
    vnetName: vnets.outputs.teamVnetName
  }
}

module createDatabricksCluster './databricks/deployment.template.bicep' = {
  scope: rg
  name: 'DatabricksCluster'
  params: {
    location: location
    identity: myIdentity.outputs.mIdentityId
    adb_workspace_url: adb.outputs.databricks_workspaceUrl
    adb_workspace_id: adb.outputs.databricks_workspace_id
    adb_secret_scope_name: adbAkvLinkName
    akv_id: keyVault.outputs.keyvault_id
    akv_uri: keyVault.outputs.keyvault_uri
    LogAWkspId: loganalytics.outputs.logAnalyticsWkspId
    LogAWkspKey: loganalytics.outputs.primarySharedKey
    storageKey: adlsGen2.outputs.key1
    evenHubKey: eventHubLogging.outputs.eHPConnString
  }
}

output resourceGroupName string = rg.name
// output keyVaultName string = keyVaultName
// output adbWorkspaceName string = adbWorkspaceName
// output storageAccountName string = storageAccountName
// output storageKey1 string = adlsGen2.outputs.key1
// output storageKey2 string = adlsGen2.outputs.key2
// output databricksWksp string = adb.outputs.databricks_workspace_id
// output databricks_workspaceUrl string = adb.outputs.databricks_workspaceUrl
// output keyvault_id string = keyVault.outputs.keyvault_id
// output keyvault_uri string = keyVault.outputs.keyvault_uri
// output logAnalyticsWkspId string = loganalytics.outputs.logAnalyticsWkspId
// output logAnalyticsprimarySharedKey string = loganalytics.outputs.primarySharedKey
// output logAnalyticssecondarySharedKey string = loganalytics.outputs.secondarySharedKey
// output eHNamespaceId string = eventHubLogging.outputs.eHNamespaceId
// output eHubNameId string = eventHubLogging.outputs.eHubNameId
// output eHAuthRulesId string = eventHubLogging.outputs.eHAuthRulesId
// output eHPConnString string = eventHubLogging.outputs.eHPConnString
// output dsOutputs object = createDatabricksCluster.outputs.patOutput
// output adbCluster object = createDatabricksCluster.outputs.adbCluster
// output amlProperties object = aml.outputs.amlProperties
