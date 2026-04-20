# Assets Folder

This folder contains all the static assets used in the Mediai Flutter application.

## Folder Structure

```
assets/
├── images/          # Image assets (PNG, JPG, etc.)
├── icons/           # Icon assets (PNG, SVG, etc.)
├── fonts/           # Custom font files (TTF, OTF)
└── README.md        # This file
```

## Usage

### Images
Place your image assets in the `images/` folder. Common image types include:
- Logo files
- Background images
- Placeholder images
- UI illustrations

### Icons
Place your icon assets in the `icons/` folder. Common icon types include:
- Social media icons (Google, Facebook, Apple)
- UI icons
- App-specific icons

### Fonts
Place your custom font files in the `fonts/` folder. Supported formats:
- TTF (TrueType Font)
- OTF (OpenType Font)

## Asset Management

Use the `AssetUtils` class in `lib/utils/asset_utils.dart` to manage asset paths:

```dart
// Get image path
String logoPath = AssetUtils.logo;
String customImage = AssetUtils.getImagePath('my_image.png');

// Get icon path
String googleIcon = AssetUtils.googleIcon;
String customIcon = AssetUtils.getIconPath('my_icon.png');

// Get font path
String primaryFont = AssetUtils.primaryFont;
String customFont = AssetUtils.getFontPath('my_font.ttf');
```

## Adding New Assets

1. Place your asset file in the appropriate folder
2. Update `AssetUtils` class if needed
3. Run `flutter pub get` to refresh assets
4. Use the asset in your code

## Best Practices

- Use descriptive file names
- Optimize images for mobile (compress when possible)
- Use vector icons when possible for scalability
- Follow naming conventions (snake_case for files)
- Keep assets organized in subfolders if needed







