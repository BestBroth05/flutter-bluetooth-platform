import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../ble/domain/models/ble_connection_state.dart';
import 'simulator_cubit.dart';

/// Minimal portfolio shell for exercising the BLE simulator.
class SimulatorDashboardPage extends StatelessWidget {
  const SimulatorDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Platform Simulator')),
      body: BlocBuilder<SimulatorCubit, SimulatorState>(
        builder: (context, state) {
          final cubit = context.read<SimulatorCubit>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Session: ${state.connectionState.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (state.selectedDeviceId != null)
                Text('Connected device: ${state.selectedDeviceId}'),
              if (state.lastError != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.lastError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: state.isScanning || state.busy
                        ? null
                        : cubit.startScan,
                    child: Text(state.isScanning ? 'Scanning…' : 'Scan'),
                  ),
                  OutlinedButton(
                    onPressed: state.isScanning ? cubit.stopScan : null,
                    child: const Text('Stop scan'),
                  ),
                  FilledButton.tonal(
                    onPressed:
                        state.connectionState == BleConnectionState.connected &&
                            !state.busy
                        ? cubit.sendDemoCommand
                        : null,
                    child: const Text('Write command'),
                  ),
                  OutlinedButton(
                    onPressed:
                        state.connectionState !=
                                BleConnectionState.disconnected &&
                            !state.busy
                        ? cubit.disconnect
                        : null,
                    child: const Text('Disconnect'),
                  ),
                  if (state.isReconnecting)
                    OutlinedButton(
                      onPressed: cubit.cancelReconnect,
                      child: const Text('Cancel reconnect'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Discovered devices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (state.devices.isEmpty)
                const Text('No devices yet. Start a scan to discover sensors.')
              else
                ...state.devices.map(
                  (device) => Card(
                    child: ListTile(
                      title: Text(device.name),
                      subtitle: Text(
                        '${device.id} · RSSI ${device.signalStrength.rssiDbm} dBm',
                      ),
                      trailing: FilledButton(
                        onPressed: state.busy
                            ? null
                            : () => cubit.connect(device),
                        child: const Text('Connect'),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'GATT services',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (state.services.isEmpty)
                const Text('Connect to a sensor to discover services.')
              else
                ...state.services.map(
                  (service) => Card(
                    child: ExpansionTile(
                      title: Text(service.uuid),
                      children: service.characteristics
                          .map(
                            (characteristic) => ListTile(
                              dense: true,
                              title: Text(characteristic.uuid),
                              subtitle: Text(
                                'write=${characteristic.properties.canWrite} '
                                'notify=${characteristic.properties.canNotify}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text('Telemetry', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (state.telemetry.isEmpty)
                const Text('No telemetry samples yet.')
              else
                ...state.telemetry.map(
                  (sample) => Text(
                    '${sample.receivedAt.toIso8601String()} · '
                    '${sample.payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Paired devices',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: state.pairedDevices.isEmpty
                        ? null
                        : cubit.clearPairedDevices,
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.pairedDevices.isEmpty)
                const Text('No paired devices stored locally.')
              else
                ...state.pairedDevices.map(
                  (device) => Card(
                    child: ListTile(
                      title: Text(device.name),
                      subtitle: Text(
                        '${device.id}\nLast connected: '
                        '${device.lastConnectedAt?.toIso8601String() ?? 'never'}',
                      ),
                      isThreeLine: true,
                      trailing: FilledButton.tonal(
                        onPressed: state.busy
                            ? null
                            : () => cubit.reconnect(device.id),
                        child: Text(
                          state.isReconnecting ? 'Reconnecting…' : 'Reconnect',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
