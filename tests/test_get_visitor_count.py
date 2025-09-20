import json
import pytest
from unittest.mock import patch, MagicMock
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import azure.functions as func
from function_app import GetVisitorCount  # <-- adjust if module name differs


def make_request(body=None):
    """Helper to create a fake HTTP request."""
    return func.HttpRequest(
        method="POST",
        url="/api/GetVisitorCount",
        body=json.dumps(body or {}).encode("utf-8"),
    )


@patch("GetVisitorCount.TableClient")
@patch("GetVisitorCount.DefaultAzureCredential")
def test_first_visit_initializes_count(mock_cred, mock_table_client):
    # Arrange
    mock_instance = MagicMock()
    # Simulate get_entity throwing (first visit - no entity found)
    mock_instance.get_entity.side_effect = Exception("Not found")
    mock_table_client.return_value = mock_instance

    req = make_request()

    # Act
    resp = GetVisitorCount(req)

    # Assert
    assert resp.status_code == 200
    body = json.loads(resp.get_body())
    assert body["count"] == 1
    assert "visitor number" in body["message"]

    # Ensure entity was upserted with Count = 1
    args, kwargs = mock_instance.upsert_entity.call_args
    entity = kwargs["entity"]
    assert entity["Count"] == 1


@patch("GetVisitorCount.TableClient")
@patch("GetVisitorCount.DefaultAzureCredential")
def test_existing_visitor_increments_count(mock_cred, mock_table_client):
    # Arrange
    mock_instance = MagicMock()
    mock_instance.get_entity.return_value = {"Count": 5}
    mock_table_client.return_value = mock_instance

    req = make_request()

    # Act
    resp = GetVisitorCount(req)

    # Assert
    assert resp.status_code == 200
    body = json.loads(resp.get_body())
    assert body["count"] == 6
    assert "visitor number" in body["message"]

    # Ensure entity was upserted with Count = 6
    args, kwargs = mock_instance.upsert_entity.call_args
    entity = kwargs["entity"]
    assert entity["Count"] == 6


@patch("GetVisitorCount.TableClient")
@patch("GetVisitorCount.DefaultAzureCredential")
def test_error_handling_returns_500(mock_cred, mock_table_client):
    # Arrange: make TableClient throw during creation
    mock_table_client.side_effect = Exception("Connection error")

    req = make_request()

    # Act
    resp = GetVisitorCount(req)

    # Assert
    assert resp.status_code == 500
    body = json.loads(resp.get_body())
    assert "error" in body
