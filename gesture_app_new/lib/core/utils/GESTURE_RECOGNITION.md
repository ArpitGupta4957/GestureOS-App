# Gesture Recognition System

## 📚 Overview

This Flutter gesture recognition system implements the **$1 Unistroke Recognizer** algorithm, a simple yet powerful template-based gesture recognition approach.

## 🎯 Features

- ✅ **Template Matching**: Compare drawn gestures against saved templates
- ✅ **Normalization**: Automatic resampling, rotation, and scaling
- ✅ **High Accuracy**: 80%+ match threshold for reliable recognition
- ✅ **Fast Performance**: Optimized golden section search algorithm
- ✅ **Easy Integration**: Simple API for creating and recognizing gestures

## 📖 How It Works

### The $1 Algorithm Steps:

1. **Resample** - Normalize to 64 evenly-spaced points
2. **Rotate** - Align to indicative angle (zero rotation)
3. **Scale** - Fit to reference 250x250 square
4. **Translate** - Center at origin
5. **Match** - Compare using path distance calculation
6. **Score** - Return similarity score (0.0 to 1.0)

## 💻 Usage

### Basic Example

```dart
import 'package:gesture_app/core/utils/gesture_recognizer.dart';

// Step 1: Create templates from saved gestures
List<GestureTemplate> templates = [
  GestureRecognizer.createTemplate('circle', circlePoints),
  GestureRecognizer.createTemplate('swipe_right', swipePoints),
];

// Step 2: Recognize a new gesture
RecognitionResult result = GestureRecognizer.recognize(
  userDrawnPoints,
  templates,
);

// Step 3: Check the result
if (result.isMatch(threshold: 0.8)) {
  print('Matched: ${result.name}');
  print('Confidence: ${(result.score * 100).toStringAsFixed(1)}%');
}
```

### Creating Templates

```dart
// From user drawing
List<Offset> points = [...]; // Points from DrawGestureScreen
GestureTemplate template = GestureRecognizer.createTemplate('my_gesture', points);

// Save to database or local storage
Map<String, dynamic> json = template.toJson();

// Load from storage
GestureTemplate loaded = GestureTemplate.fromJson(json);
```

### Recognition with Actions

```dart
void recognizeAndExecute(List<Offset> points) {
  final result = GestureRecognizer.recognize(points, savedTemplates);
  
  if (result.isMatch()) { // Default threshold is 0.8
    switch (result.name) {
      case 'swipe_left':
        performSwipeLeftAction();
        break;
      case 'circle':
        performRefreshAction();
        break;
      default:
        print('Unknown gesture: ${result.name}');
    }
  } else {
    print('No match found (score: ${result.score})');
  }
}
```

## 🎨 Integration with DrawGestureScreen

```dart
// In DrawGestureScreen
void _handleSave() {
  if (_points.isEmpty) return;
  
  // Option 1: Create template for recognition
  final template = GestureRecognizer.createTemplate('new_gesture', _points);
  savedTemplates.add(template);
  
  // Option 2: Recognize against existing templates
  final result = GestureRecognizer.recognize(_points, existingTemplates);
  if (result.isMatch()) {
    print('You drew a ${result.name}!');
  }
}
```

## 📊 Recognition Results

### RecognitionResult Properties

```dart
class RecognitionResult {
  String name;           // Name of matched template
  double score;          // Similarity score (0.0 to 1.0)
  GestureTemplate? template; // The matched template
  
  bool isMatch({double threshold = 0.8}); // Check if match is good enough
}
```

### Score Interpretation

| Score Range | Meaning |
|------------|---------|
| 0.9 - 1.0  | Excellent match (nearly identical) |
| 0.8 - 0.9  | Good match (recommended threshold) |
| 0.6 - 0.8  | Fair match (possible but uncertain) |
| 0.0 - 0.6  | Poor match (not recognized) |

## 🔧 Configuration

### Adjust Recognition Sensitivity

```dart
// More strict (fewer false positives)
if (result.isMatch(threshold: 0.9)) { ... }

// More lenient (more matches, more false positives)
if (result.isMatch(threshold: 0.7)) { ... }
```

### Algorithm Constants

Located in `GestureRecognizer` class:

```dart
static const int numPoints = 64;          // Resampling resolution
static const double squareSize = 250.0;   // Reference square size
static const double angleRange = 45.0;    // Rotation search range
static const double anglePrecision = 2.0; // Rotation step size
```

## 📝 Best Practices

### Creating Good Templates

1. **Consistent Drawing**: Draw gestures similarly each time
2. **Adequate Points**: Ensure at least 20-30 points for simple gestures
3. **Distinct Shapes**: Make gestures visually different from each other
4. **Multiple Samples**: Create 2-3 templates per gesture for better accuracy

### Performance Tips

1. **Limit Templates**: Keep template count reasonable (< 50)
2. **Cache Results**: Store normalized templates
3. **Batch Processing**: Process recognition in background if needed

## 🐛 Troubleshooting

### Low Recognition Scores

- **Issue**: All scores below 0.5
- **Solution**: Ensure gestures have enough points (minimum 10)

### False Matches

- **Issue**: Wrong gesture recognized
- **Solution**: Increase threshold or make gestures more distinct

### Slow Recognition

- **Issue**: Recognition takes too long
- **Solution**: Reduce number of templates or adjust `anglePrecision`

## 📚 References

- [Wobbrock, J.O., Wilson, A.D., and Li, Y. (2007). Gestures without libraries, toolkits or training: A $1 recognizer for user interface prototypes.](https://dl.acm.org/doi/10.1145/1294211.1294238)
- [$1 Unistroke Recognizer](https://depts.washington.edu/acelab/proj/dollar/index.html)

## 🚀 Next Steps

1. Integrate with database to persist templates
2. Add multi-stroke gesture support
3. Implement gesture training mode
4. Create gesture library with common patterns
