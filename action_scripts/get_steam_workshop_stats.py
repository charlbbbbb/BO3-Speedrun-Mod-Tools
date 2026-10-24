
import json
import os
import urllib.parse
import urllib.request

WORKSHOP_ID = "3508605873"
API_URL = (
    "https://api.steampowered.com/"
    "ISteamRemoteStorage/GetPublishedFileDetails/v1/"
)

data = urllib.parse.urlencode({
    "itemcount": 1,
    "publishedfileids[0]": WORKSHOP_ID,
}).encode()

request = urllib.request.Request(API_URL, data=data)

with urllib.request.urlopen(request, timeout=30) as response:
    result = json.load(response)

items = result["response"]["publishedfiledetails"]

if not items or not items[0].get("result") == 1:
    raise RuntimeError("Steam did not return valid Workshop details.")

item = items[0]

os.makedirs("stats", exist_ok=True)

# parse steam resp
subscribers = item.get("subscriptions")
badge = {
    badge = {
        "schemaVersion": 1,
        "label": "Current Subscribers",
        "message": str(value),
        "color": "green",
    }
}

if value is None:
        print(f"Steam did not provide {field}; skipping {filename}.")
else:
    with open(
        os.path.join("stats", filename),
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(badge, file, indent=2)
        file.write("\n")
