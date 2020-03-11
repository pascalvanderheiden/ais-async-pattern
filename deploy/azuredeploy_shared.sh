#!/bin/bash

# Arguments
# -r Resource Group Name
# -l Location Name
# -a Cosmos DB Account
# -d Cosmos DB Database (Using shared RU's, 400 RU's are the minimum)
# -c Cosmos DB Container
# -p API Management Instance (Developer tier)
# -n Service Bus Namespace (Premium tier for Event Grid)
# -q Service Bus Queue
# -w Log Analytics Workspace (Logic Apps Logging)
# -k Key Vault
# -s Key Vault Service Bus Connection String Label
# -x Key Vault Cosmos DB Key Label
# -y Cosmos DB Container Partition Key
# 
# Executing it with minimum parameters:
#   ./azuredeploy.sh -r ais-async-rg -l westeurope -a aisasyncosmos-acc -d aisasync-db -c customer-con -p aisasync -n aisasync-ns -q customer-queue -w aisasync-ws -k aisasync-kv -s aisasyncservicebus -x aisasynccosmosdb -y "/message/lastName"
#
# This script assumes that you already executed "az login" to authenticate 
#
# For Azure DevOps it's best practice to create a Service Principle for the deployement
# In the Cloud Shell:
# For example: az ad sp create-for-rbac --name aisasync
# Copy output JSON: AppId and password

while getopts r:l:a:d:c:p:n:q:i:w:e:k:s:x:y: option
do
	case "${option}"
	in
		r) RESOURCEGROUP=${OPTARG};;
		l) LOCATION=${OPTARG};;
		a) COSMOSACC=${OPTARG};;
		d) COSMOSDB=${OPTARG};;
		c) COSMOSCON=${OPTARG};;
		p) APIM=${OPTARG};;
		n) SERVICEBUSNS=${OPTARG};;
		q) SERVICEBUSQUEUE=${OPTARG};;
		w) LOGANALYTICS=${OPTARG};;
		k) KV=${OPTARG};;
		s) KVSERVICEBUSLABEL=${OPTARG};;
		x) KVCOSMOSDBLABEL=${OPTARG};;
		y) COSMOSCONPARTKEY=${OPTARG};;		
	esac
done

# Functions
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
    echo -n "$var"
}

# Setting up some default values if not provided
# if [ -z ${RESOURCEGROUP} ]; then RESOURCEGROUP="aisasync-rg"; fi 

echo "Input parameters"
echo "   Resource Group: ${RESOURCEGROUP}"
echo "   Location: ${LOCATION}"
echo "   Cosmos DB Account: ${COSMOSACC}"
echo "   Cosmos DB Database: ${COSMOSDB}"
echo "   Cosmos DB Container: ${COSMOSCON}"
echo "   API Management Instance: ${APIM}"
echo "   Service Bus Namespace: ${SERVICEBUSNS}"
echo "   Service Bus Queue: ${SERVICEBUSQUEUE}"
echo "   Log Analytics Workspace: ${LOGANALYTICS}"
echo "   Key Vault: ${KV}"
echo "   Key Vault Service Bus Connection String Label: ${KVSERVICEBUSLABEL}"
echo "   Key Vault Cosmos DB Key Label: ${KVCOSMOSDBLABEL}"
echo "   Cosmos DB Container Partition Key: ${COSMOSCONPARTKEY}"; echo

#--------------------------------------------
# Registering providers & extentions
#--------------------------------------------
echo "Registering providers"
az extension add -n eventgrid
az provider register -n Microsoft.DocumentDB
az provider register -n Microsoft.ApiManagement
az provider register -n Microsoft.Logic
az provider register -n Microsoft.ServiceBus
az provider register -n Microsoft.OperationsManagement
az provider register -n Microsoft.EventGrid
az provider register -n Microsoft.keyvault

#--------------------------------------------
# Creating Resource group
#-------------------------------------------- 
echo "Creating resource group ${RESOURCEGROUP}"
RESULT=$(az group exists -n $RESOURCEGROUP)
if [ "$RESULT" != "true" ]
then
	az group create -l $LOCATION -n $RESOURCEGROUP
else
	echo "   Resource group ${RESOURCEGROUP} already exists"
fi

#--------------------------------------------
# Creating Cosmos DB Account
#-------------------------------------------- 
echo "Creating Cosmos DB Account ${COSMOSACC}"
RESULT=$(az cosmosdb check-name-exists -n $COSMOSACC)
if [ "$RESULT" != "true" ]
then
	az cosmosdb create -n $COSMOSACC -g $RESOURCEGROUP
	# Get Secure Connection String
	COSMOSDBKEY=$(az cosmosdb keys list -n $COSMOSACC -g $RESOURCEGROUP --type keys --query primaryMasterKey -o tsv)
else
	echo "   Cosmos DB Account ${COSMOSACC} already exists, retrieve key"
	COSMOSDBKEY=$(az cosmosdb keys list -n $COSMOSACC -g $RESOURCEGROUP --type keys --query primaryMasterKey -o tsv)
