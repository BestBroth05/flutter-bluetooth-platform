import 'package:flutter/material.dart';

import 'app.dart';
import 'di/injector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const BluetoothPlatformApp());
}
