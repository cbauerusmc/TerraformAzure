using 'blob-to-sharepoint.bicep'

param logicAppName = 'logic-blob-to-sharepoint-prod'
param storageAccountName = 'compassusprodedw01'
param containerName = 'sftpfiles'
param blobFolderPath = 'commure'

param sharePointSiteAddress = 'https://compassus0.sharepoint.com/sites/CommureFiles'

// Verify in the Designer's folder picker that this matches — connector may expect the
// library's internal name here rather than the display name "Shared Documents".
param sharePointFolderPath = '/Shared Documents/General/Input'

param tags = {
  environment: 'prod'
}
