part of 'simulator_cubit.dart';

final class SimulatorState extends Equatable {
  const SimulatorState({
    this.devices = const <BleDevice>[],
    this.pairedDevices = const <PairedDevice>[],
    this.services = const <GattService>[],
    this.telemetry = const <TelemetrySample>[],
    this.connectionState = BleConnectionState.disconnected,
    this.isScanning = false,
    this.busy = false,
    this.isReconnecting = false,
    this.selectedDeviceId,
    this.lastError,
  });

  final List<BleDevice> devices;
  final List<PairedDevice> pairedDevices;
  final List<GattService> services;
  final List<TelemetrySample> telemetry;
  final BleConnectionState connectionState;
  final bool isScanning;
  final bool busy;
  final bool isReconnecting;
  final String? selectedDeviceId;
  final String? lastError;

  SimulatorState copyWith({
    List<BleDevice>? devices,
    List<PairedDevice>? pairedDevices,
    List<GattService>? services,
    List<TelemetrySample>? telemetry,
    BleConnectionState? connectionState,
    bool? isScanning,
    bool? busy,
    bool? isReconnecting,
    String? selectedDeviceId,
    String? lastError,
    bool clearError = false,
    bool clearSelectedDevice = false,
  }) {
    return SimulatorState(
      devices: devices ?? this.devices,
      pairedDevices: pairedDevices ?? this.pairedDevices,
      services: services ?? this.services,
      telemetry: telemetry ?? this.telemetry,
      connectionState: connectionState ?? this.connectionState,
      isScanning: isScanning ?? this.isScanning,
      busy: busy ?? this.busy,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      selectedDeviceId: clearSelectedDevice
          ? null
          : (selectedDeviceId ?? this.selectedDeviceId),
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => [
    devices,
    pairedDevices,
    services,
    telemetry,
    connectionState,
    isScanning,
    busy,
    isReconnecting,
    selectedDeviceId,
    lastError,
  ];
}
