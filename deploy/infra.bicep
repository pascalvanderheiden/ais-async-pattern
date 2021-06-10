param cosmos_container_name string = 'customer-con'
param sb_queue_name string = 'customer-queue'
param cosmos_partition_key string = '/message/lastName'
param cosmos_acc_name string = 'msaisd-acc'
param cosmos_db_name string = 'msaisd-db'
param apim_name string = 'msaisd'
param sb_name string = 'msaisd-ns'
param sb_send_rule_name string = 'msaisdservicebus-rule'
param log_analytics_name string = 'msaisd-ws'
param kv_name string = 'msaisd-kv'
param kv_sb_secret_label string = 'msaisdservicebus'
param kv_cosmos_secret_label string = 'msaisdcosmosdb'
param app_insights_name string = 'msaisd-ai'

// --------------------------------------------
//  Creating Cosmos DB Account
// -------------------------------------------- 
resource cosmos_account 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: cosmos_acc_name
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
  name: cosmos_db_name
  properties: {
    resource: {
      id: cosmos_db_name
    }
  }
}

resource cosmos_container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-04-15' = {
  parent: cosmos_database
  name: cosmos_container_name
  properties: {
    resource: {
      id: cosmos_container_name
      partitionKey: {
        paths: [
          cosmos_partition_key
        ]
        kind: 'Hash'
      }
    }
  }
}

// --------------------------------------------
//  Creating API Management service
// -------------------------------------------- 
resource apim 'Microsoft.ApiManagement/service@2020-12-01' = {
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
  name: log_analytics_name
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
  name: sb_name
  location: resourceGroup().location
  sku: {
    name: 'Premium'
    tier: 'Premium'
    capacity: 1
  }
}

resource sb_queue 'Microsoft.ServiceBus/namespaces/queues@2017-04-01' = {
  parent: sb
  name: sb_queue_name
}

resource sb_ns_send_rule 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2017-04-01' = {
  parent: sb
  name: sb_send_rule_name
  properties: {
    rights: [
      'Send'
    ]
  }
}

// --------------------------------------------
//  Creating Key Vault and secrets
// -------------------------------------------- 
resource kv 'Microsoft.KeyVault/vaults@2019-09-01' = {
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

resource kv_cosmosdb_secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: kv
  name: kv_cosmos_secret_label
  properties: {
    value: listKeys(cosmos_account.id, '2021-04-15').primaryMasterKey
  }
}

resource kv_sb_secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: kv
  name: kv_sb_secret_label
  properties: {
    value: listKeys(sb_ns_send_rule.id, '2017-04-01').primaryConnectionString
  }
}

// ----------------------------------------------------------------------------------------
//  Creating Application insights and APIM Logging and diagnostics
// ----------------------------------------------------------------------------------------
resource ai 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: app_insights_name
  location: resourceGroup().location
  kind: 'other'
  properties: {
    Application_Type: 'other'
    IngestionMode: 'ApplicationInsights'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource apim_logger 'Microsoft.ApiManagement/service/loggers@2020-12-01' = {
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

resource apim_diag 'Microsoft.ApiManagement/service/diagnostics@2020-12-01' = {
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
