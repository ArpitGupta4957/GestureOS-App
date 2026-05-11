import 'dart:math';
import 'package:flutter/material.dart'; // For Offset

/// Simple Bounding Box
class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;

  double get left => x;
  double get top => y;

  BoundingBox(this.x, this.y, this.width, this.height);
}

/// Result of a gesture recognition attempt
class RecognitionResult {
  final String name;
  final double score;
  final GestureTemplate? template;

  RecognitionResult(this.name, this.score, {this.template});

  @override
  String toString() => '$name (Score: ${score.toStringAsFixed(2)})';
}

/// Helper class for Template storage
class GestureTemplate {
  final String name;
  final List<Offset> points;
  final Map<String, dynamic>? metadata;

  // Stored processed points for algorithm
  late final List<Offset> processedPoints;

  GestureTemplate({required this.name, required this.points, this.metadata}) {
    // Pre-process on creation
    processedPoints = GestureRecognizer.normalize(points);
  }
}

/// $1 Unistroke Recognizer Implementation (Static Utility)
class GestureRecognizer {
  // Constants for the algorithm
  static const int _numPoints = 64;
  static const double _squareSize = 250.0;
  static const double _phi =
      0.5 * (-1.0 + 2.23606797749979); // (sqrt(5) - 1) / 2

  /// Normalize points (Resample -> Rotate -> Scale -> Translate)
  static List<Offset> normalize(List<Offset> points) {
    if (points.isEmpty) return [];
    List<Offset> candidate = _resample(points, _numPoints);
    candidate = _rotateToZero(candidate);
    candidate = _scaleToSquare(candidate, _squareSize);
    candidate = _translateToOrigin(candidate);
    return candidate;
  }

