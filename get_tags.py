import urllib.request
import json
import traceback

tools = {
    "samtools": "1.22",
    "minimap2": "2.28",
    "hifiasm": "0.25",
    "gfatools": "0.5",
    "pigz": "2.8",
    "compleasm": "0.2.7",
    "quast": "5.3.0"
}

for tool, version in tools.items():
    url = f"https://quay.io/api/v1/repository/biocontainers/{tool}/tag/"
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            tags = [t["name"] for t in data.get("tags", [])]
            if version:
                tags = [t for t in tags if version in t]
            if tags:
                print(f"{tool}: {tags[0]}")
            else:
                print(f"{tool}: NO TAGS FOUND FOR {version}")
    except Exception as e:
        print(f"Error querying {tool}: {e}")
