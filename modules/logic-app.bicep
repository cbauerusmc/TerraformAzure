@description('Name of the Logic App (Consumption).')
param logicAppName string

@description('Azure region for the Logic App.')
param location string = resourceGroup().location

@description('Tags applied to the Logic App.')
param tags object = {}

@description('State of the Logic App workflow.')
@allowed([
  'Enabled'
  'Disabled'
])
param state string = 'Enabled'

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: tags
  properties: {
    state: state
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {}
            }
          }
        }
      }
      actions: {
        Response: {
          type: 'Response'
          runAfter: {}
          inputs: {
            statusCode: 200
            body: {
              message: 'Hello from Logic App'
            }
          }
        }
      }
      outputs: {}
    }
  }
}

resource manualTrigger 'Microsoft.Logic/workflows/triggers@2019-05-01' existing = {
  parent: logicApp
  name: 'manual'
}

@description('Resource ID of the Logic App.')
output logicAppId string = logicApp.id

@description('Name of the Logic App.')
output logicAppName string = logicApp.name

@description('Callback URL for the manual HTTP request trigger.')
output httpTriggerUrl string = manualTrigger.listCallbackUrl().value
