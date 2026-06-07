import urllib.request
import os

url = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"
dest_dir = r"e:\EduSHAMIIT\volumes\assets"
dest_path = os.path.join(dest_dir, "sample.mp4")

print(f"Downloading {url} to {dest_path}...")
try:
    os.makedirs(dest_dir, exist_ok=True)
    req = urllib.request.Request(
        url,
        headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3'}
    )
    with urllib.request.urlopen(req) as response, open(dest_path, 'wb') as out_file:
        out_file.write(response.read())
    print("Download completed successfully!")
except Exception as e:
    print(f"Error downloading video: {e}")
