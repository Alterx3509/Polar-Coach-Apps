import json
import os
import urllib.parse
import urllib.request
from datetime import datetime, timedelta

CLIENT_ID = "216908"
CLIENT_SECRET = "6234c0f8d1f558f46edf0822a6f27985cff1904e"
FALLBACK_REFRESH_TOKEN = "86788e8daf775160e556966407cefc756db41570"

SYNC_FOLDER = os.path.expanduser("~/Documents/Garmin/sync")
TOKEN_FILE = os.path.expanduser("~/.strava_tokens.json")
OUTPUT_FILE = os.path.join(SYNC_FOLDER, "strava_activities.json")


def load_refresh_token():
    try:
        with open(TOKEN_FILE) as f:
            token_data = json.load(f)
        return token_data.get("refresh_token") or FALLBACK_REFRESH_TOKEN
    except FileNotFoundError:
        return FALLBACK_REFRESH_TOKEN


def refresh_access_token():
    data = urllib.parse.urlencode({
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "refresh_token": load_refresh_token(),
        "grant_type": "refresh_token",
    }).encode()
    req = urllib.request.Request("https://www.strava.com/oauth/token", data=data)
    with urllib.request.urlopen(req, timeout=30) as response:
        token_data = json.loads(response.read())

    with open(TOKEN_FILE, "w") as f:
        json.dump(token_data, f, indent=2)

    return token_data["access_token"]


def fetch_activities(access_token):
    after = int((datetime.now() - timedelta(days=30)).timestamp())
    params = urllib.parse.urlencode({
        "after": after,
        "per_page": 100,
        "page": 1,
    })
    req = urllib.request.Request(
        f"https://www.strava.com/api/v3/athlete/activities?{params}",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.loads(response.read())


def main():
    os.makedirs(SYNC_FOLDER, exist_ok=True)
    activities = fetch_activities(refresh_access_token())

    with open(OUTPUT_FILE, "w") as f:
        json.dump(activities, f, indent=2)

    latest = activities[0]["start_date_local"] if activities else "none"
    print(f"Strava sync complete: {len(activities)} activities saved. Latest: {latest}")


if __name__ == "__main__":
    main()
