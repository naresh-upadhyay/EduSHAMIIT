import urllib.request
import urllib.parse
import json

# Encode a test URL to fetch through the proxy
test_url = "https://image.pollinations.ai/prompt/jungle?width=1024&height=1024&nologo=true&enhance=true"
proxy_url = f"http://localhost:80/api/chat/image-proxy?url={urllib.parse.quote(test_url)}"

try:
    print(f"Requesting proxy: {proxy_url}")
    req = urllib.request.Request(
        proxy_url,
        headers={'User-Agent': 'Mozilla/5.0'}
    )
    with urllib.request.urlopen(req, timeout=15) as response:
        print(f"Status Code: {response.status}")
        print(f"Content-Type: {response.info().get_content_type()}")
        print(f"Content-Length: {response.info().get('Content-Length')}")
        data = response.read(100)
        print(f"First 100 bytes of response: {data}")
except Exception as e:
    print(f"Proxy request failed: {e}")
