const Map<String, String> _shiftCharacterMap = <String, String>{
  '1': '!',
  '2': '@',
  '3': '#',
  '4': r'$',
  '5': '%',
  '6': '^',
  '7': '&',
  '8': '*',
  '9': '(',
  '0': ')',
  '-': '_',
  '=': '+',
  '[': '{',
  ']': '}',
  '\\': '|',
  ';': ':',
  "'": '"',
  ',': '<',
  '.': '>',
  '/': '?',
  '`': '~',
};

int ctrlKey(String character) {
  if (character.isEmpty) {
    return 0;
  }

  final int code = character.toLowerCase().codeUnitAt(0);
  if (code < 97 || code > 122) {
    return code;
  }
  return code - 96;
}

int shiftedKey(String character) {
  if (character.isEmpty) {
    return 0;
  }

  final String shifted =
      _shiftCharacterMap[character] ?? character.toUpperCase();
  return shifted.codeUnitAt(0);
}

int keycodeForCharacter(
  String character, {
  bool applyShift = false,
  bool applyCtrl = false,
}) {
  if (applyCtrl) {
    return ctrlKey(character);
  }
  if (applyShift) {
    return shiftedKey(character);
  }
  return character.codeUnitAt(0);
}
