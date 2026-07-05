enum XiaomiWearableFamily { band, bandPro, redmiWatch, xiaomiWatch, unknown }

enum XiaomiWearableChip { bes, xring, unknown }

class XiaomiWearableIdentity {
  const XiaomiWearableIdentity({
    required this.codename,
    required this.displayName,
    required this.abV2Id,
    required this.family,
    required this.chip,
    this.seriesName,
    this.fetch = false,
    this.aliases = const [],
  });

  final String codename;
  final String displayName;
  final String abV2Id;
  final XiaomiWearableFamily family;
  final XiaomiWearableChip chip;
  final String? seriesName;
  final bool fetch;
  final List<String> aliases;
}

const xiaomiWearableIdentities = <String, XiaomiWearableIdentity>{
  'm66': XiaomiWearableIdentity(
    codename: 'm66',
    displayName: 'Xiaomi Smart Band 8',
    abV2Id: 'm66',
    family: XiaomiWearableFamily.band,
    chip: XiaomiWearableChip.bes,
    seriesName: 'Xiaomi Smart Band 8 系列',
    aliases: [
      '小米手环8',
      '小米手环8 NFC',
      'Xiaomi Smart Band 8',
      'Xiaomi Smart Band 8 NFC',
      'miwear.watch.m66',
      'miwear.watch.m66nfc',
      'miwear.watch.m66tc',
      'miwear.watch.m66dsn',
      'miwear.watch.m66gl',
      'miwear.watch.m66gln',
    ],
  ),
  'm67': XiaomiWearableIdentity(
    codename: 'm67',
    displayName: 'Xiaomi Smart Band 8 Pro',
    abV2Id: 'm67',
    family: XiaomiWearableFamily.bandPro,
    chip: XiaomiWearableChip.bes,
    seriesName: 'Xiaomi Smart Band 8 Pro 系列',
    aliases: [
      '小米手环8 Pro',
      'Xiaomi Smart Band 8 Pro',
      'lchz.watch.m67',
      'lchz.watch.m67ys',
      'lchz.watch.m67gl',
    ],
  ),
  'n66': XiaomiWearableIdentity(
    codename: 'n66',
    displayName: 'Xiaomi Smart Band 9',
    abV2Id: 'xmb9',
    family: XiaomiWearableFamily.band,
    chip: XiaomiWearableChip.bes,
    seriesName: 'Xiaomi Smart Band 9 系列',
    aliases: [
      '小米手环9',
      '小米手环9 NFC',
      'Xiaomi Smart Band 9',
      'Xiaomi Smart Band 9 NFC',
      'miwear.watch.n66',
      'miwear.watch.n66cn',
      'miwear.watch.n66nfc',
      'miwear.watch.n66tc',
      'miwear.watch.n66gl',
      'miwear.watch.n66gln',
      'M2345B1',
      'M2346B1',
    ],
  ),
  'n67': XiaomiWearableIdentity(
    codename: 'n67',
    displayName: 'Xiaomi Smart Band 9 Pro',
    abV2Id: 'xmb9p',
    family: XiaomiWearableFamily.bandPro,
    chip: XiaomiWearableChip.bes,
    seriesName: 'Xiaomi Smart Band 9 Pro 系列',
    fetch: true,
    aliases: [
      '小米手环9 Pro',
      'Xiaomi Smart Band 9 Pro',
      'miwear.watch.n67',
      'miwear.watch.n67cn',
      'miwear.watch.n67gl',
      'M2401B1',
      'M2402B1',
    ],
  ),
  'n69': XiaomiWearableIdentity(
    codename: 'n69',
    displayName: 'Xiaomi Smart Band 9 Active',
    abV2Id: 'n69',
    family: XiaomiWearableFamily.band,
    chip: XiaomiWearableChip.bes,
    seriesName: 'Xiaomi Smart Band 9 Active 系列',
    aliases: [
      '小米手环9 Active',
      '小米手环9 活力版',
      'Redmi Band 3',
      'Redmi手环3',
      'Xiaomi Smart Band 9 Active',
      'miwear.watch.n69',
      'miwear.watch.n69cn',
      'miwear.watch.n69gl',
    ],
  ),
  'o66': XiaomiWearableIdentity(
    codename: 'o66',
    displayName: 'Xiaomi Smart Band 10',
    abV2Id: 'xmb10',
    family: XiaomiWearableFamily.band,
    chip: XiaomiWearableChip.bes,
    seriesName: 'Xiaomi Smart Band 10 系列',
    aliases: [
      '小米手环10',
      'Xiaomi Smart Band 10',
      'miwear.watch.o66',
      'miwear.watch.o66cn',
      'miwear.watch.o66gl',
      'M2457B1',
    ],
  ),
  'o66nfc': XiaomiWearableIdentity(
    codename: 'o66nfc',
    displayName: 'Xiaomi Smart Band 10 NFC',
    abV2Id: 'xmb10nfc',
    family: XiaomiWearableFamily.band,
    chip: XiaomiWearableChip.bes,
    seriesName: 'Xiaomi Smart Band 10 NFC 系列',
    aliases: [
      '小米手环10 NFC',
      'Xiaomi Smart Band 10 NFC',
      'miwear.watch.o66nfc',
      'miwear.watch.o66gln',
      'M2456B1',
    ],
  ),
  'p67': XiaomiWearableIdentity(
    codename: 'p67',
    displayName: 'Xiaomi Smart Band 10 Pro',
    abV2Id: 'xmb10p',
    family: XiaomiWearableFamily.bandPro,
    chip: XiaomiWearableChip.bes,
    seriesName: 'Xiaomi Smart Band 10 Pro 系列',
    aliases: [
      '小米手环10 Pro',
      'Xiaomi Smart Band 10 Pro',
      'miwear.watch.p67',
      'miwear.watch.p67cn',
      'miwear.watch.p67tc',
      'M2553B1',
    ],
  ),
  'n62': XiaomiWearableIdentity(
    codename: 'n62',
    displayName: 'Xiaomi Watch S3',
    abV2Id: 'xmws3',
    family: XiaomiWearableFamily.xiaomiWatch,
    chip: XiaomiWearableChip.bes,
    seriesName: 'Xiaomi Watch S3 系列',
    fetch: true,
    aliases: [
      '小米手表S3',
      'Xiaomi Watch S3',
      'mijia.watch.n62',
      'mijia.watch.n62lte',
      'mijia.watch.n62w',
      'M2313W1',
      'M2311W1',
      'M2323W1',
    ],
  ),
  'o62': XiaomiWearableIdentity(
    codename: 'o62',
    displayName: 'Xiaomi Watch S4',
    abV2Id: 'xmws4',
    family: XiaomiWearableFamily.xiaomiWatch,
    chip: XiaomiWearableChip.bes,
    seriesName: 'Xiaomi Watch S4 系列',
    fetch: true,
    aliases: [
      '小米手表S4',
      'Xiaomi Watch S4',
      'mijia.watch.o62',
      'mijia.watch.o62lte',
      'mijia.watch.o62gl',
      'mijia.watch.n62s',
      'M2425W1',
      'M2424W1',
      'M2312W1',
    ],
  ),
  'o62m': XiaomiWearableIdentity(
    codename: 'o62m',
    displayName: 'Xiaomi Watch S4 15周年纪念版',
    abV2Id: 'xmws4xring',
    family: XiaomiWearableFamily.xiaomiWatch,
    chip: XiaomiWearableChip.xring,
    seriesName: 'Xiaomi Watch S4 15周年纪念版 系列',
    fetch: true,
    aliases: [
      '小米手表S4 15周年纪念版',
      'Xiaomi Watch S4 15th Anniversary',
      'mijia.watch.o62m',
      'M2426W1',
    ],
  ),
  'o63': XiaomiWearableIdentity(
    codename: 'o63',
    displayName: 'Xiaomi Watch S4 41mm',
    abV2Id: 'xmws441',
    family: XiaomiWearableFamily.xiaomiWatch,
    chip: XiaomiWearableChip.bes,
    seriesName: 'Xiaomi Watch S4 41mm 系列',
    fetch: true,
    aliases: [
      '小米手表S4 41mm',
      'Xiaomi Watch S4 41mm',
      'miwear.watch.o63',
      'miwear.watch.o63w',
      'M2502W1',
    ],
  ),
  'p62': XiaomiWearableIdentity(
    codename: 'p62',
    displayName: 'Xiaomi Watch S5',
    abV2Id: 'xmws5',
    family: XiaomiWearableFamily.xiaomiWatch,
    chip: XiaomiWearableChip.bes,
    seriesName: 'Xiaomi Watch S5 系列',
    fetch: true,
    aliases: [
      '小米手表S5',
      'Xiaomi Watch S5',
      'Xiaomi Watch S5 46mm',
      'miwear.watch.p62',
      'miwear.watch.p62lte',
      'miwear.watch.p62g',
      'M2530W1',
      'M2517W1',
    ],
  ),
  'o65': XiaomiWearableIdentity(
    codename: 'o65',
    displayName: 'REDMI Watch 5',
    abV2Id: 'xmrw5',
    family: XiaomiWearableFamily.redmiWatch,
    chip: XiaomiWearableChip.bes,
    seriesName: 'REDMI Watch 5 系列',
    fetch: true,
    aliases: [
      'Redmi Watch 5',
      'REDMI Watch 5',
      'miwear.watch.o65',
      'miwear.watch.o65w',
      'M2427W1',
    ],
  ),
  'o65m': XiaomiWearableIdentity(
    codename: 'o65m',
    displayName: 'REDMI Watch 5 eSIM',
    abV2Id: 'xmrw5xring',
    family: XiaomiWearableFamily.redmiWatch,
    chip: XiaomiWearableChip.xring,
    seriesName: 'REDMI Watch 5 eSIM 系列',
    fetch: true,
    aliases: [
      'Redmi Watch 5 eSIM',
      'REDMI Watch 5 eSIM',
      'miwear.watch.o65m',
      'M2428W1',
    ],
  ),
  'p65': XiaomiWearableIdentity(
    codename: 'p65',
    displayName: 'REDMI Watch 6',
    abV2Id: 'xmrw6',
    family: XiaomiWearableFamily.redmiWatch,
    chip: XiaomiWearableChip.bes,
    seriesName: 'REDMI Watch 6 系列',
    fetch: true,
    aliases: [
      'Redmi Watch 6',
      'REDMI Watch 6',
      'miwear.watch.p65',
      'miwear.watch.p65gl',
      'miwear.watch.p65gln',
      'M2523W1',
    ],
  ),
};

