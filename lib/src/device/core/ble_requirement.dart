class BleRequiredCharacteristic {
  const BleRequiredCharacteristic({
    required this.serviceUuid,
    required this.characteristicUuid,
    this.label,
  });

  final String serviceUuid;
  final String characteristicUuid;
  final String? label;
}

const xiaomiBleServiceUuid = '0000fe95-0000-1000-8000-00805f9b34fb';
const xiaomiBleRecvCharUuid = '0000005e-0000-1000-8000-00805f9b34fb';
const xiaomiBleSentCharUuid = '0000005f-0000-1000-8000-00805f9b34fb';

const xiaomiRequiredBleCharacteristics = <BleRequiredCharacteristic>[
  BleRequiredCharacteristic(
    serviceUuid: xiaomiBleServiceUuid,
    characteristicUuid: xiaomiBleRecvCharUuid,
    label: 'xiaomi recv',
  ),
  BleRequiredCharacteristic(
    serviceUuid: xiaomiBleServiceUuid,
    characteristicUuid: xiaomiBleSentCharUuid,
    label: 'xiaomi sent',
  ),
];
