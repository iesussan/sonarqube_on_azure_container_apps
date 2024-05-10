#!/bin/bash

#Variables globales
export RESOURCE_GROUP=sonarqube-rg
export LOCATION=eastus
export STORAGE_ACCOUNT_NAME=sonarqubestorage001
export STORAGE_CONTAINER_SKU=Standard_LRS
export KEY_VAULT_NAME=sonarqubevault001
export KEY_VAULT_SKU=standard
export CURRENT_USER_OBJECT_ID=$(az ad signed-in-user show --query id --output tsv)

# Variables para PostgreSQL Flexible
export POSTGRES_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d '/@\" ')
export POSTGRES_SERVER_NAME=sonarqubepgserver01
export POSTGRES_DATABASE_NAME=sonarqubedatabase001
export DB_SKU_NAME=Standard_D4s_v3
export DB_TIER=GeneralPurpose
export DB_STORAGE_SIZE=256
export DB_VERSION=12

# Variables para Azure Container Instance
export ACI_DNS_LABEL=sonarqubeaci
export ACI_NAME=sonarqube-server
export ACI_IP_TYPE=Public
export ACI_OS_TYPE=Linux
export ACI_RESTART_POLICY=Always
export ACI_CONTAINER_IMAGE="sonarqube:lts-community"
export SONAR_CONTAINER_CPU=2
export SONAR_CONTAINER_MEMORY=8
export SONAR_CONTAINER_COMMANDS='[]'  # Asume que no hay comandos específicos a ejecutar

#Creacion de resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Creación de Storage Account
az storage account create \
    --name $STORAGE_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku $STORAGE_CONTAINER_SKU \
    --kind StorageV2 \
    --access-tier Hot \
    --min-tls-version TLS1_2 \
    --hns true

# Creación de comparticiones de almacenamiento (file shares)
for share in "data:10" "extensions:10" "logs:10" "conf:1"
do
    IFS=':' read -r share_name quota <<< "$share"
    az storage share create \
        --account-name $STORAGE_ACCOUNT_NAME \
        --name $share_name \
        --quota $quota
done

# Creación de Key Vault
az keyvault create \
    --name $KEY_VAULT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --enable-rbac-authorization true \
    --sku $KEY_VAULT_SKU 

# Asignación de permisos (Role Assignment) para el Key Vault
az role assignment create \
    --role "Key Vault Administrator" \
    --assignee-object-id $CURRENT_USER_OBJECT_ID \
    --scope $(az keyvault show --name $KEY_VAULT_NAME --query id --output tsv)

# Creación de secretos en el Key Vault
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "sonarq-sa-password" --value "$POSTGRES_ADMIN_PASSWORD"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "sonarq-sa-username" --value "sqladmin"

DB_USERNAME=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name "sonarq-sa-username" --query "value" -o tsv)
DB_PASSWORD=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name "sonarq-sa-password" --query "value" -o tsv)

# Crear un servidor PostgreSQL Flexible
az postgres flexible-server create \
    --name $POSTGRES_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --admin-user $DB_USERNAME \
    --admin-password $DB_PASSWORD \
    --sku-name $DB_SKU_NAME \
    --tier $DB_TIER \
    --storage-size $DB_STORAGE_SIZE \
    --version $DB_VERSION

# Configurar reglas de firewall
az postgres flexible-server firewall-rule create \
    --resource-group $RESOURCE_GROUP \
    --name $POSTGRES_SERVER_NAME \
    --rule-name "allow-all-azure-ips" \
    --start-ip-address "0.0.0.0" \
    --end-ip-address "0.0.0.0"

# Crear una base de datos en el servidor PostgreSQL Flexible
az postgres flexible-server db create \
    --resource-group $RESOURCE_GROUP \
    --server-name $POSTGRES_SERVER_NAME \
    --database-name $POSTGRES_DATABASE_NAME

# Creación de Azure Container Instance
az storage file upload \
    --account-name $STORAGE_ACCOUNT_NAME \
    --share-name "conf" \
    --source ./sonar.properties \
    --path "sonar.properties"

export STORAGE_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP --account-name $STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv)
export SONARQUBE_JDBC_URL="jdbc:postgresql://$POSTGRES_SERVER_NAME.postgres.database.azure.com:5432/$POSTGRES_DATABASE_NAME"

az container create \
    --resource-group $RESOURCE_GROUP \
    --name $ACI_NAME \
    --location $LOCATION \
    --os-type $ACI_OS_TYPE \
    --restart-policy $ACI_RESTART_POLICY \
    --dns-name-label $ACI_DNS_LABEL \
    --ip-address $ACI_IP_TYPE \
    --image $SONAR_CONTAINER_IMAGE \
    --cpu $SONAR_CONTAINER_CPU \
    --memory $SONAR_CONTAINER_MEMORY \
    --port 9000 \
    --azure-file-volume-account-name $STORAGE_ACCOUNT_NAME \
    --azure-file-volume-account-key $STORAGE_KEY \
    --azure-file-volume-share-name "data" \
    --azure-file-volume-mount-path "/opt/sonarqube/data" \
    --azure-file-volume-share-name "extensions" \
    --azure-file-volume-mount-path "/opt/sonarqube/extensions" \
    --azure-file-volume-share-name "logs" \
    --azure-file-volume-mount-path "/opt/sonarqube/logs" \
    --azure-file-volume-share-name "conf" \
    --azure-file-volume-mount-path "/opt/sonarqube/conf" \
    --secure-environment-variables \
        SONAR_JDBC_USERNAME="$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name "sonarq-sa-username" --query value -o tsv)" \
        SONAR_JDBC_PASSWORD="$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name "sonarq-sa-password" --query value -o tsv)" \
        SONAR_JDBC_URL="$SONARQUBE_JDBC_URL"