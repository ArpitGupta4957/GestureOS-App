void main() {
  String name = "Bhavik Patil";
  int shortcutLength = 2;

  final words = name
      .replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ')
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  print("Words: $words");
  print("Count: ${words.length}");

  String shortcut = "";

  if (shortcutLength == 2) {
    if (words.length >= 2) {
      shortcut = words[0][0] + words[1][0];
    } else {
      shortcut = words[0].substring(
        0,
        words[0].length >= 2 ? 2 : words[0].length,
      );
    }
  } else if (shortcutLength == 3) {
    if (words.length >= 3) {
      shortcut = words[0][0] + words[1][0] + words[2][0];
    } else if (words.length == 2) {
      shortcut =
          words[0][0] +
          words[1].substring(0, words[1].length >= 2 ? 2 : words[1].length);
    } else {
      shortcut = words[0].substring(
        0,
        words[0].length >= 3 ? 3 : words[0].length,
      );
    }
  } else if (shortcutLength == 4) {
    if (words.length >= 4) {
      shortcut = words[0][0] + words[1][0] + words[2][0] + words[3][0];
    } else if (words.length == 3) {
      shortcut =
          words[0][0] +
          words[1][0] +
          words[2].substring(0, words[2].length >= 2 ? 2 : words[2].length);
    } else if (words.length == 2) {
      shortcut =
          words[0].substring(0, words[0].length >= 2 ? 2 : words[0].length) +
          words[1].substring(0, words[1].length >= 2 ? 2 : words[1].length);
    } else {
      shortcut = words[0].substring(
        0,
        words[0].length >= 4 ? 4 : words[0].length,
      );
    }
  }

  print("Shortcut: $shortcut");
}
