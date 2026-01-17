#!/usr/bin/env python3
"""
Download and process images from Pexels for MovingBox test assets.

Usage:
    python download_pexels_images.py --api-key YOUR_PEXELS_API_KEY

Get a free API key at: https://www.pexels.com/api/

The script will download images for the Beach House test data and process them
to 1920x1920 square format.
"""

import argparse
import os
import requests
from pathlib import Path
from PIL import Image
from io import BytesIO


# Image configurations: (output_filename, search_query, orientation)
BEACH_HOUSE_IMAGES = [
    ("beach-house", "beach house exterior malibu", "landscape"),
    ("beach-living-room", "coastal living room ocean view", "landscape"),
    ("beach-bedroom", "white beach bedroom coastal", "landscape"),
    ("beach-kitchen", "coastal kitchen white modern", "landscape"),
    ("beach-deck", "beach house deck ocean view", "landscape"),
]

# Household items for test data: (output_filename, search_query, orientation)
HOUSEHOLD_ITEMS = [
    # Electronics
    ("laptop", "laptop computer desk", "landscape"),
    ("desktop-computer", "desktop computer setup", "landscape"),
    ("tablet", "tablet ipad device", "landscape"),
    ("smartphone", "smartphone mobile phone", "portrait"),
    ("headphones", "wireless headphones", "square"),
    ("speaker-bluetooth", "bluetooth speaker portable", "square"),
    ("camera-dslr", "dslr camera photography", "landscape"),
    ("gaming-console", "video game console", "landscape"),
    ("smart-watch", "smart watch wearable", "square"),
    ("router-wifi", "wifi router networking", "landscape"),

    # Kitchen Appliances
    ("microwave", "microwave oven kitchen", "landscape"),
    ("toaster", "toaster kitchen appliance", "landscape"),
    ("kettle-electric", "electric kettle kitchen", "square"),
    ("instant-pot", "instant pot pressure cooker", "square"),
    ("juicer", "juicer kitchen appliance", "square"),
    ("rice-cooker", "rice cooker appliance", "square"),
    ("knife-set", "kitchen knife set block", "landscape"),
    ("pots-pans", "cookware pots pans set", "landscape"),
    ("cutting-board", "wooden cutting board kitchen", "landscape"),
    ("mixer-hand", "hand mixer kitchen", "square"),

    # Furniture
    ("armchair", "armchair living room", "landscape"),
    ("coffee-table", "coffee table living room", "landscape"),
    ("nightstand", "nightstand bedroom", "square"),
    ("dresser", "dresser bedroom furniture", "landscape"),
    ("wardrobe", "wardrobe closet furniture", "portrait"),
    ("desk-writing", "writing desk home office", "landscape"),
    ("dining-chairs", "dining chairs set", "landscape"),
    ("bookcase", "bookcase bookshelf furniture", "portrait"),
    ("ottoman", "ottoman footstool living room", "square"),
    ("console-table", "console table entryway", "landscape"),

    # Home Decor
    ("mirror-wall", "wall mirror decorative", "portrait"),
    ("vase-ceramic", "ceramic vase decorative", "portrait"),
    ("picture-frame", "picture frame wall art", "landscape"),
    ("throw-blanket", "throw blanket cozy", "landscape"),
    ("decorative-pillows", "decorative pillows sofa", "landscape"),
    ("wall-clock", "wall clock decorative", "square"),
    ("candle-holder", "candle holder decorative", "square"),
    ("plant-indoor", "indoor plant potted", "portrait"),

    # Bedroom
    ("mattress", "mattress bedroom", "landscape"),
    ("bedding-set", "bedding comforter set", "landscape"),
    ("pillow-sleeping", "sleeping pillows bed", "landscape"),
    ("lamp-bedside", "bedside lamp table", "portrait"),

    # Bathroom
    ("towel-set", "bath towels set", "landscape"),
    ("shower-head", "shower head bathroom", "square"),
    ("bathroom-scale", "bathroom scale digital", "square"),
    ("hair-dryer", "hair dryer styling", "landscape"),

    # Tools & Garage
    ("toolbox", "toolbox tools storage", "landscape"),
    ("ladder", "step ladder folding", "portrait"),
    ("lawn-mower", "lawn mower garden", "landscape"),
    ("vacuum-cleaner", "vacuum cleaner home", "portrait"),
]

PEXELS_API_URL = "https://api.pexels.com/v1/search"
TARGET_SIZE = 1920


def search_pexels(api_key: str, query: str, orientation: str = "landscape") -> dict | None:
    """Search Pexels for images matching the query."""
    headers = {"Authorization": api_key}
    params = {
        "query": query,
        "per_page": 5,
        "orientation": orientation,
    }

    response = requests.get(PEXELS_API_URL, headers=headers, params=params)

    if response.status_code == 200:
        return response.json()
    else:
        print(f"  Error searching Pexels: {response.status_code} - {response.text}")
        return None


def download_image(url: str) -> Image.Image | None:
    """Download an image from URL and return as PIL Image."""
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        return Image.open(BytesIO(response.content))
    except Exception as e:
        print(f"  Error downloading image: {e}")
        return None


