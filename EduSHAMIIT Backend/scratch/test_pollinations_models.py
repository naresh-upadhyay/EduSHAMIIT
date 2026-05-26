import urllib.request
import urllib.parse

prompt = "jungle"
encoded = urllib.parse.quote(prompt)

models = ["flux", "turbo", "sana", "flux-realism", "flux-anime", "flux-3d"]

for m in models:
    url = f"https://image.pollinations.ai/prompt/{encoded}?width=1024&height=1024&nologo=true&model={m}"
    try:
        print(f"Testing model: {m}")
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as resp:
            print(f"  Success: {resp.status} - Content-Type: {resp.info().get_content_type()}")
    except Exception as e:
        print(f"  Failed: {e}")
