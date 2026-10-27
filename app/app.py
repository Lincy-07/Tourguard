"""TN Tourist Guide - a small Flask app that helps travellers find places to visit.

This is the workload that the Terraform + Jenkins + cost-guardrail pipeline deploys.
"""
import json
import os
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from flask import Flask, jsonify, render_template, request

app = Flask(__name__)

SPOTS = json.loads((Path(__file__).parent / "spots.json").read_text(encoding="utf-8"))
SEASONS = ("winter", "summer", "monsoon")
BUDGETS = ("low", "medium", "high")


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/health")
def health():
    return jsonify(
        status="ok",
        version=os.getenv("APP_VERSION", "dev"),
        commit=os.getenv("GIT_SHA", "local"),
        time=datetime.now(timezone.utc).isoformat(),
    )


@app.route("/api/spots")
def spots():
    category = request.args.get("category", "").lower()
    season = request.args.get("season", "").lower()
    budget = request.args.get("budget", "").lower()
    q = request.args.get("q", "").strip().lower()

    if season and season not in SEASONS:
        return jsonify(error=f"season must be one of {SEASONS}"), 400
    if budget and budget not in BUDGETS:
        return jsonify(error=f"budget must be one of {BUDGETS}"), 400

    result = []
    for s in SPOTS:
        if category and s["category"] != category:
            continue
        if season and season not in s["seasons"]:
            continue
        if budget and s["budget"] != budget:
            continue
        if q and q not in (s["name"] + " " + s["place"] + " " + s["blurb"]).lower():
            continue
        result.append(s)
    return jsonify(count=len(result), spots=result)


@app.route("/api/meta")
def meta():
    cats = Counter(s["category"] for s in SPOTS)
    return jsonify(total=len(SPOTS), categories=dict(sorted(cats.items())),
                   seasons=list(SEASONS), budgets=list(BUDGETS))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
