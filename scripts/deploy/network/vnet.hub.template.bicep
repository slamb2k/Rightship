@description('The name of the virtual network to create.')
param hubVnetName string

@description('The name of the firewall subnet to create.')
param firewallSubnetName string = 'AzureFirewallSubnet'

@description('Location for all resources.')
param vnetLocation string = resourceGroup().location

@description('Cidr range for the hub vnet.')
param hubVnetCidr string

@description('Cidr range for the firewall subnet.')
param firewallSubnetCidr string

resource hubVnetName_resource 'Microsoft.Network/virtualNetworks@2020-08-01' = {
  name: hubVnetName
  location: vnetLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetCidr
      ]
    }
    subnets: [
      {
        name: firewallSubnetName
        properties: {
          addressPrefix: firewallSubnetCidr
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
      }
    ]
    enableDdosProtection: false
  }
}

output hubVnetName string = hubVnetName
