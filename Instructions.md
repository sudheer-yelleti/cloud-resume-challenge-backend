az cosmosdb sql role definition create -g cloud-resume-challenge-dev -a visitorinfo -b @role-definition.json
az cosmosdb sql role definition list -g cloud-resume-challenge-dev -a visitorinfo 

az cosmosdb sql role assignment create -a visitorinfo -g cloud-resume-challenge-dev -s "/" -p eddbe3b3-e07b-4ba2-9054-da391d8d2ac8 -d 244ed9af-71f1-40b2-94f5-584aa8371013

az functionapp config appsettings set   --name visitorcounter   --resource-group cloud-resume-challenge-dev  --settings   "CosmosDBTableConnection__accountEndpoint=https://visitorinfo.table.cosmos.azure.com:443/"   "CosmosDBTableConnection__credential=managedidentity"  "CosmosDBTableConnection__accountName=visitorinfo"