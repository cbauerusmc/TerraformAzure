@description('Name of the Logic App (Consumption).')
param logicAppName string

@description('Azure region for the Logic App and connections.')
param location string = resourceGroup().location

@description('Tags applied to all resources in this module.')
param tags object = {}

@description('Name of the existing storage account to watch (must be in the same resource group as this deployment).')
param storageAccountName string

@description('Blob container to watch for new files.')
param containerName string = 'sftpfiles'

@description('Folder path within the container to watch (no leading/trailing slash).')
param blobFolderPath string = 'commure'

@description('SharePoint site address, e.g. https://compassus0.sharepoint.com/sites/YourSiteName. Verify via browser address bar, not a Graph API resource path.')
param sharePointSiteAddress string

@description('Destination folder path within the SharePoint document library, e.g. /Shared Documents/General/Input.')
param sharePointFolderPath string

@description('State of the Logic App workflow.')
@allowed([
  'Enabled'
  'Disabled'
])
param state string = 'Enabled'

@description('How often to poll the blob container for new files.')
param pollingIntervalMinutes int = 1

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// Pre-encode at deploy time — the SharePoint connector's dataset address needs this double-encoded,
// and the site address is a fixed deployment value, so no runtime workflow expression is needed for it.
var encodedSharePointSiteAddress = uriComponent(uriComponent(sharePointSiteAddress))

resource blobConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: '${logicAppName}-azureblob'
  location: location
  tags: tags
  properties: {
    displayName: 'azureblob'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
    }
    parameterValues: {
      accountName: storageAccountName
      accessKey: storageAccount.listKeys().keys[0].value
    }
  }
}

// SharePoint uses interactive OAuth — this connection deploys unauthorized.
// After deployment, open it in the Portal (API Connections > this connection > Edit API connection) and sign in once.
resource sharePointConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: '${logicAppName}-sharepointonline'
  location: location
  tags: tags
  properties: {
    displayName: 'sharepointonline'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'sharepointonline')
    }
  }
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: state
    parameters: {
      '$connections': {
        value: {
          azureblob: {
            connectionId: blobConnection.id
            connectionName: blobConnection.name
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
          }
          sharepointonline: {
            connectionId: sharePointConnection.id
            connectionName: sharePointConnection.name
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'sharepointonline')
          }
        }
      }
    }
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          type: 'Object'
          defaultValue: {}
        }
      }
      triggers: {
        When_a_blob_is_added_or_modified: {
          recurrence: {
            frequency: 'Minute'
            interval: pollingIntervalMinutes
          }
          splitOn: '@triggerBody()?[\'value\']'
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azureblob\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/v2/datasets/${storageAccountName}/triggers/batch/onupdatedfile'
            queries: {
              folderId: '/${containerName}/${blobFolderPath}'
              maxFileCount: 10
            }
          }
        }
      }
      actions: {
        Get_blob_content: {
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azureblob\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/v2/datasets/${storageAccountName}/files/@{encodeURIComponent(triggerBody()?[\'Id\'])}/content'
            queries: {
              inferContentType: true
            }
          }
        }
        Create_file_in_SharePoint: {
          runAfter: {
            Get_blob_content: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'sharepointonline\'][\'connectionId\']'
              }
            }
            method: 'post'
            body: '@body(\'Get_blob_content\')'
            headers: {
              'Content-Type': 'application/octet-stream'
            }
            path: '/datasets/${encodedSharePointSiteAddress}/files'
            queries: {
              folderPath: sharePointFolderPath
              name: '@triggerBody()?[\'DisplayName\']'
            }
          }
        }
        Delete_blob: {
          runAfter: {
            Create_file_in_SharePoint: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azureblob\'][\'connectionId\']'
              }
            }
            method: 'delete'
            path: '/v2/datasets/${storageAccountName}/files/@{encodeURIComponent(triggerBody()?[\'Id\'])}'
          }
        }
      }
      outputs: {}
    }
  }
}

// Storage Blob Data Contributor — lets the Logic App's managed identity read/write/delete blobs
// once we switch the connection over to Azure AD auth (pending confirmation the connector supports it).
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource blobRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, logicApp.id, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    principalId: logicApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
  }
}

@description('Resource ID of the Logic App.')
output logicAppId string = logicApp.id

@description('Principal ID of the Logic App''s system-assigned managed identity.')
output logicAppPrincipalId string = logicApp.identity.principalId

@description('Resource ID of the SharePoint connection — open this in the Portal to complete the one-time OAuth sign-in.')
output sharePointConnectionId string = sharePointConnection.id