def crop_to_square(image: Image.Image) -> Image.Image:
    """Crop image to square from center."""
    width, height = image.size
    size = min(width, height)

    left = (width - size) // 2
    top = (height - size) // 2
    right = left + size
    bottom = top + size

    return image.crop((left, top, right, bottom))


def process_image(image: Image.Image, target_size: int = TARGET_SIZE) -> Image.Image:
    """Crop to square and resize to target size."""
    # Crop to square
    squared = crop_to_square(image)

    # Resize to target size
    resized = squared.resize((target_size, target_size), Image.Resampling.LANCZOS)

    return resized


def save_image(image: Image.Image, output_path: Path, quality: int = 85):
    """Save image as JPEG with specified quality."""
    # Convert to RGB if necessary (for PNG with transparency)
    if image.mode in ('RGBA', 'P'):
        image = image.convert('RGB')

    image.save(output_path, 'JPEG', quality=quality, optimize=True)


def download_and_process(
    api_key: str,
    filename: str,
    query: str,
    orientation: str,
    output_dir: Path,
    interactive: bool = True
) -> bool:
    """Search, download, and process a single image."""
    print(f"\nSearching for: {query}")

    results = search_pexels(api_key, query, orientation)
    if not results or not results.get("photos"):
        print("  No images found")
        return False

    photos = results["photos"]

    if interactive:
        # Show options and let user choose
        print(f"  Found {len(photos)} images:")
        for i, photo in enumerate(photos):
            print(f"    [{i+1}] {photo['alt'] or 'No description'} - by {photo['photographer']}")
            print(f"        {photo['src']['large2x']}")

        while True:
            choice = input(f"  Select image (1-{len(photos)}) or 's' to skip: ").strip().lower()
            if choice == 's':
                print("  Skipped")
                return False
            try:
                idx = int(choice) - 1
                if 0 <= idx < len(photos):
                    selected_photo = photos[idx]
                    break
            except ValueError:
                pass
            print(f"  Invalid choice. Enter 1-{len(photos)} or 's'")
    else:
        # Auto-select first result
        selected_photo = photos[0]
        print(f"  Auto-selected: {selected_photo['alt'] or 'No description'}")

    # Download the large version
    image_url = selected_photo["src"]["large2x"]
    print(f"  Downloading: {image_url}")

    image = download_image(image_url)
    if not image:
        return False

    print(f"  Original size: {image.size[0]}x{image.size[1]}")

    # Process image
    processed = process_image(image)
    print(f"  Processed size: {processed.size[0]}x{processed.size[1]}")

    # Save
    output_path = output_dir / f"{filename}.jpg"
    save_image(processed, output_path)
    print(f"  Saved to: {output_path}")

    return True


def main():
    parser = argparse.ArgumentParser(
        description="Download and process images from Pexels for MovingBox test assets"
    )
    parser.add_argument(
        "--api-key",
        required=True,
        help="Pexels API key (get free at https://www.pexels.com/api/)"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("./downloaded_images"),
        help="Output directory for processed images (default: ./downloaded_images)"
    )
    parser.add_argument(
        "--auto",
        action="store_true",
        help="Auto-select first result without prompting"
    )
    parser.add_argument(
        "--size",
        type=int,
        default=TARGET_SIZE,
        help=f"Target size for square images (default: {TARGET_SIZE})"
    )
    parser.add_argument(
        "--category",
        choices=["beach-house", "household", "all"],
        default="all",
        help="Which image category to download (default: all)"
    )
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="Skip images that already exist in output directory"
    )

    args = parser.parse_args()

    # Create output directory
    args.output_dir.mkdir(parents=True, exist_ok=True)

    # Determine which images to download
    images_to_download = []
    if args.category in ("beach-house", "all"):
        images_to_download.extend(BEACH_HOUSE_IMAGES)
    if args.category in ("household", "all"):
        images_to_download.extend(HOUSEHOLD_ITEMS)

    print(f"MovingBox Pexels Image Downloader")
    print(f"==================================")
    print(f"Output directory: {args.output_dir.absolute()}")
    print(f"Target size: {args.size}x{args.size}")
    print(f"Mode: {'automatic' if args.auto else 'interactive'}")
    print(f"Category: {args.category}")
    print(f"Total images to download: {len(images_to_download)}")

    # Process each image
    success_count = 0
    skipped_count = 0
    for filename, query, orientation in images_to_download:
        # Check if file already exists
        output_path = args.output_dir / f"{filename}.jpg"
        if args.skip_existing and output_path.exists():
            print(f"\nSkipping {filename} (already exists)")
            skipped_count += 1
            continue

        if download_and_process(
            api_key=args.api_key,
            filename=filename,
            query=query,
            orientation=orientation,
            output_dir=args.output_dir,
            interactive=not args.auto
        ):
            success_count += 1

    print(f"\n==================================")
    print(f"Downloaded: {success_count}/{len(images_to_download)} images")
    if skipped_count > 0:
        print(f"Skipped (existing): {skipped_count}")
    print(f"Images saved to: {args.output_dir.absolute()}")
    print(f"\nNext steps:")
    print(f"1. Review the downloaded images in {args.output_dir}")
    print(f"2. Add them to MovingBox/TestAssets.xcassets in Xcode")
    print(f"   - Drag each .jpg file into the asset catalog")
    print(f"   - The filename becomes the asset name")


if __name__ == "__main__":
    main()
