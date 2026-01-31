#!/usr/bin/env python3
import os
import subprocess
import shutil
from PIL import Image

def generate_iconset(source_image_path, app_path):
    iconset_name = "AppIcon.iconset"
    iconset_path = os.path.join(app_path, iconset_name)
    
    # Clean up existing iconset
    if os.path.exists(iconset_path):
        shutil.rmtree(iconset_path)
    os.makedirs(iconset_path)
    
    # Required sizes for macOS app icon
    # Format: (size, scale) -> filename
    icon_specs = [
        (16, 1, "icon_16x16.png"),
        (16, 2, "icon_16x16@2x.png"),
        (32, 1, "icon_32x32.png"),
        (32, 2, "icon_32x32@2x.png"),
        (128, 1, "icon_128x128.png"),
        (128, 2, "icon_128x128@2x.png"),
        (256, 1, "icon_256x256.png"),
        (256, 2, "icon_256x256@2x.png"),
        (512, 1, "icon_512x512.png"),
        (512, 2, "icon_512x512@2x.png")
    ]
    
    try:
        img = Image.open(source_image_path)
        
        # Resize and save for each spec
        for size, scale, filename in icon_specs:
            target_size = size * scale
            resized_img = img.resize((target_size, target_size), Image.Resampling.LANCZOS)
            output_path = os.path.join(iconset_path, filename)
            resized_img.save(output_path)
            print(f"Generated: {filename}")
            
        print("Iconset generation complete.")
        
        # Convert iconset to icns using iconutil
        icns_path = os.path.join(app_path, "AppIcon.icns")
        subprocess.run(["iconutil", "-c", "icns", iconset_path, "-o", icns_path], check=True)
        print(f"ICNS file created at: {icns_path}")
        
    except Exception as e:
        print(f"Error generating icons: {e}")

if __name__ == "__main__":
    # Path to the new battery icon
    source_image = "/Users/lyon/Documents/bluetooth Android/MacBatteryMonitor/AppIcon_new.png"
    app_directory = "/Users/lyon/Documents/bluetooth Android/MacBatteryMonitor"
    
    generate_iconset(source_image, app_directory)
