import 'package:material_ui/material_ui.dart';

import 'screens/admin/ward_officer_management_screen.dart';
import 'screens/login_screen.dart';
import 'services/firebase_bootstrap.dart';
import 'theme/app_theme.dart';
import 'widgets/update_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never blocks start-up: without Firebase config the app runs in offline
  // demo mode and the auth screens still work.
  await FirebaseBootstrap.initialize();
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
      routes: {
        WardOfficerManagementScreen.routeName: (_) =>
            const WardOfficerManagementScreen(),
      },
    );
  }
}