final Map<String, XiaomiWearableIdentity> _xiaomiWearableAliasIndex = {
  for (final identity in xiaomiWearableIdentities.values) ...{
    _normalizeIdentityToken(identity.codename): identity,
    _normalizeIdentityToken(identity.abV2Id): identity,
    _normalizeIdentityToken(identity.displayName): identity,
    for (final alias in identity.aliases)
      _normalizeIdentityToken(alias): identity,
  },
};

XiaomiWearableIdentity? normalizeXiaomiWearableIdentity(String? input) {
  final normalized = _normalizeIdentityToken(input);
  if (normalized.isEmpty) return null;
  return _xiaomiWearableAliasIndex[normalized];
}

XiaomiWearableIdentity? xiaomiWearableIdentityForCodename(String? value) =>
    normalizeXiaomiWearableIdentity(value);

String normalizeXiaomiWearableCodename(String? input) {
  return xiaomiWearableIdentityForCodename(input)?.codename ?? '';
}

String xiaomiDisplayNameForIdentity({required String name, String? codename}) {
  final identity =
      xiaomiWearableIdentityForCodename(codename) ??
      normalizeXiaomiWearableIdentity(name);
  if (identity != null) return identity.displayName;
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'Unknown device' : trimmed;
}

String xiaomiSeriesNameForIdentity(String value) {
  final identity = xiaomiWearableIdentityForCodename(value);
  if (identity == null) return value;
  return identity.seriesName ?? '${identity.displayName} 系列';
}

String _normalizeIdentityToken(String? value) {
  final lower = value?.trim().toLowerCase() ?? '';
  if (lower.isEmpty) return '';
  return lower
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll('-', '')
      .replaceAll('_', '')
      .replaceAll('红米', 'redmi')
      .replaceAll('小米', 'xiaomi')
      .replaceAll('手环', 'smartband')
      .replaceAll('手表', 'watch')
      .replaceAll('系列', '')
      .replaceAll('纪念版', 'anniversary');
}
