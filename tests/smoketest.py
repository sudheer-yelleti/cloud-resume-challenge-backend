import requests
import pytest

@pytest.mark.smoke
def test_smoke_deployed_function():
    """Smoke test against deployed Azure Function"""
    url = os.environ["FUNC_URL"]
    resp = requests.post(url, json={})
    
    # Basic validations
    assert resp.status_code == 200
    data = resp.json()
    assert "count" in data
    print(f"✅ Visitor count is now: {data['count']}")
