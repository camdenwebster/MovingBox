import os
import requests
import json
from urllib.parse import urlparse, urljoin

def ensure_dir(directory):
    if not os.path.exists(directory):
        os.makedirs(directory)

def create_image_set(name, image_data):
    # Create the directory structure for the image set
    # Update path to be in the same directory as the script
    image_set_dir = os.path.join(os.path.dirname(__file__), 'TestAssets.xcassets', f'{name}.imageset')
    ensure_dir(image_set_dir)
    
    # Save the image
    image_path = os.path.join(image_set_dir, f'{name}.jpg')
    with open(image_path, 'wb') as f:
        f.write(image_data)
    
    # Create the Contents.json file
    contents = {
        "images": [
            {
                "filename": f"{name}.jpg",
                "idiom": "universal",
                "scale": "1x"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    
    with open(os.path.join(image_set_dir, 'Contents.json'), 'w') as f:
        json.dump(contents, f, indent=2)

def get_sized_url(url, size=1920):
    """Convert a Pexels URL to use a smaller size"""
    if "pexels.com" in url:
        # Add size query parameter to request a smaller image
        if "?" in url:
            return f"{url}&w={size}&h={size}&fit=crop"
        else:
            return f"{url}?w={size}&h={size}&fit=crop"
    return url

def download_image(url, name):
    # Get a smaller version of the image
    sized_url = get_sized_url(url)
    print(f"Downloading {name} from {sized_url}...")
    
    response = requests.get(sized_url)
    if response.status_code == 200:
        create_image_set(name, response.content)
        print(f"✅ Created image set for: {name}")
    else:
        print(f"❌ Failed to download: {sized_url}")

# Download home images
homes = [
    ("craftsman-home", "https://images.pexels.com/photos/106399/pexels-photo-106399.jpeg")
]

# Download location images
locations = [
    ("living-room", "https://images.pexels.com/photos/1571460/pexels-photo-1571460.jpeg"),
    ("master-bedroom", "https://images.pexels.com/photos/271624/pexels-photo-271624.jpeg"),
    ("kitchen", "https://images.pexels.com/photos/2724749/pexels-photo-2724749.jpeg"),
    ("home-office", "https://images.pexels.com/photos/1957477/pexels-photo-1957477.jpeg"),
    ("garage", "https://images.pexels.com/photos/210538/pexels-photo-210538.jpeg"),
    ("basement", "https://images.pexels.com/photos/5490356/pexels-photo-5490356.jpeg")
]

# Download item images
items = [
    ("macbook", "https://images.pexels.com/photos/303383/pexels-photo-303383.jpeg"),
    ("tv", "https://images.pexels.com/photos/5552789/pexels-photo-5552789.jpeg"),
    ("coffee-maker", "https://images.pexels.com/photos/6401669/pexels-photo-6401669.jpeg"),
    ("desk-chair", "https://images.pexels.com/photos/1957477/pexels-photo-1957477.jpeg"),
    ("guitar", "https://images.pexels.com/photos/164936/pexels-photo-164936.jpeg"),
    # Kitchen Items
    ("stand-mixer", "https://images.pexels.com/photos/4040646/pexels-photo-4040646.jpeg"),
    ("blender", "https://images.pexels.com/photos/1640774/pexels-photo-1640774.jpeg"),
    ("air-fryer", "https://images.pexels.com/photos/29461935/pexels-photo-29461935.jpeg"),
    # Electronics
    ("gaming-console", "https://images.pexels.com/photos/4219883/pexels-photo-4219883.jpeg"),
    ("smart-speaker", "https://images.pexels.com/photos/4790255/pexels-photo-4790255.jpeg"),
    ("tablet", "https://images.pexels.com/photos/1334597/pexels-photo-1334597.jpeg"),
    # Furniture
    ("sofa", "https://images.pexels.com/photos/1571463/pexels-photo-1571463.jpeg"),
    ("dining-table", "https://images.pexels.com/photos/1395967/pexels-photo-1395967.jpeg"),
    ("bed-frame", "https://images.pexels.com/photos/1743229/pexels-photo-1743229.jpeg"),
    # Sports Equipment
    ("treadmill", "https://images.pexels.com/photos/4162487/pexels-photo-4162487.jpeg"),
    ("bicycle", "https://images.pexels.com/photos/100582/pexels-photo-100582.jpeg"),
    ("weight-set", "https://images.pexels.com/photos/949132/pexels-photo-949132.jpeg"),
    # Tools
    ("power-drill", "https://images.pexels.com/photos/8005398/pexels-photo-8005398.jpeg"),
    ("table-saw", "https://images.pexels.com/photos/1094770/pexels-photo-1094770.jpeg"),
    ("tool-chest", "https://images.pexels.com/photos/9754810/pexels-photo-9754810.jpeg"),
    # Art & Decor
    ("canvas-print", "https://images.pexels.com/photos/1585325/pexels-photo-1585325.jpeg"),
    ("area-rug", "https://images.pexels.com/photos/1543447/pexels-photo-1543447.jpeg"),
    ("floor-lamp", "https://images.pexels.com/photos/1112598/pexels-photo-1112598.jpeg"),
    # Additional Electronics
    ("smart-tv", "https://images.pexels.com/photos/6782581/pexels-photo-6782581.jpeg"),
    ("sound-bar", "https://images.pexels.com/photos/6020432/pexels-photo-6020432.jpeg"),
    ("wireless-router", "https://images.pexels.com/photos/4218883/pexels-photo-4218883.jpeg"),
    # Additional Kitchen Items
    ("espresso-machine", "https://images.pexels.com/photos/4349798/pexels-photo-4349798.jpeg"),
    ("food-processor", "https://images.pexels.com/photos/4551832/pexels-photo-4551832.jpeg"),
    ("wine-fridge", "https://images.pexels.com/photos/2664149/pexels-photo-2664149.jpeg"),
    # Additional Furniture
    ("bookshelf", "https://images.pexels.com/photos/1370295/pexels-photo-1370295.jpeg"),
    ("tv-stand", "https://images.pexels.com/photos/4352247/pexels-photo-4352247.jpeg"),
    ("office-desk", "https://images.pexels.com/photos/3740748/pexels-photo-3740748.jpeg"),
    # Outdoor Items
    ("grill", "https://images.pexels.com/photos/1309067/pexels-photo-1309067.jpeg"),
    ("patio-set", "https://images.pexels.com/photos/1643383/pexels-photo-1643383.jpeg"),
    ("fire-pit", "https://images.pexels.com/photos/5465057/pexels-photo-5465057.jpeg"),
    # Musical Instruments
    ("digital-piano", "https://images.pexels.com/photos/164935/pexels-photo-164935.jpeg"),
    ("bass-guitar", "https://images.pexels.com/photos/165971/pexels-photo-165971.jpeg"),
    ("drum-kit", "https://images.pexels.com/photos/995301/pexels-photo-995301.jpeg"),
    # Home Office
    ("monitor", "https://images.pexels.com/photos/1714208/pexels-photo-1714208.jpeg"),
    ("printer", "https://images.pexels.com/photos/4792733/pexels-photo-4792733.jpeg"),
    ("webcam", "https://images.pexels.com/photos/4195325/pexels-photo-4195325.jpeg"),
    # Storage & Organization
    ("filing-cabinet", "https://images.pexels.com/photos/2528118/pexels-photo-2528118.jpeg"),
    ("storage-bench", "https://images.pexels.com/photos/1669799/pexels-photo-1669799.jpeg"),
    ("closet-system", "https://images.pexels.com/photos/1667088/pexels-photo-1667088.jpeg"),
    # Appliances
    ("washer", "https://images.pexels.com/photos/4484078/pexels-photo-4484078.jpeg"),
    ("dryer", "https://images.pexels.com/photos/4484079/pexels-photo-4484079.jpeg"),
    ("dishwasher", "https://images.pexels.com/photos/4484077/pexels-photo-4484077.jpeg"),
    # Entertainment
    ("record-player", "https://images.pexels.com/photos/1389429/pexels-photo-1389429.jpeg"),
    ("board-games", "https://images.pexels.com/photos/776654/pexels-photo-776654.jpeg"),
    ("projector", "https://images.pexels.com/photos/1872928/pexels-photo-1872928.jpeg"),
    # Lighting
    ("chandelier", "https://images.pexels.com/photos/210010/pexels-photo-210010.jpeg"),
    ("table-lamps", "https://images.pexels.com/photos/1123262/pexels-photo-1123262.jpeg"),
    ("smart-bulbs", "https://images.pexels.com/photos/1036936/pexels-photo-1036936.jpeg")
]

# Download all images
if __name__ == "__main__":
    # Update path to be in the same directory as the script
    asset_catalog = os.path.join(os.path.dirname(__file__), 'TestAssets.xcassets')
    ensure_dir(asset_catalog)
    
    # Create the Contents.json for the asset catalog
    catalog_contents = {
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    with open(os.path.join(asset_catalog, 'Contents.json'), 'w') as f:
        json.dump(catalog_contents, f, indent=2)
    
    print("Downloading images...")
    for name, url in homes:
        download_image(url, name)
        
    for name, url in locations:
        download_image(url, name)
        
    for name, url in items:
        download_image(url, name)
    
    print("\nDone! The TestAssets.xcassets has been created in the same directory as the script.")
