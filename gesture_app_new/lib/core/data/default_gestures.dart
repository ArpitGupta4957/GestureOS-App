import 'dart:ui';
import 'package:gesture_app/core/utils/gesture_recognizer.dart';

/// Static collection of default geometric gestures (A-Z)
/// These act as the "Offline Handwriting Library" using the $1 Unistroke Algorithm.
class DefaultGestures {
  static List<GestureTemplate> get all => [
    _template("A", _pointsA),
    _template("B", _pointsB),
    _template("C", _pointsC),
    _template("D", _pointsD),
    _template("E", _pointsE),
    _template("F", _pointsF),
    _template("G", _pointsG),
    _template("H", _pointsH),
    _template("I", _pointsI),
    _template("J", _pointsJ),
    _template("K", _pointsK),
    _template("L", _pointsL),
    _template("M", _pointsM),
    _template("N", _pointsN),
    _template("O", _pointsO),
    _template("P", _pointsP),
    _template("Q", _pointsQ),
    _template("R", _pointsR),
    _template("S", _pointsS),
    _template("T", _pointsT),
    _template("U", _pointsU),
    _template("V", _pointsV),
    _template("W", _pointsW),
    _template("X", _pointsX),
    _template("Y", _pointsY),
    _template("Z", _pointsZ),
    _template("0", _points0),
    _template("1", _points1),
  ];

  static GestureTemplate _template(String name, List<Offset> points) {
    return GestureTemplate(
      name: name,
      points: points,
      metadata: {
        'isSystem': true, // Flag to identify system templates
      },
    );
  }

  // --- HARDCODED POINT DATA ---

