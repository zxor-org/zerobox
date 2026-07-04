# ZeroBox

A pretty fast wearable management tool for VelaOS and ZeppOS, built with Flutter

[简体中文](README.md) · English

> ⚠️ This project is under active development and is not yet fully usable

## What is ZeroBox?

ZeroBox is a cross-platform wearable device management tool that lets you connect, manage and install resources on VelaOS / Xiaomi and ZeppOS devices without the official client

## Supported platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ Supported | Tested on CrDroid 12.11 (Android 16) |
| Linux | ✅ Supported | Tested on Arch Linux x86_64 |
| Web | ✅ Supported | Requires a browser with Web Serial / Bluetooth support |
| macOS | ❔ Not tested | Not tested yet |
| Windows | ❔ Not tested | Not tested yet |
| iOS | ❌ Not supported | No plans yet |

## Features

| Feature | Status |
|---------|--------|
| VelaOS / Xiaomi device connection | ✅ Done |
| Install watch faces, mini apps and firmware packages | ✅ Done |
| Xiaomi account login with 2FA | ✅ Done |
| AstroBox-Repo community source integration | ✅ Done |
| Optimize resource installation flow | 🚧 WIP |
| Optimize device connection experience | 🚧 WIP |
| Integrate BandBBS OAuth login for BandBBS community resources | 🚧 WIP |
| Creator center, one-click publish resources to BandBBS / AstroBox-Repo | 🚧 WIP |
| Home page improvements | 🚧 WIP |

## Build from source

~~You need [Flutter](https://docs.flutter.dev/get-started/install) installed~~

## Acknowledgements

ZeroBox benefits from the following excellent projects:

| Project | What we referenced |
|---------|--------------------|
| [AstroBox-Public](https://github.com/AstralSightStudios/AstroBox-Public) | UI structure, resource flow and interaction design |
| [AstroBox-NG-Module-Core](https://github.com/AstralSightStudios/AstroBox-NG-Module-Core) | Xiaomi device protocol, installation flow and transfer behavior |
| [AstroBox-NG-Module-Bluetooth](https://github.com/AstralSightStudios/AstroBox-NG-Module-Bluetooth) | Bluetooth connection behavior |
| [AstroBox-NG-Module-Account](https://github.com/AstralSightStudios/AstroBox-NG-Module-Account) | Xiaomi account login, device sync and authkey retrieval |
| [AstroBox-NG-Module-Provider](https://github.com/AstralSightStudios/AstroBox-NG-Module-Provider) | Community resource index, CDN and manifest parsing |
| [AstroBox-NG-Module-AppWasm](https://github.com/AstralSightStudios/AstroBox-NG-Module-AppWasm) | Web Serial and browser-side connection flow |
| [Gadgetbridge](https://codeberg.org/Freeyourgadget/Gadgetbridge) | ZeppOS and wearable device protocol research |
| [Kazumi](https://github.com/Predidit/Kazumi) | Material Design components and UI design |

## License

ZeroBox is licensed under the [GNU Affero General Public License v3.0](LICENSE)
