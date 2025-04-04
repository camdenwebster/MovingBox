from PIL import Image
import os

def generate_app_icons(source_image_path, output_dir):
    # Define the sizes needed for iOS app icons
    icon_sizes = {
        # Format: (output_name, size, scale)
        "20@2x": (40, 2),  # 20pt @2x
        "20@3x": (60, 3),  # 20pt @3x
        "29@2x": (58, 2),  # 29pt @2x
        "29@3x": (87, 3),  # 29pt @3x
        "40@2x": (80, 2),  # 40pt @2x
        "40@3x": (120, 3), # 40pt @3x
        "60@2x": (120, 2), # 60pt @2x
        "60@3x": (180, 3), # 60pt @3x
        "1024": (1024, 1)  # App Store
    }

    # Open the source image
    try:
        with Image.open(source_image_path) as img:
            # Convert to RGBA if not already
            if img.mode != 'RGBA':
                img = img.convert('RGBA')

            # Create output directory if it doesn't exist
            os.makedirs(output_dir, exist_ok=True)

            # Generate each size
            for name, (size, scale) in icon_sizes.items():
                final_size = size
                output_name = f"AppIcon.beta-{name}.png"
                output_path = os.path.join(output_dir, output_name)

                # Resize the image
                resized = img.resize((final_size, final_size), Image.Resampling.LANCZOS)
                
                # Save the resized image
                resized.save(output_path, 'PNG')
                print(f"Generated {output_name} ({final_size}x{final_size})")

    except Exception as e:
        print(f"Error processing image: {e}")
        return

if __name__ == "__main__":
    # Update these paths for your project
    source_image = "Assets.xcassets/AppIcon.beta.appiconset/Light Icon.png"
    output_directory = "Assets.xcassets/AppIcon.beta.appiconset"

    if not os.path.exists(source_image):
        print(f"Error: Source image not found at {source_image}")
        print("Please update the source_image path in the script.")
        exit(1)

    generate_app_icons(source_image, output_directory)
    print("\nDone! All icon sizes generated successfully.")
    print("\nMake sure to:")
    print("1. Check that all images were generated correctly")
    print("2. Update the Contents.json file if needed")
    print("3. Clean and rebuild your Xcode project")
