@description('The name of the existing network security group to create.')
param securityGroupName string

@description('The name of the virtual network to create.')
param teamVnetName string

@description('The name of the private subnet to create.')
param privateSubnetName string = 'private-subnet'

@description('The name of the private subnet to create.')
param privatelinkSubnetName string = 'privatelink-subnet'

@description('The name of the public subnet to create.')
param publicSubnetName string = 'public-subnet'

@description('Name of the Routing Table')
param routeTableName string

@description('Location for all resources.')
param vnetLocation string = resourceGroup().location

@description('Cidr range for the team vnet.')
param teamVnetCidr string

@description('Cidr range for the private subnet.')
param privateSubnetCidr string

@description('Cidr range for the public subnet.')
param publicSubnetCidr string

@description('Cidr range for the private link subnet..')
param privatelinkSubnetCidr string

var securityGroupId = resourceId('Microsoft.Network/networkSecurityGroups', securityGroupName)

resource teamVnetName_resource 'Microsoft.Network/virtualNetworks@2020-08-01' = {
  location: vnetLocation
  name: teamVnetName
  properties: {
    addressSpace: {
      addressPrefixes: [
        teamVnetCidr
      ]
    }
    subnets: [
      {
        name: publicSubnetName
        properties: {
          addressPrefix: publicSubnetCidr
          networkSecurityGroup: {
            id: securityGroupId
          }
          routeTable: {
            id: resourceId('Microsoft.Network/routeTables', routeTableName)
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                resourceGroup().location
              ]
            }
          ]
          delegations: [
            {
              name: 'databricks-del-public'
              properties: {
                serviceName: 'Microsoft.Databricks/workspaces'
              }
            }
          ]
        }
      }
      {
        name: privateSubnetName
        properties: {
          addressPrefix: privateSubnetCidr
          networkSecurityGroup: {
            id: securityGroupId
          }
          routeTable: {
            id: resourceId('Microsoft.Network/routeTables', routeTableName)
          }
          delegations: [
            {
              name: 'databricks-del-private'
              properties: {
                serviceName: 'Microsoft.Databricks/workspaces'
              }
            }
          ]
        }
      }
      {
        name: privatelinkSubnetName
        properties: {
          addressPrefix: privatelinkSubnetCidr
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    enableDdosProtection: false
  }
}

// output team_vnet_id string = teamVnetName_resource.id
output privatelinksubnet_id string = resourceId('Microsoft.Network/virtualNetworks/subnets', teamVnetName, privatelinkSubnetName)
// output team_vnet_name string= teamVnetName
output databricksPublicSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', teamVnetName, publicSubnetName)

output teamVnetName string = teamVnetName
