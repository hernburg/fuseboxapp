class History<T> {
  final List<T> _stack = [];
  final List<T> _redo = [];

  void push(T state) {
    _stack.add(state);
    _redo.clear();
  }

  T? undo() {
    if (_stack.length <= 1) return _stack.isEmpty ? null : _stack.last;
    final last = _stack.removeLast();
    _redo.add(last);
    return _stack.last;
  }

  T? redo() {
    if (_redo.isEmpty) return _stack.isEmpty ? null : _stack.last;
    final next = _redo.removeLast();
    _stack.add(next);
    return next;
  }

  T? get current => _stack.isEmpty ? null : _stack.last;

  bool get canUndo => _stack.length > 1;
  bool get canRedo => _redo.isNotEmpty;
}