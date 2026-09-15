import 'package:flutter/material.dart';

import 'library_store.dart';

class LibraryScope extends InheritedNotifier<LibraryStore> {
  const LibraryScope({
    super.key,
    required LibraryStore store,
    required super.child,
  }) : super(notifier: store);

  static LibraryStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LibraryScope>();
    assert(scope != null, 'LibraryScope not found');
    return scope!.notifier!;
  }

  static LibraryStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<LibraryScope>();
    assert(scope != null, 'LibraryScope not found');
    return scope!.notifier!;
  }
}
