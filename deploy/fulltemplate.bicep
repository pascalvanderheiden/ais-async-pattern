param vaults_mcmaisd_kv_name string = 'mcmaisd-kv'
param service_mcmaisd_name string = 'mcmaisd'
param components_mcmaisd_ai_name string = 'mcmaisd-ai'
// param namespaces_mcmaisd_ns_name string = 'mcmaisd-ns'
param databaseAccounts_mcmaisd_acc_name string = 'mcmaisd-acc'
// param workspaces_mcmaisd_ws_name string = 'mcmaisd-ws'

resource service_mcmaisd_name_resource 'Microsoft.ApiManagement/service@2020-06-01-preview' = {
  name: service_mcmaisd_name
  location: 'West Europe'
  tags: {
    Owner: 'Monish'
  }
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: 'email@mydomain.com'
    publisherName: 'Microsoft'
  }
}

resource databaseAccounts_mcmaisd_acc_name_resource 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: databaseAccounts_mcmaisd_acc_name
  location: 'West Europe'
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: 'West Europe'
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
  }
}

resource databaseAccounts_mcmaisd_acc_name_mcmaisd_db 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-04-15' = {
  parent: databaseAccounts_mcmaisd_acc_name_resource
  name: 'mcmaisd-db'
  properties: {
    resource: {
      id: 'mcmaisd-db'
    }
  }
}

resource databaseAccounts_mcmaisd_acc_name_mcmaisd_db_customer_con 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-04-15' = {
  parent: databaseAccounts_mcmaisd_acc_name_mcmaisd_db
  name: 'customer-con'
  properties: {
    resource: {
      id: 'customer-con'
      partitionKey: {
        paths: [
          '/message/lastName'
        ]
        kind: 'Hash'
      }
    }
  }
  dependsOn: [
    databaseAccounts_mcmaisd_acc_name_resource
  ]
}

resource components_mcmaisd_ai_name_resource 'microsoft.insights/components@2020-02-02-preview' = {
  name: components_mcmaisd_ai_name
  location: 'westeurope'
  tags: {
    Owner: 'Monish'
  }
  kind: 'other'
  properties: {
    Application_Type: 'other'
    IngestionMode: 'ApplicationInsights'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource vaults_mcmaisd_kv_name_resource 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: vaults_mcmaisd_kv_name
  location: 'westeurope'
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: '72f988bf-86f1-41af-91ab-2d7cd011db47'
    accessPolicies: [
      {
        tenantId: '72f988bf-86f1-41af-91ab-2d7cd011db47'
        objectId: '6de67c3b-75d8-4ba9-acad-ab2e6f490c16'
        permissions: {
          keys: [
            'All'
          ]
          secrets: [
            'All'
          ]
          certificates: [
            'All'
          ]
          storage: [
            'All'
          ]
        }
      }
    ]
  }
}

resource vaults_mcmaisd_kv_name_mcmaisdcosmosdb 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = {
  parent: vaults_mcmaisd_kv_name_resource
  name: 'mcmaisdcosmosdb'
  dependsOn: [databaseAccounts_mcmaisd_acc_name_resource]
  properties: {
    value: listKeys(databaseAccounts_mcmaisd_acc_name_resource.id, '2021-04-15').primaryMasterKey
  }
}

resource vaults_mcmaisd_kv_name_mcmaisdservicebus 'Microsoft.KeyVault/vaults/secrets@2020-04-01-preview' = {
  parent: vaults_mcmaisd_kv_name_resource
  dependsOn: [namespaces_mcmaisd_ns_name_resource]
  name: 'mcmaisdservicebus'
  properties: {
    value: listKeys(namespaces_mcmaisd_ns_name_resource.id, '2017-04-01').primaryConnectionString
  }
}

resource workspaces_mcmaisd_ws_name_resource 'microsoft.operationalinsights/workspaces@2020-10-01' = {
  name: workspaces_mcmaisd_ws_name
  location: 'westeurope'
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource namespaces_mcmaisd_ns_name_resource 'Microsoft.ServiceBus/namespaces@2017-04-01' = {
  name: namespaces_mcmaisd_ns_name
  location: 'West Europe'
  sku: {
    name: 'Premium'
    tier: 'Premium'
    capacity: 1
  }
}

resource namespaces_mcmaisd_ns_name_customer_queue 'Microsoft.ServiceBus/namespaces/queues@2018-01-01-preview' = {
  parent: namespaces_mcmaisd_ns_name_resource
  name: 'customer-queue'
  properties: {
    lockDuration: 'PT1M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P10675199DT2H48M5.4775807S'
    deadLetteringOnMessageExpiration: false
    enableBatchedOperations: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    maxDeliveryCount: 10
    status: 'Active'
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
    enableExpress: false
  }
}

resource service_mcmaisd_name_service_mcmaisd_name_ai 'Microsoft.ApiManagement/service/loggers@2021-01-01-preview' = {
  parent: service_mcmaisd_name_resource
  name: '${service_mcmaisd_name}-ai'
  properties: {
    loggerType: 'applicationInsights'
    description: 'Logger resources to APIM'
    credentials: {
      instrumentationKey: '{{Logger-Credentials--60bf034046346110ac32e87f}}'
    }
    isBuffered: true
  }
}

resource service_mcmaisd_name_applicationinsights 'Microsoft.ApiManagement/service/diagnostics@2021-01-01-preview' = {
  parent: service_mcmaisd_name_resource
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'None'
    logClientIp: true
    loggerId: service_mcmaisd_name_service_mcmaisd_name_ai.id
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
