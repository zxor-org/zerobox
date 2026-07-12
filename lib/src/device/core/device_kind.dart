enum DeviceKind { xiaomi, zepp }

String deviceKindLabel(DeviceKind kind) {
  return switch (kind) {
    DeviceKind.xiaomi => 'Xiaomi / Mi Wear',
    DeviceKind.zepp => 'ZeppOS',
  };
}

DeviceKind? deviceKindFromString(String value) {
  return switch (value.toLowerCase()) {
    'xiaomi' || 'miwear' || 'mi wear' => DeviceKind.xiaomi,
    'zepp' || 'zeppos' => DeviceKind.zepp,
    _ => null,
  };
}
