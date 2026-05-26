import urllib.request
import urllib.parse

# Long prompt that failed
prompt = "A lush premium illustration of a tropical rainforest jungle at peak biodiversity (daytime), featuring multiple layers of vegetation: emergent kapok trees piercing the canopy, dense mid-canopy with epiphytes like orchids and ferns, and a rich forest floor with fallen logs, mosses, and vibrant fungi. A clear jungle stream winds through the scene, reflecting dappled sunlight and lined with helconia and ginger plants. In the soft background, distant volcanic peaks rise through light mist. The atmosphere is humid and alive with implied life - no dangerous animals visible, just the sense of a thriving ecosystem. Ultra-detailed scientific illustration style with vibrant yet natural greens, earthy browns, and floral pops of color (red, yellow, purple). Perfect for biology or geography education."

encoded_prompt = urllib.parse.quote(prompt.strip())

# URL 1: Original with enhance=true
url_original = f"https://image.pollinations.ai/prompt/{encoded_prompt}?width=1024&height=1024&nologo=true&enhance=true"

# URL 2: Without enhance=true
url_no_enhance = f"https://image.pollinations.ai/prompt/{encoded_prompt}?width=1024&height=1024&nologo=true"

# URL 3: Short prompt
url_short = f"https://image.pollinations.ai/prompt/{urllib.parse.quote('tropical rainforest jungle')}?width=1024&height=1024&nologo=true"

for name, url in [("Original (enhance=true)", url_original), ("No Enhance", url_no_enhance), ("Short Prompt", url_short)]:
    try:
        print(f"Fetching: {name}")
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as resp:
            print(f"  Result: {resp.status} - Length: {resp.info().get('Content-Length')}")
    except Exception as e:
        print(f"  Failed: {e}")
