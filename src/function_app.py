import azure.functions as func
import datetime
import json
import logging
import os

from azure.data.tables import TableClient, UpdateMode
from azure.identity import DefaultAzureCredential
app = func.FunctionApp()

@app.route(route="GetVisitorCountHttpTrigger", methods=["POST"], auth_level=func.AuthLevel.ANONYMOUS)

def GetVisitorCount(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Visitor counter function processed a request.')

    try:
         # Setup Cosmos DB Table connection
        account_url = os.environ["CosmosDBTableConnection__accountEndpoint"]
        table_name = "visitor"
        credential = DefaultAzureCredential()
        table_client = TableClient(endpoint=account_url,
                                  table_name=table_name,
                                  credential=credential)

        # Get current count or initialize
        try:
            entity = table_client.get_entity(partition_key="counter", row_key="visitor")
            current_count = int(entity.get("Count", 0))
        except Exception:
            # Entity not found, initialize
            current_count = 0
        
        # Increment count
        new_count = current_count + 1
        
        # Create table entity for Cosmos DB Table API
        visitor_entity = {
            'PartitionKey': 'counter',
            'RowKey': 'visitor',
            'Count': new_count,
            'LastUpdated': datetime.datetime.utcnow().isoformat(),
        }
        
        table_client.upsert_entity(entity=visitor_entity, mode=UpdateMode.MERGE)
        
        # Return response
        response_data = {
            'count': new_count,
            'message': f'You are visitor number {new_count}!'
        }
        
        return func.HttpResponse(
            json.dumps(response_data),
            status_code=200,
            headers={'Content-Type': 'application/json'}
        )
        
    except Exception as e:
        logging.error(f'Error in visitor counter: {str(e)}')
        return func.HttpResponse(
            json.dumps({'error': 'Failed to update visitor count'}),
            status_code=500,
            headers={'Content-Type': 'application/json'}
        )