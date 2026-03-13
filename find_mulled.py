import urllib.request
import json
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

def search(query):
    url = f"https://quay.io/api/v1/find/repositories?query={query}&includeUsage=false"
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, context=ctx) as response:
            data = json.loads(response.read().decode())
            for repo in data.get('results', []):
                if repo['name'].startswith('biocontainers/mulled-v2'):
                    print(repo['name'])
    except Exception as e:
        print(e)
search("minimap2 samtools pigz")
