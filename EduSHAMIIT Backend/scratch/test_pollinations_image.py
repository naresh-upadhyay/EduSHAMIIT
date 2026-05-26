import urllib.request
import urllib.parse
import sys

url = "https://image.pollinations.ai/prompt/A%20breathtaking%20premium%20illustration%20of%20a%20tropical%20rainforest%20interior%20showing%20sunlight%20filtering%20through%20multiple%20canopy%20layers%3A%20emergent%20layer%20with%20towering%20trees%20piercing%20through%20the%20green%20ceiling%2C%20dense%20upper%20canopy%20creating%20dappled%20light%20patterns%20on%20the%20mid-canopy%20below%2C%20and%20the%20dim%20forest%20floor%20with%20shade-adapted%20plants%20like%20ferns%2C%20mosses%2C%20and%20seedlings.%20A%20small%20clear%20stream%20winds%20through%20the%20scene%2C%20reflecting%20the%20golden%20sunlight%20shafts.%20The%20illustration%20clearly%20shows%20the%20concept%20of%20light%20stratification%20in%20ecosystems%20-%20how%20different%20plant%20adaptations%20thrive%20at%20different%20light%20levels.%20Vibrant%20yet%20natural%20colors%20%28deep%20jungle%20greens%2C%20earthy%20browns%2C%20and%20pops%20of%20floral%20color%20from%20orchids%20and%20helconia%29%20with%20visible%20light%20rays.%20Ultra-detailed%20scientific%20illustration%20style%20suitable%20for%20biology%20or%20geography%20education.%208K%20resolution.?width=1024&height=1024&nologo=true&enhance=true"

try:
    print("Sending request to pollinations.ai...")
    req = urllib.request.Request(
        url, 
        headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
    )
    with urllib.request.urlopen(req, timeout=15) as response:
        content_type = response.info().get_content_type()
        content_len = response.info().get("Content-Length")
        print(f"Response code: {response.status}")
        print(f"Content-Type: {content_type}")
        print(f"Content-Length: {content_len}")
        data = response.read(100)
        print(f"First 100 bytes: {data}")
except Exception as e:
    print(f"Error fetching image: {e}")
