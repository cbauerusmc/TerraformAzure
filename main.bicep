targetScope = 'resourceGroup'

@description('Name of the Logic App (Consumption).')
param logicAppName string = 'logic-http-example'

@description('Azure region for resources.')
param location string = resourceGroup().location

@description('Tags applied to all resources.')
param tags object = {
  environment: 'dev'
}

module logicApp 'modules/logic-app.bicep' = {
  name: 'deploy-${logicAppName}'
  params: {
    logicAppName: logicAppName
    location: location
    tags: tags
  }
}

output logicAppId string = logicApp.outputs.logicAppId
output httpTriggerUrl string = logicApp.outputs.httpTriggerUrl
