#!/usr/bin/env python3
"""Download Google Fonts for EduSHAMIIT Flutter app using the official API."""
import os
import requests
import zipfile
import io
import sys

# Create fonts directory if it doesn't exist
fonts_dir = "edu_shamiit_ai/assets/fonts"
os.makedirs(fonts_dir, exist_ok=True)

def download_google_font(family, output_dir, weights=None):
    """Download a Google Font family with specified weights."""
    print(f"\nDownloading {family} font family...")
    
    # Build the API URL
    base_url = "https://www.googleapis.com/webfonts/v1/webfonts"
    params = {"key": "AIzaSyDlABpKE_6v8VZz8J9vXJ6vXJ6vXJ6vXJ6"}  # This won't work, use direct approach
    
    # Alternative: Use the direct download URL format
    # For Outfit: https://fonts.google.com/download?family=Outfit
    # For DM Sans: https://fonts.google.com/download?family=DM+Sans
    
    try:
        # Use the simple download URL
        font_name = family.replace(' ', '+')
        download_url = f"https://fonts.google.com/download?family={font_name}"
        
        print(f"  Downloading from: {download_url}")
        response = requests.get(download_url, timeout=30)
        
        if response.status_code == 200:
            # Extract the zip file
            with zipfile.ZipFile(io.BytesIO(response.content)) as z:
                # Get all font files
                for file_info in z.infolist():
                    if file_info.filename.endswith('.ttf'):
                        # Read the font data
                        font_data = z.read(file_info.filename)
                        
                        # Determine the weight from filename
                        fname_lower = file_info.filename.lower()
                        
                        # For Outfit family
                        if family.lower() == 'outfit':
                            if 'thin' in fname_lower:
                                out_name = 'Outfit-Thin.ttf'
                            elif 'extralight' in fname_lower or 'extra-light' in fname_lower:
                                out_name = 'Outfit-ExtraLight.ttf'
                            elif 'light' in fname_lower:
                                out_name = 'Outfit-Light.ttf'
                            elif 'regular' in fname_lower:
                                out_name = 'Outfit-Regular.ttf'
                            elif 'medium' in fname_lower:
                                out_name = 'Outfit-Medium.ttf'
                            elif 'semibold' in fname_lower or 'semi-bold' in fname_lower:
                                out_name = 'Outfit-SemiBold.ttf'
                            elif 'bold' in fname_lower:
                                out_name = 'Outfit-Bold.ttf'
                            elif 'extrabold' in fname_lower or 'extra-bold' in fname_lower:
                                out_name = 'Outfit-ExtraBold.ttf'
                            elif 'black' in fname_lower:
                                out_name = 'Outfit-Black.ttf'
                            else:
                                continue
                        # For DM Sans family
                        elif family.lower() == 'dm sans':
                            if 'thin' in fname_lower:
                                out_name = 'DMSans-Thin.ttf'
                            elif 'extralight' in fname_lower or 'extra-light' in fname_lower:
                                out_name = 'DMSans-ExtraLight.ttf'
                            elif 'light' in fname_lower:
                                out_name = 'DMSans-Light.ttf'
                            elif 'regular' in fname_lower:
                                out_name = 'DMSans-Regular.ttf'
                            elif 'medium' in fname_lower:
                                out_name = 'DMSans-Medium.ttf'
                            elif 'semibold' in fname_lower or 'semi-bold' in fname_lower:
                                out_name = 'DMSans-SemiBold.ttf'
                            elif 'bold' in fname_lower:
                                out_name = 'DMSans-Bold.ttf'
                            elif 'extrabold' in fname_lower or 'extra-bold' in fname_lower:
                                out_name = 'DMSans-ExtraBold.ttf'
                            elif 'black' in fname_lower:
                                out_name = 'DMSans-Black.ttf'
                            else:
                                continue
                        else:
                            out_name = file_info.filename
                        
                        # Write the font file
                        output_path = os.path.join(output_dir, out_name)
                        with open(output_path, 'wb') as f:
                            f.write(font_data)
                        print(f"  ✓ Saved: {out_name}")
            
            print(f"  ✓ {family} download complete!")
            return True
        else:
            print(f"  ✗ Failed with status {response.status_code}")
            return False
            
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return False

def main():
    print("EduSHAMIIT Font Downloader")
    print("=" * 40)
    
    # Download Outfit font
    success1 = download_google_font("Outfit", fonts_dir)
    
    # Download DM Sans font
    success2 = download_google_font("DM Sans", fonts_dir)
    
    print("\n" + "=" * 40)
    if success1 and success2:
        print("✓ All fonts downloaded successfully!")
        print(f"Fonts saved to: {fonts_dir}")
    else:
        print("✗ Some fonts failed to download.")
        print("\nAlternative: You can manually download fonts from:")
        print("  - Outfit: https://fonts.google.com/download?family=Outfit")
        print("  - DM Sans: https://fonts.google.com/download?family=DM+Sans")
        print("\nExtract the zip files and copy .ttf files to:")
        print(f"  {fonts_dir}")
        sys.exit(1)

if __name__ == "__main__":
    main()