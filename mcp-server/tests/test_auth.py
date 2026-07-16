import httpx
import pytest

from tuik_mcp import auth, sdmx


class FakeResponse:
    def __init__(self, status_code: int = 200, payload: dict | None = None):
        self.status_code = status_code
        self._payload = payload or {}

    def json(self) -> dict:
        return self._payload


@pytest.fixture(autouse=True)
def clean_auth_state(monkeypatch):
    auth.clear_token_cache()
    monkeypatch.delenv(auth.API_KEY_ENV_VAR, raising=False)
    yield
    auth.clear_token_cache()


def test_missing_api_key_raises_with_guidance():
    with pytest.raises(auth.TuikAuthError) as excinfo:
        auth.sdmx_auth_headers()
    assert "TUIK_API_KEY" in str(excinfo.value)
    assert "veriportali.tuik.gov.tr" in str(excinfo.value)


def test_token_exchange_builds_bearer_header(monkeypatch):
    monkeypatch.setenv(auth.API_KEY_ENV_VAR, "test-key")
    calls: list[dict] = []

    def fake_post(url, data=None, timeout=None):
        calls.append({"url": url, "data": data})
        return FakeResponse(payload={"access_token": "tok-1", "expires_in": 300})

    monkeypatch.setattr(httpx, "post", fake_post)

    headers = auth.sdmx_auth_headers()

    assert headers == {"Authorization": "Bearer tok-1"}
    assert calls[0]["url"] == auth.TOKEN_URL
    assert calls[0]["data"] == {
        "grant_type": "password",
        "client_id": "nsi-ws-consumer",
        "api_key": "test-key",
    }


def test_token_is_cached_until_expiry(monkeypatch):
    monkeypatch.setenv(auth.API_KEY_ENV_VAR, "test-key")
    calls = []

    def fake_post(url, data=None, timeout=None):
        calls.append(url)
        return FakeResponse(payload={"access_token": f"tok-{len(calls)}", "expires_in": 300})

    monkeypatch.setattr(httpx, "post", fake_post)

    first = auth.sdmx_auth_headers()
    second = auth.sdmx_auth_headers()

    assert first == second == {"Authorization": "Bearer tok-1"}
    assert len(calls) == 1


def test_expired_token_is_refreshed(monkeypatch):
    monkeypatch.setenv(auth.API_KEY_ENV_VAR, "test-key")
    calls = []

    def fake_post(url, data=None, timeout=None):
        calls.append(url)
        return FakeResponse(payload={"access_token": f"tok-{len(calls)}", "expires_in": 300})

    monkeypatch.setattr(httpx, "post", fake_post)

    assert auth.sdmx_auth_headers() == {"Authorization": "Bearer tok-1"}

    # Force expiry and confirm a fresh token is fetched.
    auth._token_manager._expires_at = 0.0
    assert auth.sdmx_auth_headers() == {"Authorization": "Bearer tok-2"}
    assert len(calls) == 2


def test_rejected_api_key_raises(monkeypatch):
    monkeypatch.setenv(auth.API_KEY_ENV_VAR, "bad-key")
    monkeypatch.setattr(httpx, "post", lambda *a, **k: FakeResponse(status_code=401))

    with pytest.raises(auth.TuikAuthError) as excinfo:
        auth.sdmx_auth_headers()
    assert "rejected the API key" in str(excinfo.value)


def test_missing_access_token_in_response_raises(monkeypatch):
    monkeypatch.setenv(auth.API_KEY_ENV_VAR, "test-key")
    monkeypatch.setattr(httpx, "post", lambda *a, **k: FakeResponse(payload={}))

    with pytest.raises(auth.TuikAuthError) as excinfo:
        auth.sdmx_auth_headers()
    assert "did not include an access token" in str(excinfo.value)


def test_sdmx_requests_carry_authorization_header(monkeypatch, structure_xml):
    monkeypatch.setattr(sdmx, "sdmx_auth_headers", lambda: {"Authorization": "Bearer tok-x"})
    seen_headers: dict = {}

    def fake_get(url, *, headers=None, **kwargs):
        seen_headers.update(headers or {})

        class Response:
            text = structure_xml

        return Response()

    monkeypatch.setattr(sdmx, "get_with_retries", fake_get)

    sdmx.fetch_structure("TR,DF_ADNKS_T26,1.0")

    assert seen_headers["Authorization"] == "Bearer tok-x"
