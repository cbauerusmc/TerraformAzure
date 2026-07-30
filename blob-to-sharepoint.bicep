targetScope = 'resourceGroup'

@description('Name of the Logic App (Consumption).')
param logicAppName string

@description('Azure region for resources.')
param location string = resourceGroup().location

@description('Tags applied to all resources.')
param tags object = {}

@description('Name of the existing storage account to watch (must be in this resource group).')
param storageAccountName string

@description('Blob container to watch for new files.')
param containerName string = 'sftpfiles'

@description('Folder path within the container to watch (no leading/trailing slash).')
param blobFolderPath string = 'commure'

@description('SharePoint site address, e.g. https://compassus0.sharepoint.com/sites/YourSiteName.')
param sharePointSiteAddress string

@description('Destination folder path within the SharePoint document library.')
param sharePointFolderPath string

module blobToSharePointLogicApp 'modules/blob-to-sharepoint-logic-app.bicep' = {
  name: 'deploy-${logicAppName}'
  params: {
    logicAppName: logicAppName
    location: location
    tags: tags
    storageAccountName: storageAccountName
    containerName: containerName
    blobFolderPath: blobFolderPath
    sharePointSiteAddress: sharePointSiteAddress
    sharePointFolderPath: sharePointFolderPath
  }
}

output logicAppId string = blobToSharePointLogicApp.outputs.logicAppId
output sharePointConnectionId string = blobToSharePointLogicApp.outputs.sharePointConnectionId