fi

#--------------------------------------------
# Creating Cosmos DB Database
#-------------------------------------------- 
echo "Creating Cosmos DB Account ${COSMOSDB}"
RESULT=$(az cosmosdb sql database show -n $COSMOSDB -a $COSMOSACC -g $RESOURCEGROUP)
if [ "$RESULT" = "" ]
then
	az cosmosdb sql database create -a $COSMOSACC -g $RESOURCEGROUP -n $COSMOSDB --throughput 400
else
	echo "   Cosmos DB Database ${COSMOSDB} already exists"
fi

#--------------------------------------------
# Creating Cosmos DB Container
#-------------------------------------------- 
echo "Creating Cosmos DB Container ${COSMOSCON}"
RESULT=$(az cosmosdb sql container show -a $COSMOSACC -g $RESOURCEGROUP -n $COSMOSCON -d $COSMOSDB)
if [ "$RESULT" = "" ]
then
	az cosmosdb sql container create -a $COSMOSACC -g $RESOURCEGROUP -n $COSMOSCON -d $COSMOSDB -p "$COSMOSCONPARTKEY"
else
	echo "   Cosmos DB Container ${COSMOSCON} already exists"
fi

#--------------------------------------------
# Creating Log Analytics Workspace
#-------------------------------------------- 
echo "Creating Log Analytics Workspace ${LOGANALYTICS}"
RESULT=$(az monitor log-analytics workspace show -g $RESOURCEGROUP -n $LOGANALYTICS)
if [ "$RESULT" = "" ]
then
	az monitor log-analytics workspace create -g $RESOURCEGROUP -n $LOGANALYTICS
else
	echo "   Log Analytics Workspace ${LOGANALYTICS} already exists"
fi

#--------------------------------------------
# Creating API Management Instance
#-------------------------------------------- 
echo "Creating API Management Instance ${APIM}"
RESULT=$(az apim check-name -n $APIM)
if [ "$RESULT" != "true" ]
then
	az apim create -n $APIM -g $RESOURCEGROUP -l $LOCATION --publisher-email email@mydomain.com --publisher-name Microsoft
else
	echo "   API Management Instance ${APIM} already exists"
fi

#--------------------------------------------
# Creating Service Bus Namespace
#-------------------------------------------- 
echo "Creating Service Bus Namespace ${SERVICEBUSNS}"
RESULT=$(az servicebus namespace exists -n $SERVICEBUSNS)
if [ "$RESULT" != "true" ]
then
	az servicebus namespace create -g $RESOURCEGROUP -n $SERVICEBUSNS -l $LOCATION --sku Premium
	# Create a authorization rule for the Logic App (for the name of the rule I'm using the same label as that of the Key Vault entry)
	az servicebus namespace authorization-rule create -g $RESOURCEGROUP --namespace-name $SERVICEBUSNS -n $KVSERVICEBUSLABEL --rights Listen Send
	# Get Secure Connection String
	SBCONNECTIONSTRING=$(az servicebus namespace authorization-rule keys list -g $RESOURCEGROUP --namespace-name $SERVICEBUSNS -n $KVSERVICEBUSLABEL --query primaryConnectionString -o tsv)
else
	echo "   Service Bus Namespace ${SERVICEBUSNS} already exists, retrieve connection string"
	SBCONNECTIONSTRING=$(az servicebus namespace authorization-rule keys list -g $RESOURCEGROUP --namespace-name $SERVICEBUSNS -n $KVSERVICEBUSLABEL --query primaryConnectionString -o tsv)
fi

#--------------------------------------------
# Creating Service Bus Queue
#-------------------------------------------- 
echo "Creating Service Bus Queue ${SERVICEBUSQUEUE}"
RESULT=$(az servicebus queue show -g $RESOURCEGROUP --namespace-name $SERVICEBUSNS -n $SERVICEBUSQUEUE)
if [ "$RESULT" = "" ]
then
	az servicebus queue create -g $RESOURCEGROUP --namespace-name $SERVICEBUSNS -n $SERVICEBUSQUEUE --max-size 1024
else
	echo "   Service Bus Queue ${SERVICEBUSQUEUE} already exists"
fi

#--------------------------------------------
# Creating Key Vault
#-------------------------------------------- 
echo "Creating Key Vault ${KV}"
RESULT=$(az keyvault show -n $KV)
if [ "$RESULT" = "" ]
then
	az keyvault create -l $LOCATION -n $KV -g $RESOURCEGROUP
	az keyvault secret set --vault-name "$KV" --name "$KVSERVICEBUSLABEL" --value "$SBCONNECTIONSTRING"
	az keyvault secret set --vault-name "$KV" --name "$KVCOSMOSDBLABEL" --value "$COSMOSDBKEY"
else
	echo "   Key Vault ${KV} already exists"
fi
