import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ble/application/ble_session_coordinator.dart';
import 'di/injector.dart';
import 'features/dashboard/presentation/simulator_cubit.dart';
import 'features/dashboard/presentation/simulator_dashboard_page.dart';

class BluetoothPlatformApp extends StatelessWidget {
  const BluetoothPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Bluetooth Platform',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F6E56)),
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (_) =>
            SimulatorCubit(getIt<BleSessionCoordinator>())..bootstrap(),
        child: const SimulatorDashboardPage(),
      ),
    );
  }
}
