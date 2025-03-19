import os
import requests
from urllib.parse import urlparse

def ensure_dir(directory):
    if not os.path.exists(directory):
        os.makedirs(directory)

def download_image(url, category, filename):
    directory = os.path.join(os.path.dirname(__file__), category)
    ensure_dir(directory)
    filepath = os.path.join(directory, f"{filename}.jpg")
    
    response = requests.get(url)
    if response.status_code == 200:
        with open(filepath, 'wb') as f:
            f.write(response.content)
        print(f"Downloaded: {filepath}")
    else:
        print(f"Failed to download: {url}")

# Download home images
homes = [
    ("craftsman-home", "https://town-n-country-living.com/wp-content/uploads/2023/06/craftsman-exterior.jpg")
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
    # ... Add all other items here
]

# Download all images
if __name__ == "__main__":
    for name, url in homes:
        download_image(url, "homes", name)
        
    for name, url in locations:
        download_image(url, "locations", name)
        
    for name, url in items:
        download_image(url, "items", name)

