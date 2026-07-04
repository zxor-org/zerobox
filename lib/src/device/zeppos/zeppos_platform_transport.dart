import 'package:zerobox/src/core/services/ble_gatt_driver.dart';
import 'package:zerobox/src/core/services/rfcomm_driver.dart';
import 'package:zerobox/src/device/core/ble_transport.dart';
import 'package:zerobox/src/device/core/spp_transport.dart';

class ZeppOsPlatformTransport {
  const ZeppOsPlatformTransport._();

  static const firmwareServiceUuid = '00001530-0000-3512-2118-0009af100700';
  static const chunked2021WriteCharUuid =
      '00000016-0000-3512-2118-0009af100700';
  static const chunked2021ReadCharUuid = '00000017-0000-3512-2118-0009af100700';
  static const btSerialServiceUuid = '00000022-0000-3512-2118-0009af100700';

  static const defaultBtbrFallbackChannels = <int>[5, 1];

  static const requiredBleCharacteristics = <BleRequiredCharacteristic>[
    BleRequiredCharacteristic(
      serviceUuid: firmwareServiceUuid,
      characteristicUuid: chunked2021ReadCharUuid,
      label: 'zeppos chunked 2021 read',
    ),
    BleRequiredCharacteristic(
      serviceUuid: firmwareServiceUuid,
      characteristicUuid: chunked2021WriteCharUuid,
      label: 'zeppos chunked 2021 write',
    ),
  ];

  static Future<BleTransport> connectBle({
    required BleGattDriver ble,
    required String deviceId,
    required String deviceName,
    int desiredMtu = 247,
  }) async {
    final connection = await ble.connect(
      deviceId,
      deviceName,
      requiredCharacteristics: requiredBleCharacteristics,
      desiredMtu: desiredMtu,
    );
    final transport = BleTransport.zepp(connection);
    await transport.start();
    return transport;
  }

  static Future<SppTransport> connectBtbr({
    required RfcommDriver rfcomm,
    required String deviceId,
    required String deviceName,
    List<int> fallbackChannels = defaultBtbrFallbackChannels,
  }) async {
    final connection = await rfcomm.connect(
      deviceId,
      deviceName,
      serviceUuid: btSerialServiceUuid,
      fallbackChannels: fallbackChannels,
    );
    final transport = SppTransport.zeppBtbr(connection);
    await transport.start();
    return transport;
  }
}
