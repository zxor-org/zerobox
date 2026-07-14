class CommunitySourceId {
  const CommunitySourceId._(
    this.name,
    this.storageKey,
    this.displayName, {
    this.pluginProviderName,
  });

  static const astroboxRepo = CommunitySourceId._(
    'astroboxRepo',
    'astrobox-repo',
    'AstroBox Repo',
  );
  static const bandbbs = CommunitySourceId._('bandbbs', 'bandbbs', '米坛社区');
  static const huamiAppStore = CommunitySourceId._(
    'huamiAppStore',
    'huami-appstore',
    '华米应用商店',
  );

  static const values = [astroboxRepo, bandbbs, huamiAppStore];

  factory CommunitySourceId.plugin(String providerName) {
    final name = providerName.trim();
    if (name.isEmpty) {
      throw const FormatException('Plugin provider name is required');
    }
    return CommunitySourceId._(
      'plugin',
      'plugin@${Uri.encodeComponent(name)}',
      name,
      pluginProviderName: name,
    );
  }

  final String name;
  final String storageKey;
  final String displayName;
  final String? pluginProviderName;

  bool get isPlugin => pluginProviderName != null;

  @override
  bool operator ==(Object other) =>
      other is CommunitySourceId && other.storageKey == storageKey;

  @override
  int get hashCode => storageKey.hashCode;

  @override
  String toString() => storageKey;
}

CommunitySourceId? communitySourceIdByName(String value) {
  for (final source in CommunitySourceId.values) {
    if (source.storageKey == value || source.name == value) return source;
  }
  if (!value.startsWith('plugin@')) return null;
  final encodedName = value.substring('plugin@'.length);
  if (encodedName.isEmpty) return null;
  try {
    return CommunitySourceId.plugin(Uri.decodeComponent(encodedName));
  } on FormatException {
    return null;
  }
}
