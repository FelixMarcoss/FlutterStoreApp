import 'package:flutter/material.dart';

import 'app.dart';
import 'features/alert/alert_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlertService.instance.init();
  runApp(const App());
}
