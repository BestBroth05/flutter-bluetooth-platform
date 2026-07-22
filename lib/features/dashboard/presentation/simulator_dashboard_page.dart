import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../ble/domain/models/ble_adapter_state.dart';
import '../../../ble/domain/models/ble_connection_state.dart';
import '../../../ble/domain/models/ble_transport_mode.dart';
import '../../../ble/domain/models/ble_write_type.dart';
import '../../../ble/domain/permissions/ble_permission_status.dart';
import '../../../core/codec/byte_codecs.dart';
import 'simulator_cubit.dart';

/// Phase 2 dashboard for simulator and real BLE central workflows.
class SimulatorDashboardPage extends StatelessWidget {
  const SimulatorDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Bluetooth Platform')),
      body: BlocBuilder<SimulatorCubit, SimulatorState>(
        builder: (context, state) {
          final cubit = context.read<SimulatorCubit>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle(context, 'Transport mode'),
              SegmentedButton<BleTransportMode>(
                segments: [
                  const ButtonSegment(
                    value: BleTransportMode.simulator,
                    label: Text('Simulator'),
                  ),
                  ButtonSegment(
                    value: BleTransportMode.real,
                    label: Text(
                      state.realBleSupported
                          ? 'Real BLE'
                          : 'Real (unsupported)',
                    ),
                    enabled: state.realBleSupported,
                  ),
                ],
                selected: {state.transportMode},
                onSelectionChanged: state.busy
                    ? null
                    : (selection) => cubit.switchTransportMode(selection.first),
              ),
              const SizedBox(height: 16),
              _sectionTitle(context, 'Bluetooth readiness'),
              Text('Adapter: ${state.adapterState.name}'),
              Text('Permission: ${state.permissionStatus.name}'),
              Text('Session: ${state.connectionState.name}'),
              if (state.selectedDeviceId != null) ...[
                Text(
                  'Device: ${state.selectedDeviceName ?? state.selectedDeviceId}',
                ),
                Text('Paired: ${state.isPairedSelected}'),
                if (state.currentRssi != null)
                  Text('RSSI: ${state.currentRssi} dBm'),
                if (state.lastActivityAt != null)
                  Text(
                    'Last activity: ${state.lastActivityAt!.toIso8601String()}',
                  ),
              ],
              if (state.lastError != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.lastError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: state.busy ? null : cubit.requestPermissions,
                    child: const Text('Request permissions'),
                  ),
                  OutlinedButton(
                    onPressed: state.busy ? null : cubit.refreshPermissions,
                    child: const Text('Refresh permission status'),
                  ),
                  if (state.adapterState == BleAdapterState.off)
                    const Chip(label: Text('Bluetooth is off')),
                  if (state.permissionStatus == BlePermissionStatus.denied ||
                      state.permissionStatus ==
                          BlePermissionStatus.permanentlyDenied)
                    const Chip(label: Text('Permission missing')),
                ],
              ),
              const SizedBox(height: 16),
              _sectionTitle(context, 'Scan filters'),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Name contains',
                  border: OutlineInputBorder(),
                ),
                onChanged: cubit.updateNameFilter,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Minimum RSSI (dBm)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. -80',
                ),
                keyboardType: TextInputType.number,
                onChanged: cubit.updateMinRssiFilter,
              ),
              const SizedBox(height: 12),
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
                        ? cubit.refreshRssi
                        : null,
                    child: const Text('Read RSSI'),
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
              _sectionTitle(context, 'Discovered devices'),
              if (state.isScanning && state.devices.isEmpty)
                const Text('Scanning for nearby devices…')
              else if (state.devices.isEmpty)
                const Text(
                  'No devices found. Start a scan to discover sensors.',
                )
              else
                ...state.devices.map(
                  (device) => Card(
                    child: ListTile(
                      title: Text(device.name),
                      subtitle: Text(
                        '${device.id}\nRSSI ${device.signalStrength.rssiDbm} dBm',
                      ),
                      isThreeLine: true,
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
              _sectionTitle(context, 'GATT explorer'),
              Text('Services: ${state.services.length}'),
              if (state.services.isEmpty)
                const Text('Connect to a device to inspect GATT services.')
              else
                ...state.services.map(
                  (service) => Card(
                    child: ExpansionTile(
                      title: Text(service.uuid),
                      children: service.characteristics
                          .map(
                            (characteristic) => ListTile(
                              dense: true,
                              selected:
                                  state
                                      .selectedCharacteristic
                                      ?.characteristicUuid ==
                                  characteristic.uuid,
                              title: Text(characteristic.uuid),
                              subtitle: Text(
                                'read=${characteristic.properties.canRead} '
                                'write=${characteristic.properties.canWrite} '
                                'writeNoRsp=${characteristic.properties.canWriteWithoutResponse} '
                                'notify=${characteristic.properties.canNotify} '
                                'indicate=${characteristic.properties.canIndicate}',
                              ),
                              onTap: () => cubit.selectCharacteristic(
                                service.uuid,
                                characteristic,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              if (state.selectedCharacteristic != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Selected: ${state.selectedCharacteristic!.characteristicUuid}',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: state.busy
                          ? null
                          : cubit.readSelectedCharacteristic,
                      child: const Text('Read'),
                    ),
                    FilledButton.tonal(
                      onPressed: state.busy ? null : cubit.subscribeSelected,
                      child: const Text('Subscribe'),
                    ),
                    OutlinedButton(
                      onPressed: state.busy ? null : cubit.unsubscribeSelected,
                      child: const Text('Unsubscribe'),
                    ),
                    if (state.transportMode == BleTransportMode.simulator)
                      OutlinedButton(
                        onPressed: state.busy ? null : cubit.sendDemoCommand,
                        child: const Text('Demo write'),
                      ),
                  ],
                ),
                if (state.lastReadHex != null) ...[
                  Text('Last read (hex): ${state.lastReadHex}'),
                  if (state.lastReadText != null)
                    Text('Last read (text): ${state.lastReadText}'),
                ],
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: state.commandInput,
                  decoration: const InputDecoration(
                    labelText: 'Command payload',
                    helperText: 'Examples: hex 01 02 03 or text PING',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: cubit.updateCommandInput,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: state.busy
                          ? null
                          : () =>
                                cubit.writeSelectedCharacteristic(asHex: true),
                      child: const Text('Write hex'),
                    ),
                    FilledButton.tonal(
                      onPressed: state.busy
                          ? null
                          : () =>
                                cubit.writeSelectedCharacteristic(asHex: false),
                      child: const Text('Write text'),
                    ),
                    OutlinedButton(
                      onPressed: state.busy
                          ? null
                          : () => cubit.writeSelectedCharacteristic(
                              asHex: true,
                              writeType: BleWriteType.withoutResponse,
                            ),
                      child: const Text('Write without response'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable demo PKT framing'),
                subtitle: const Text(
                  'Off by default. Do not enable for arbitrary real devices.',
                ),
                value: state.demoFramingEnabled,
                onChanged: cubit.setDemoFramingEnabled,
              ),
              _sectionTitle(context, 'Raw notifications'),
              if (state.rawNotifications.isEmpty)
                const Text('No notification bytes yet.')
              else
                ...state.rawNotifications
                    .take(12)
                    .map(
                      (event) => Text(
                        '${event.receivedAt.toIso8601String()} · '
                        '${event.characteristic.characteristicUuid} · '
                        '${ByteCodecs.toHex(event.bytes)}'
                        '${ByteCodecs.tryDecodePrintable(event.bytes) == null ? '' : ' · "${ByteCodecs.tryDecodePrintable(event.bytes)}"'}',
                      ),
                    ),
              const SizedBox(height: 16),
              _sectionTitle(context, 'Framed telemetry (optional)'),
              if (state.framedTelemetry.isEmpty)
                const Text(
                  'No framed samples. Enable demo framing to parse PKT.',
                )
              else
                ...state.framedTelemetry.map(
                  (sample) => Text(
                    '${sample.receivedAt.toIso8601String()} · '
                    '${ByteCodecs.toHex(sample.payload)}',
                  ),
                ),
              const SizedBox(height: 16),
              _sectionTitle(context, 'Command history (session)'),
              if (state.commandHistory.isEmpty)
                const Text('No commands yet.')
              else
                ...state.commandHistory.map(Text.new),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _sectionTitle(context, 'Paired devices')),
                  TextButton(
                    onPressed: state.pairedDevices.isEmpty
                        ? null
                        : cubit.clearPairedDevices,
                    child: const Text('Clear'),
                  ),
                ],
              ),
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

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
