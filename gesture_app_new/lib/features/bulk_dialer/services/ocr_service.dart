
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<List<String>> extractPhoneNumbers(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await textRecognizer.processImage(inputImage);

    // Filter logic: Basic regex for potential phone numbers
    // This looks for sequences of 7+ digits, possibly with separators
    final phoneRegex = RegExp(r"(\+?\d{1,3}[-.\s]?)?(\(?\d{3}\)?[-.\s]?)?\d{3}[-.\s]?\d{4}");
    
    List<String> numbers = [];

    // Iterate through blocks -> lines -> text
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        final matches = phoneRegex.allMatches(line.text);
        for (final match in matches) {
          // Clean the number
          String raw = match.group(0) ?? "";
          String clean = raw.replaceAll(RegExp(r"[^0-9+]"), ""); 
          
          if (clean.length >= 7) { // Basic sanity check
             numbers.add(clean);
          }
        }
      }
    }
    
    // De-duplicate
    return numbers.toSet().toList();
  }

  void dispose() {
    textRecognizer.close();
  }
}
