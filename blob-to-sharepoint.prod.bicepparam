using 'blob-to-sharepoint.bicep'

param logicAppName = 'logic-blob-to-sharepoint-prod'
param storageAccountName = 'compassusprodedw01'
param containerName = 'sftpfiles'
param blobFolderPath = 'commure'

// TODO: replace with the actual site URL from your browser address bar (not a Graph API resource path)
param sharePointSiteAddress = 'https://compassus0.sharepoint.com/sites/REPLACE-WITH-SITE-NAME'

// TODO: confirm exact folder path via the SharePoint connector's folder picker in Designer
param sharePointFolderPath = '/Shared Documents/CommureFiles/General/Input'

param tags = {
  environment: 'prod'
}
