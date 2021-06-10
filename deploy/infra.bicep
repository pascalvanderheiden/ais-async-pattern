param cosmoscont_name string = 'customer-con'
param servicebusqueue_name string = 'customer-queue'
param cosmosconpartkey string = '/message/lastName'
param cosmosacc_name string = 'mcmaisd-acc'
param cosmosdb_name string = 'mcmaisd-db'
param apim_name string = 'mcmaisd'
param servicebusns_name string = 'mcmaisd-ns'
param loganalytics_name string = 'mcmaisd-ws'
param kv_name string = 'mcmaisd-kv'
param kvservicebus_label string = 'mcmaisdcosmosdb'
param kvcosmosdb_label string = 'mcmaisdservicebus'
param appinsights_name string = 'mcmaisd-ai'

// --------------------------------------------
//  Creating Cosmos DB Account
// -------------------------------------------- 
resource cosmos_account 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: cosmosacc_name
  location: resourceGroup().location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: resourceGroup().location
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
  }
}

resource cosmos_database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-04-15' = {
  parent: cosmos_account
  name: cosmosdb_name
  properties: {
    resource: {
      id: cosmosdb_name
    }
  }
}

resource cosmos_container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-04-15' = {
  parent: cosmos_database
  name: cosmoscont_name
  properties: {
    resource: {
      id: cosmoscont_name
      partitionKey: {
        paths: [
          cosmosconpartkey
        ]
        kind: 'Hash'
      }
    }
  }
}

// --------------------------------------------
//  Creating API Management service
// -------------------------------------------- 
resource apim 'Microsoft.ApiManagement/service@2020-06-01-preview' = {
  name: apim_name
  location: resourceGroup().location
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: 'info@microsoft.com'
    publisherName: 'Microsoft'
  }
}

// --------------------------------------------
//  Creating Log analytics workspace
// -------------------------------------------- 
resource la_workspace 'microsoft.operationalinsights/workspaces@2020-10-01' = {
  name: loganalytics_name
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// --------------------------------------------
//  Creating Service bus and queue
// -------------------------------------------- 
resource sb 'Microsoft.ServiceBus/namespaces@2017-04-01' = {
  name: servicebusns_name
  location: resourceGroup().location
  sku: {
    name: 'Premium'
    tier: 'Premium'
    capacity: 1
  }
}

resource sb_queue 'Microsoft.ServiceBus/namespaces/queues@2018-01-01-preview' = {
  parent: sb
  name: servicebusqueue_name
}

resource sb_ns_auth_send 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2021-01-01-preview' = {
  parent: sb
  name: kvservicebus_label
  properties: {
    rights: [
      'Send'
    ]
  }
}

// --------------------------------------------
//  Creating Key Vault and secrets
// -------------------------------------------- 
resource kv 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: kv_name
  location: resourceGroup().location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: '72f988bf-86f1-41af-91ab-2d7cd011db47'
    accessPolicies: []
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: true
  }
}

resource kv_cosmosdb_secret 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = {
  parent: kv
  name: kvcosmosdb_label
  properties: {
    value: listKeys(cosmos_account.id, '2021-04-15').primaryMasterKey
  }
}

resource kv_sb_secret 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = {
  parent: kv
  name: kvservicebus_label
  properties: {
    value: listKeys(sb_ns_auth_send.name, '2021-04-01-preview').primaryConnectionString
  }
}

// ----------------------------------------------------------------------------------------
//  Creating Application insights and APIM Logging and diagnostics
// ----------------------------------------------------------------------------------------
resource ai 'microsoft.insights/components@2020-02-02-preview' = {
  name: appinsights_name
  location: resourceGroup().location
  kind: 'other'
  properties: {
    Application_Type: 'other'
    IngestionMode: 'ApplicationInsights'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource apim_logger 'Microsoft.ApiManagement/service/loggers@2021-01-01-preview' = {
  parent: apim
  name: '${apim_name}-ai'
  properties: {
    loggerType: 'applicationInsights'
    description: 'Logger resources to APIM'
    credentials: {
      instrumentationKey: ai.properties.InstrumentationKey
    }
    isBuffered: true
  }
  dependsOn: [
    ai
  ]
}

resource apim_diag 'Microsoft.ApiManagement/service/diagnostics@2021-01-01-preview' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'None'
    logClientIp: true
    loggerId: apim_logger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 50
    }
    frontend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
  }
}
