import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest  # noqa: E402

import app as guide  # noqa: E402


@pytest.fixture()
def client():
    guide.app.config["TESTING"] = True
    return guide.app.test_client()


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    body = r.get_json()
    assert body["status"] == "ok"
    assert "version" in body


def test_home_page(client):
    r = client.get("/")
    assert r.status_code == 200
    assert b"Tamil Nadu" in r.data


def test_all_spots(client):
    data = client.get("/api/spots").get_json()
    assert data["count"] == len(guide.SPOTS) >= 10


def test_filter_by_category(client):
    data = client.get("/api/spots?category=beach").get_json()
    assert data["count"] >= 1
    assert all(s["category"] == "beach" for s in data["spots"])


def test_filter_by_season_and_budget(client):
    data = client.get("/api/spots?season=monsoon&budget=low").get_json()
    assert all("monsoon" in s["seasons"] and s["budget"] == "low" for s in data["spots"])


def test_search(client):
    data = client.get("/api/spots?q=madurai").get_json()
    assert any(s["place"] == "Madurai" for s in data["spots"])


def test_bad_season_rejected(client):
    assert client.get("/api/spots?season=spring").status_code == 400


def test_meta(client):
    data = client.get("/api/meta").get_json()
    assert data["total"] == len(guide.SPOTS)
