import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/child_home_screen.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  final appState = AppState(storage);
  await appState.load();

  runApp(YomitamaApp(appState: appState));
}

class YomitamaApp extends StatelessWidget {
  final AppState appState;
  const YomitamaApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        title: 'よみたま',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const ChildHomeScreen(),
      ),
    );
  }
}
