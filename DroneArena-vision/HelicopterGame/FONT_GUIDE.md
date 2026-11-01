# Font Configuration Guide

## Quick Start: Change Fonts Globally

All fonts in the app are now centralized in `Styles.swift` through the `FontConfig` struct. To test different fonts across the entire app, simply change these two lines:

```swift
// In Styles.swift, line 64-65:
static let displayFontName = "SF Pro Display"  // Change this
static let textFontName = "SF Pro Text"        // Change this
```

## Example: Testing Different Fonts

### Try Futura (Modern, Geometric)
```swift
static let displayFontName = "Futura"
static let textFontName = "Futura"
```

### Try Avenir Next (Clean, Professional)
```swift
static let displayFontName = "Avenir Next"
static let textFontName = "Avenir Next"
```

### Try Menlo (Technical, Monospaced)
```swift
static let displayFontName = "Menlo"
static let textFontName = "Menlo"
```

### Try Copperplate (Bold, Structured)
```swift
static let displayFontName = "Copperplate"
static let textFontName = "Copperplate"
```

## Additional Customization

### Adjust Font Sizes Globally
```swift
// Make all fonts 10% larger
static let sizeMultiplier: CGFloat = 1.1

// Make all fonts 10% smaller
static let sizeMultiplier: CGFloat = 0.9
```

### Adjust Font Weights
```swift
// Make displays even bolder
static let displayWeight: Font.Weight = .heavy  // or .black (current)

// Make body text lighter
static let bodyWeight: Font.Weight = .light  // or .regular (current)
```

## Built-in iOS Fonts You Can Try

These fonts are available on all iOS devices without adding custom font files:

**Sans-Serif (Modern)**
- `SF Pro Display` / `SF Pro Text` (Default - Apple's system font)
- `Helvetica Neue`
- `Avenir Next`
- `Futura`
- `Trebuchet MS`

**Monospaced (Technical)**
- `Menlo`
- `Courier New`
- `Monaco`

**Display/Decorative**
- `Copperplate`
- `American Typewriter`
- `DIN Alternate` (if available on device)
- `Optima`

**Serif (Classic)**
- `Georgia`
- `Times New Roman`
- `Palatino`

## How Every Text Element Uses These Fonts

All text in your app uses `SteelTypography` which references `FontConfig`:

| Component | Font Style | Where It's Used |
|-----------|-----------|----------------|
| Titles | `SteelTypography.title` | Screen headers, main titles |
| Headlines | `SteelTypography.headline` | Section headers, card titles |
| Body | `SteelTypography.body` | Regular text, descriptions |
| Buttons | `SteelTypography.button` | All button labels |
| Captions | `SteelTypography.caption` | Small labels, metadata |
| HUD Labels | `SteelTypography.hudLabel` | Timers, scores, stats |
| Display | `SteelTypography.display` | Large hero text |

### Examples from Your App:

**Buttons (ChromeButton, GlassButton)**
```swift
Text(title)
    .font(SteelTypography.button)  // Uses FontConfig
```

**Card Headers**
```swift
Text("Game Settings")
    .font(SteelTypography.headline)  // Uses FontConfig
```

**Body Text**
```swift
Text("Description text")
    .font(SteelTypography.body)  // Uses FontConfig
```

## Adding Custom Fonts (Advanced)

To use a custom font like "Orbitron" or "Rajdhani":

1. **Add font file to Xcode**
   - Drag `.ttf` or `.otf` file into project
   - Check "Copy items if needed"
   - Add to target

2. **Update Info.plist**
   ```xml
   <key>UIAppFonts</key>
   <array>
       <string>Orbitron-Bold.ttf</string>
       <string>Orbitron-Regular.ttf</string>
   </array>
   ```

3. **Update FontConfig**
   ```swift
   static let displayFontName = "Orbitron-Bold"
   static let textFontName = "Orbitron-Regular"
   ```

## Recommended Gaming Fonts

**Sci-Fi/Tech**
- Orbitron - Geometric, futuristic
- Exo 2 - Modern, technical
- Audiowide - Bold, digital
- Rajdhani - Clean, structured

**Military/Tactical**
- DIN Alternate (built-in on some devices)
- Copperplate (built-in)
- Impact (built-in)

## Testing Workflow

1. **Open** `Styles.swift`
2. **Change** `FontConfig.displayFontName` and `FontConfig.textFontName` (lines 64-65)
3. **Build & Run** - The entire app will use the new font
4. **Iterate** - Try different fonts until you find the perfect match
5. **Fine-tune** - Adjust `sizeMultiplier` and weights as needed

## Current Font Usage Across the App

Your app already uses `SteelTypography` everywhere via:
- ✅ ChromeButton
- ✅ GlassButton
- ✅ SteelCard headers
- ✅ StatusChip labels
- ✅ SteelToggle labels
- ✅ SteelSegmentedControl
- ✅ All menu screens
- ✅ All settings panels
- ✅ All HUD elements

**Result:** Changing `FontConfig` updates EVERYTHING instantly.

## Troubleshooting

**Font doesn't appear?**
- Check spelling (case-sensitive)
- Verify font is installed on device
- For custom fonts, check Info.plist entry

**Font looks wrong?**
- Try adjusting the weight (`.black`, `.bold`, `.semibold`, `.regular`, `.light`)
- Try adjusting the size multiplier

**Some text still using old font?**
- Search codebase for `.font(` to find any hardcoded Font values
- Replace with `SteelTypography.*` equivalents
