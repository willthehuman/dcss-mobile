enum KeyboardLayer {
  move,
  act,
  char,
  more,
  keys,
}

extension KeyboardLayerLabel on KeyboardLayer {
  String get title {
    switch (this) {
      case KeyboardLayer.move:
        return 'Move';
      case KeyboardLayer.act:
        return 'Act';
      case KeyboardLayer.char:
        return 'Char';
      case KeyboardLayer.more:
        return 'More';
      case KeyboardLayer.keys:
        return 'Keys';
    }
  }
}
