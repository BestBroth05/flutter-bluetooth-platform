part of 'simulator_cubit.dart';

final class SimulatorState extends Equatable {
  const SimulatorState({
    this.transportMode = BleTransportMode.simulator,
    this.realBleSupported = false,
    this.devices = const <BleDevice>[],
    this.pairedDevices = const <PairedDevice>[],
    this.services = const <GattService>[],
    this.framedTelemetry = const <TelemetrySample>[],
    this.rawNotifications = const <BleNotificationEvent>[],
    this.commandHistory = const <String>[],
    this.connectionState = BleConnectionState.disconnected,
    this.adapterState = BleAdapterState.unknown,
    this.permissionStatus = BlePermissionStatus.unavailable,
    this.isScanning = false,
    this.busy = false,
    this.isReconnecting = false,
    this.demoFramingEnabled = true,
    this.subscribed = false,
    this.selectedDeviceId,
    this.selectedDeviceName,
    this.selectedCharacteristic,
    this.selectedCharacteristicProperties,
    this.commandInput = '01 02 03',
    this.lastReadHex,
    this.lastReadText,
    this.currentRssi,
    this.nameFilter = '',
    this.minRssiFilter,
    this.lastActivityAt,
    this.lastError,
  });

  final BleTransportMode transportMode;
  final bool realBleSupported;
  final List<BleDevice> devices;
  final List<PairedDevice> pairedDevices;
  final List<GattService> services;
  final List<TelemetrySample> framedTelemetry;
  final List<BleNotificationEvent> rawNotifications;
  final List<String> commandHistory;
  final BleConnectionState connectionState;
  final BleAdapterState adapterState;
  final BlePermissionStatus permissionStatus;
  final bool isScanning;
  final bool busy;
  final bool isReconnecting;
  final bool demoFramingEnabled;
  final bool subscribed;
  final String? selectedDeviceId;
  final String? selectedDeviceName;
  final CharacteristicRef? selectedCharacteristic;
  final GattCharacteristicProperties? selectedCharacteristicProperties;
  final String commandInput;
  final String? lastReadHex;
  final String? lastReadText;
  final int? currentRssi;
  final String nameFilter;
  final int? minRssiFilter;
  final DateTime? lastActivityAt;
  final String? lastError;

  bool get isPairedSelected {
    final id = selectedDeviceId;
    if (id == null) {
      return false;
    }
    return pairedDevices.any((device) => device.id == id);
  }

  SimulatorState copyWith({
    BleTransportMode? transportMode,
    bool? realBleSupported,
    List<BleDevice>? devices,
    List<PairedDevice>? pairedDevices,
    List<GattService>? services,
    List<TelemetrySample>? framedTelemetry,
    List<BleNotificationEvent>? rawNotifications,
    List<String>? commandHistory,
    BleConnectionState? connectionState,
    BleAdapterState? adapterState,
    BlePermissionStatus? permissionStatus,
    bool? isScanning,
    bool? busy,
    bool? isReconnecting,
    bool? demoFramingEnabled,
    bool? subscribed,
    String? selectedDeviceId,
    String? selectedDeviceName,
    CharacteristicRef? selectedCharacteristic,
    GattCharacteristicProperties? selectedCharacteristicProperties,
    String? commandInput,
    String? lastReadHex,
    String? lastReadText,
    int? currentRssi,
    String? nameFilter,
    int? minRssiFilter,
    DateTime? lastActivityAt,
    String? lastError,
    bool clearError = false,
    bool clearSelectedDevice = false,
    bool clearSelectedCharacteristic = false,
    bool clearMinRssi = false,
  }) {
    return SimulatorState(
      transportMode: transportMode ?? this.transportMode,
      realBleSupported: realBleSupported ?? this.realBleSupported,
      devices: devices ?? this.devices,
      pairedDevices: pairedDevices ?? this.pairedDevices,
      services: services ?? this.services,
      framedTelemetry: framedTelemetry ?? this.framedTelemetry,
      rawNotifications: rawNotifications ?? this.rawNotifications,
      commandHistory: commandHistory ?? this.commandHistory,
      connectionState: connectionState ?? this.connectionState,
      adapterState: adapterState ?? this.adapterState,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isScanning: isScanning ?? this.isScanning,
      busy: busy ?? this.busy,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      demoFramingEnabled: demoFramingEnabled ?? this.demoFramingEnabled,
      subscribed: subscribed ?? this.subscribed,
      selectedDeviceId: clearSelectedDevice
          ? null
          : (selectedDeviceId ?? this.selectedDeviceId),
      selectedDeviceName: clearSelectedDevice
          ? null
          : (selectedDeviceName ?? this.selectedDeviceName),
      selectedCharacteristic: clearSelectedCharacteristic
          ? null
          : (selectedCharacteristic ?? this.selectedCharacteristic),
      selectedCharacteristicProperties: clearSelectedCharacteristic
          ? null
          : (selectedCharacteristicProperties ??
                this.selectedCharacteristicProperties),
      commandInput: commandInput ?? this.commandInput,
      lastReadHex: lastReadHex ?? this.lastReadHex,
      lastReadText: lastReadText ?? this.lastReadText,
      currentRssi: currentRssi ?? this.currentRssi,
      nameFilter: nameFilter ?? this.nameFilter,
      minRssiFilter: clearMinRssi
          ? null
          : (minRssiFilter ?? this.minRssiFilter),
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => [
    transportMode,
    realBleSupported,
    devices,
    pairedDevices,
    services,
    framedTelemetry,
    rawNotifications,
    commandHistory,
    connectionState,
    adapterState,
    permissionStatus,
    isScanning,
    busy,
    isReconnecting,
    demoFramingEnabled,
    subscribed,
    selectedDeviceId,
    selectedDeviceName,
    selectedCharacteristic,
    selectedCharacteristicProperties,
    commandInput,
    lastReadHex,
    lastReadText,
    currentRssi,
    nameFilter,
    minRssiFilter,
    lastActivityAt,
    lastError,
  ];
}