  static const List<Offset> _pointsA = [
    Offset(10, 100),
    Offset(50, 0),
    Offset(90, 100),
    Offset(-1, -1),
    Offset(20, 60),
    Offset(80, 60),
  ];
  static const List<Offset> _pointsB = [
    Offset(20, 0),
    Offset(20, 100),
    Offset(-1, -1),
    Offset(20, 0),
    Offset(60, 0),
    Offset(80, 25),
    Offset(60, 50),
    Offset(20, 50),
    Offset(20, 50),
    Offset(70, 50),
    Offset(90, 75),
    Offset(70, 100),
    Offset(20, 100),
  ];
  static const List<Offset> _pointsC = [
    Offset(80, 20),
    Offset(50, 0),
    Offset(20, 20),
    Offset(10, 50),
    Offset(20, 80),
    Offset(50, 100),
    Offset(80, 80),
  ];
  static const List<Offset> _pointsD = [
    Offset(20, 0),
    Offset(20, 100),
    Offset(-1, -1),
    Offset(20, 0),
    Offset(60, 0),
    Offset(90, 50),
    Offset(60, 100),
    Offset(20, 100),
  ];
  static const List<Offset> _pointsE = [
    Offset(80, 0),
    Offset(20, 0),
    Offset(20, 100),
    Offset(80, 100),
    Offset(-1, -1),
    Offset(20, 50),
    Offset(70, 50),
  ];
  static const List<Offset> _pointsF = [
    Offset(80, 0),
    Offset(20, 0),
    Offset(20, 100),
    Offset(-1, -1),
    Offset(20, 50),
    Offset(70, 50),
  ];
  static const List<Offset> _pointsG = [
    Offset(80, 20),
    Offset(50, 0),
    Offset(20, 20),
    Offset(10, 50),
    Offset(20, 80),
    Offset(50, 100),
    Offset(90, 100),
    Offset(90, 60),
    Offset(60, 60),
  ];
  static const List<Offset> _pointsH = [
    Offset(20, 0),
    Offset(20, 100),
    Offset(-1, -1),
    Offset(80, 0),
    Offset(80, 100),
    Offset(-1, -1),
    Offset(20, 50),
    Offset(80, 50),
  ];
  static const List<Offset> _pointsI = [
    Offset(50, 0),
    Offset(50, 100),
    Offset(-1, -1),
    Offset(30, 0),
    Offset(70, 0),
    Offset(-1, -1),
    Offset(30, 100),
    Offset(70, 100),
  ];
  static const List<Offset> _pointsJ = [
    Offset(80, 0),
    Offset(80, 80),
    Offset(60, 100),
    Offset(20, 100),
    Offset(10, 80),
  ];
  static const List<Offset> _pointsK = [
    Offset(20, 0),
    Offset(20, 100),
    Offset(-1, -1),
    Offset(80, 0),
    Offset(20, 50),
    Offset(80, 100),
  ];
  static const List<Offset> _pointsL = [
    Offset(20, 0),
    Offset(20, 100),
    Offset(80, 100),
  ];
  static const List<Offset> _pointsM = [
    Offset(10, 100),
    Offset(10, 0),
    Offset(50, 50),
    Offset(90, 0),
    Offset(90, 100),
  ];
  static const List<Offset> _pointsN = [
    Offset(20, 100),
    Offset(20, 0),
    Offset(80, 100),
    Offset(80, 0),
  ];
  static const List<Offset> _pointsO = [
    Offset(50, 0),
    Offset(20, 20),
    Offset(10, 50),
    Offset(20, 80),
    Offset(50, 100),
    Offset(80, 80),
    Offset(90, 50),
    Offset(80, 20),
    Offset(50, 0),
  ];
  static const List<Offset> _pointsP = [
    Offset(20, 0),
    Offset(20, 100),
    Offset(-1, -1),
    Offset(20, 0),
    Offset(60, 0),
    Offset(80, 25),
    Offset(60, 50),
    Offset(20, 50),
  ];
  static const List<Offset> _pointsQ = [
    Offset(50, 0),
    Offset(20, 20),
    Offset(10, 50),
    Offset(20, 80),
    Offset(50, 100),
    Offset(80, 80),
    Offset(90, 50),
    Offset(80, 20),
    Offset(50, 0),
    Offset(-1, -1),
    Offset(60, 70),
    Offset(100, 100),
  ];
  static const List<Offset> _pointsR = [
    Offset(20, 0),
    Offset(20, 100),
    Offset(-1, -1),
    Offset(20, 0),
    Offset(60, 0),
    Offset(80, 25),
    Offset(60, 50),
    Offset(20, 50),
    Offset(80, 100),
  ];
  static const List<Offset> _pointsS = [
    Offset(80, 10),
    Offset(50, 0),
    Offset(20, 10),
    Offset(20, 40),
    Offset(50, 50),
    Offset(80, 60),
    Offset(80, 90),
    Offset(50, 100),
    Offset(20, 90),
  ];
  static const List<Offset> _pointsT = [
    Offset(50, 0),
    Offset(50, 100),
    Offset(-1, -1),
    Offset(20, 0),
    Offset(80, 0),
  ];
  static const List<Offset> _pointsU = [
    Offset(20, 0),
    Offset(20, 80),
    Offset(50, 100),
    Offset(80, 80),
    Offset(80, 0),
  ];
  static const List<Offset> _pointsV = [
    Offset(10, 0),
    Offset(50, 100),
    Offset(90, 0),
  ];
  static const List<Offset> _pointsW = [
    Offset(10, 0),
    Offset(20, 100),
    Offset(50, 50),
    Offset(80, 100),
    Offset(90, 0),
  ];
  static const List<Offset> _pointsX = [
    Offset(10, 10),
    Offset(90, 90),
    Offset(-1, -1),
    Offset(90, 10),
    Offset(10, 90),
  ];
  static const List<Offset> _pointsY = [
    Offset(10, 0),
    Offset(50, 50),
    Offset(90, 0),
    Offset(-1, -1),
    Offset(50, 50),
    Offset(50, 100),
  ];
  static const List<Offset> _pointsZ = [
    Offset(10, 10),
    Offset(90, 10),
    Offset(10, 90),
    Offset(90, 90),
  ];

  static const List<Offset> _points0 = [
    Offset(50, 0),
    Offset(20, 20),
    Offset(10, 50),
    Offset(20, 80),
    Offset(50, 100),
    Offset(80, 80),
    Offset(90, 50),
    Offset(80, 20),
    Offset(50, 0),
  ];
  static const List<Offset> _points1 = [Offset(50, 0), Offset(50, 100)];
}
