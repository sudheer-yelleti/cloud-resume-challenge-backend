import requests
import pytest
import os

@pytest.mark.smoke
def test_smoke_deployed_function():
    """Smoke test against deployed Azure Function"""
    url = os.environ["FUNC_URL"]
    resp = requests.post(url, json={})
    
    # Basic validations
     assert resp.status_code == 200
    data = resp.json()
    assert "count" in data
    assert "currentcount" in data
    assert isinstance(data["count"], int)
    assert isinstance(data["currentcount"], int)
    assert data["count"] > data["currentcount"]
    assert data["count"] == data["currentcount"] + 1
    print(f"✅ Visitor count incremented from {data['currentcount']} to {data['count']}")
