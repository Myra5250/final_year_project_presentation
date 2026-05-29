import urllib.request
import json
import zipfile
import os

print("Fetching latest stable release info...")
url = "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json"
req = urllib.request.Request(url)
with urllib.request.urlopen(req) as response:
    data = json.loads(response.read().decode())
    stable_hash = data['current_release']['stable']
    stable_release = next(r for r in data['releases'] if r['hash'] == stable_hash)
    zip_url = data['base_url'] + '/' + stable_release['archive']

print("Downloading Flutter SDK from", zip_url)
zip_path = "flutter_stable.zip"
urllib.request.urlretrieve(zip_url, zip_path)

print("Download complete. Extracting to C:\\src...")
if not os.path.exists("C:\\src"):
    os.makedirs("C:\\src")

with zipfile.ZipFile(zip_path, 'r') as zip_ref:
    zip_ref.extractall("C:\\src")

print("Successfully extracted Flutter to C:\\src\\flutter")
