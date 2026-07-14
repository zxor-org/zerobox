import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LicenseRegistryService {
  static const _licenses = [
    (package: 'AstroBox-Public', asset: 'assets/licenses/astrobox_public.txt'),
    (
      package: 'AstroBox-NG-Module-Core',
      asset: 'assets/licenses/astrobox_ng_core.txt',
    ),
    (
      package: 'AstroBox-NG-Module-AppWasm',
      asset: 'assets/licenses/astrobox_ng_appwasm.txt',
    ),
    (
      package: 'AstroBox-NG-Module-Provider',
      asset: 'assets/licenses/astrobox_ng_provider.txt',
    ),
    (
      package: 'AstroBox-NG-Module-Account',
      asset: 'assets/licenses/astrobox_ng_account.txt',
    ),
    (
      package: 'AstroBox-NG-Module-Bluetooth',
      asset: 'assets/licenses/astrobox_ng_bluetooth.txt',
    ),
    (package: 'Gadgetbridge', asset: 'assets/licenses/gadgetbridge.txt'),
    (package: 'Kazumi', asset: 'assets/licenses/kazumi.txt'),
    (
      package: 'opus-decoder / libopus',
      asset: 'assets/licenses/opus_decoder.txt',
    ),
    (
      package: 'quickjs-emscripten / QuickJS',
      asset: 'assets/licenses/quickjs_emscripten.txt',
    ),
  ];

  static Future<void> registerThirdPartyLicenses() async {
    for (final entry in _licenses) {
      try {
        final text = await rootBundle.loadString(entry.asset);
        LicenseRegistry.addLicense(() async* {
          yield LicenseEntryWithLineBreaks([entry.package], text);
        });
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Failed to load license ${entry.asset}: $e');
        }
      }
    }
  }
}
