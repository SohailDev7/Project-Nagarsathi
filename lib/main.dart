import 'package:material_ui/material_ui.dart';

import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/update_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NagarSathiApp());
}

class NagarSathiApp extends StatefulWidget {
  const NagarSathiApp({super.key});

  @override
  State<NagarSathiApp> createState() => _NagarSathiAppState();
}

class _NagarSathiAppState extends State<NagarSathiApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NagarSathi',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: buildAppTheme(),
      builder: (context, child) => UpdateGate(
        navigatorKey: _navigatorKey,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const LoginScreen(),
    );
  }
}