  /// Recognize a gesture against a list of templates
  static List<RecognitionResult> recognize(
    List<Offset> points,
    List<GestureTemplate> templates,
  ) {
    if (points.isEmpty || templates.isEmpty) {
      return [];
    }

    // Process candidate
    final candidate = normalize(points);
    if (candidate.isEmpty) return [];

    List<RecognitionResult> results = [];

    // Compare against all templates
    for (var i = 0; i < templates.length; i++) {
      // Safety check
      if (templates[i].processedPoints.isEmpty) continue;

      final double distance = _distanceAtBestAngle(
        candidate,
        templates[i].processedPoints,
        -_deg2Rad(45.0),
        _deg2Rad(45.0),
        _deg2Rad(2.0),
      );

      // Score
      final double score =
          1.0 -
          (distance /
              (0.5 *
                  sqrt(_squareSize * _squareSize + _squareSize * _squareSize)));
      results.add(
        RecognitionResult(
          templates[i].name,
          max(0.0, score),
          template: templates[i],
        ),
      );
    }

    // Sort descending
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  // --- Private Helper Methods ---

  /// Smoothly resample the points into n equidistant points
  static List<Offset> _resample(List<Offset> inputPoints, int n) {
    if (inputPoints.isEmpty) return [];

    // Create a mutable copy to avoid modifying original list (especially if const)
    List<Offset> points = List.from(inputPoints);

    // Safety for single point
    if (points.length == 1) return List.filled(n, points.first);

    // 1. Calculate Total Path Length (Excluding Jumps)
    double totalLength = 0.0;
    for (int i = 1; i < points.length; i++) {
      // Skip jumps (Separator is -1,-1)
      if (points[i] == const Offset(-1.0, -1.0) ||
          points[i - 1] == const Offset(-1.0, -1.0)) {
        continue;
      }
      totalLength += _distance(points[i - 1], points[i]);
    }

    double interval = totalLength / (n - 1);
    // If length is 0 (just dots), return simple fill
    if (totalLength == 0) return List.filled(n, points.first);

    double D = 0.0;
    List<Offset> newPoints = [points[0]];

    // 2. Iterate and Resample
    // We iterate through original points. If we hit a separator, we jump.
    for (int i = 1; i < points.length; i++) {
      if (points[i] == const Offset(-1.0, -1.0)) {
        // Jump detected. The next point is the start of a new stroke.
        continue;
      }
      if (points[i - 1] == const Offset(-1.0, -1.0)) {
        // We just came from a jump. Reset D?
        // Actually, Unistroke templates usually just connect
        // but cleaner to treat as continuous ink for resampling distance.
        // For simple $1, we just skip the distance add.
        continue;
      }

      Offset p1 = points[i - 1];
      Offset p2 = points[i];
      double d = _distance(p1, p2);

      if ((D + d) >= interval) {
        double qx = p1.dx + ((interval - D) / d) * (p2.dx - p1.dx);
        double qy = p1.dy + ((interval - D) / d) * (p2.dy - p1.dy);
        Offset q = Offset(qx, qy);
        newPoints.add(q);

        // Logic: we inserted 'q'
        // In standard algorithm, we insert 'q' into points list.
        // Here we just update p1 logically by reducing d
        points.insert(i, q);
        D = 0.0;
      } else {
        D += d;
      }
    }

    // Fill remaining if rounding errors
    while (newPoints.length < n) {
      newPoints.add(points.last);
    }

    return newPoints;
  }

  static List<Offset> _rotateToZero(List<Offset> points) {
    if (points.isEmpty) return [];
    Offset c = _centroid(points);
    double radians = atan2(c.dy - points[0].dy, c.dx - points[0].dx);
    return _rotateBy(points, -radians);
  }

  static List<Offset> _rotateBy(List<Offset> points, double radians) {
    if (points.isEmpty) return [];
    Offset c = _centroid(points);
    double cosVal = cos(radians);
    double sinVal = sin(radians);

    List<Offset> newPoints = [];
    for (var p in points) {
      double qx = (p.dx - c.dx) * cosVal - (p.dy - c.dy) * sinVal + c.dx;
      double qy = (p.dx - c.dx) * sinVal + (p.dy - c.dy) * cosVal + c.dy;
      newPoints.add(Offset(qx, qy));
    }
    return newPoints;
  }

  static List<Offset> _scaleToSquare(List<Offset> points, double size) {
    if (points.isEmpty) return [];
    BoundingBox box = boundingBox(points);
    List<Offset> newPoints = [];
    for (var p in points) {
      double qx = p.dx * (size / box.width);
      double qy = p.dy * (size / box.height);
      newPoints.add(Offset(qx, qy));
    }
    return newPoints;
  }

  static List<Offset> _translateToOrigin(List<Offset> points) {
    if (points.isEmpty) return [];
    Offset c = _centroid(points);
    List<Offset> newPoints = [];
    for (var p in points) {
      double qx = p.dx - c.dx;
      double qy = p.dy - c.dy;
      newPoints.add(Offset(qx, qy));
    }
    return newPoints;
  }

  static double _distanceAtBestAngle(
    List<Offset> points,
    List<Offset> templatePoints,
    double fromAngle,
    double toAngle,
    double threshold,
  ) {
    double x1 = _phi * fromAngle + (1.0 - _phi) * toAngle;
    double f1 = _distanceAtAngle(points, templatePoints, x1);
    double x2 = (1.0 - _phi) * fromAngle + _phi * toAngle;
    double f2 = _distanceAtAngle(points, templatePoints, x2);

    while ((toAngle - fromAngle).abs() > threshold) {
      if (f1 < f2) {
        toAngle = x2;
        x2 = x1;
        f2 = f1;
        x1 = _phi * fromAngle + (1.0 - _phi) * toAngle;
        f1 = _distanceAtAngle(points, templatePoints, x1);
      } else {
        fromAngle = x1;
        x1 = x2;
        f1 = f2;
        x2 = (1.0 - _phi) * fromAngle + _phi * toAngle;
        f2 = _distanceAtAngle(points, templatePoints, x2);
      }
    }
    return min(f1, f2);
  }

  static double _distanceAtAngle(
    List<Offset> points,
    List<Offset> templatePoints,
    double radians,
  ) {
    List<Offset> newPoints = _rotateBy(points, radians);
    return _pathDistance(newPoints, templatePoints);
  }

  static double _pathDistance(List<Offset> pts1, List<Offset> pts2) {
    double d = 0.0;
    int length = min(pts1.length, pts2.length);
    for (int i = 0; i < length; i++) {
      d += _distance(pts1[i], pts2[i]);
    }
    return d / length;
  }

  static double _distance(Offset p1, Offset p2) {
    double dx = p1.dx - p2.dx;
    double dy = p1.dy - p2.dy;
    return sqrt(dx * dx + dy * dy);
  }

  static Offset _centroid(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    double x = 0.0;
    double y = 0.0;
    for (var p in points) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / points.length, y / points.length);
  }

  static BoundingBox boundingBox(List<Offset> points) {
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var p in points) {
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
    }

    double w = maxX - minX;
    double h = maxY - minY;
    if (w == 0) w = 1.0; // Avoid division by zero
    if (h == 0) h = 1.0;

    return BoundingBox(minX, minY, w, h);
  }

  /// Calculate total path length
  static double pathLength(List<Offset> points) {
    double d = 0.0;
    for (int i = 1; i < points.length; i++) {
      if (points[i] == const Offset(-1, -1) ||
          points[i - 1] == const Offset(-1, -1)) {
        continue;
      }
      d += _distance(points[i - 1], points[i]);
    }
    return d;
  }

  static double _deg2Rad(double d) {
    return (d * pi / 180.0);
  }
}
