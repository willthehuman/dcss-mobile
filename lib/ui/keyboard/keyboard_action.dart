class KeyboardAction {
  const KeyboardAction.character(
    String value, {
    this.forceCtrl = false,
  })  : character = value,
        keycode = null,
        assert(value.length == 1);

  const KeyboardAction.keycode(int value)
      : keycode = value,
        character = null,
        forceCtrl = false;

  final String? character;
  final int? keycode;
  final bool forceCtrl;
}
