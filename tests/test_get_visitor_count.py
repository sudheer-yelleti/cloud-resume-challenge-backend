import os
import json
import pytest
from unittest.mock import patch, MagicMock
import sys
import azure.functions as func

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from function_app import main as GetVisitorCount  # your function entrypoint

# Mock environment variables
os.environ["VISITOR_TABLE_NAME"] = "Visitors"
os.environ["COSMOS_TABLE_URL"] = "https://mock.table.core.windows.net"

def make_request(body=None):
    return func.HttpRequest(
        method="POST",
        url="/api/GetVisitorCount",
        body=json.dumps(body or {}).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )

@patch("function_app.TableClient")
@patch("function_app.DefaultAzureCredential")
def test_first_visit_initializes_count(mock_cred, mock_table_client):
    mock_instance = MagicMock()
    mock_instance.get_entity.side_effect = Exception("Not found")  # first visit
    mock_instance.upsert_entity.return_value = None
    mock_table_client.return_value = mock_instance

    req = make_request()
    resp = GetVisitorCount(req)

    assert resp.status_code == 200
    body = json.loads(resp.get_body())
    assert body["count"] == 1
    assert "visitor number" in body["message"]
