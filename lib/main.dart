import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'state/library_scope.dart';
import 'state/library_store.dart';
import 'theme/tomo_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LibraryStore();
  await store.load();
  runApp(TomoApp(store: store));
}

class TomoApp extends StatelessWidget {
  final LibraryStore store;

  const TomoApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return LibraryScope(
      store: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TOMO',
        theme: tomoTheme(),
        home: const HomePage(),
      ),
    );
  }
}
