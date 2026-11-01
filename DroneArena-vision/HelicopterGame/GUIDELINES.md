# Development Guidelines

## Platform Requirements
- **Target Platform**: visionOS 2.0
- **Minimum Deployment**: visionOS 2.0
- **Primary Frameworks**:
  - RealityKit (visionOS version)
  - SwiftUI (visionOS version)
  - ARKit (visionOS version)
  - Metal (visionOS version)

## Code Style & Patterns

### Project Structure
- All new features should follow the existing modular structure
- Place new components in appropriate subsystems
- Follow the established naming conventions:
  - Systems: `[Name]System`
  - Components: `[Name]Component`
  - Views: `[Name]View`
  - Tools: `[Name]Tool`

### VisionOS-Specific Considerations
- Use visionOS-specific APIs and patterns
- Avoid iOS-specific implementations
- Leverage visionOS spatial computing features
- Consider spatial UI/UX patterns

### RealityKit Integration
- Use RealityKit's visionOS-specific features
- Implement proper spatial anchors
- Handle spatial tracking appropriately
- Use visionOS-specific material and rendering features

### SwiftUI Implementation
- Use visionOS-specific SwiftUI components
- Implement proper spatial layouts
- Handle spatial gestures correctly
- Consider visionOS window management

### ARKit Integration
- Use visionOS-specific ARKit features
- Implement proper spatial tracking
- Handle environment scanning appropriately
- Use visionOS-specific scene reconstruction

### Metal Implementation
- Use visionOS-specific Metal features
- Implement proper spatial rendering
- Handle visionOS-specific shader requirements
- Consider visionOS performance characteristics

## Common Patterns

### System Implementation
```swift
class [Name]System {
    // System state management
    private var state: [Name]State
    
    // Component management
    private var components: [Entity: [Name]Component]
    
    // System initialization
    init() {
        // Initialize system
    }
    
    // System update
    func update() {
        // Update logic
    }
}
```

### Component Implementation
```swift
struct [Name]Component {
    // Component properties
    var property1: Type
    var property2: Type
    
    // Component initialization
    init() {
        // Initialize component
    }
}
```

### View Implementation
```swift
struct [Name]View: View {
    // View properties
    @State private var state: [Name]State
    
    // View body
    var body: some View {
        // View implementation
    }
}
```

### Tool Implementation
```swift
class [Name]Tool {
    // Tool state
    private var state: [Name]ToolState
    
    // Tool initialization
    init() {
        // Initialize tool
    }
    
    // Tool operations
    func operation() {
        // Operation implementation
    }
}
```

## Best Practices

### Performance
- Optimize for visionOS performance characteristics
- Use efficient spatial data structures
- Handle memory management appropriately

### Spatial Computing
- Consider spatial context in all implementations
- Handle spatial relationships properly
- Implement appropriate spatial interactions
- Consider spatial audio when relevant

### User Experience
- Follow visionOS design guidelines
- Implement proper spatial feedback
- Handle spatial gestures appropriately
- Consider spatial comfort zones

### Testing
- Test in visionOS environment
- Verify spatial interactions
- Check performance in spatial context
- Validate spatial UI/UX

## Common Pitfalls to Avoid
- Using iOS-specific APIs
- Ignoring spatial context
- Poor performance optimization
- Inappropriate spatial interactions
- Incorrect spatial UI/UX patterns

## Resources
- [visionOS Documentation](https://developer.apple.com/visionos/)
- [RealityKit for visionOS](https://developer.apple.com/documentation/realitykit)
- [SwiftUI for visionOS](https://developer.apple.com/documentation/swiftui)
- [ARKit for visionOS](https://developer.apple.com/documentation/arkit)
- [Metal for visionOS](https://developer.apple.com/documentation/metal) 
