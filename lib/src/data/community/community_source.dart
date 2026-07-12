enum CommunitySourceId {
  astroboxRepo('astrobox-repo'),
  bandbbs('bandbbs'),
  huamiAppStore('huami-appstore');

  const CommunitySourceId(this.storageKey);

  final String storageKey;

  String get displayName {
    return switch (this) {
      CommunitySourceId.astroboxRepo => 'AstroBox Repo',
      CommunitySourceId.bandbbs => '米坛社区',
      CommunitySourceId.huamiAppStore => '华米应用商店',
    };
  }
}

CommunitySourceId? communitySourceIdByName(String value) {
  for (final source in CommunitySourceId.values) {
    if (source.storageKey == value || source.name == value) {
      return source;
    }
  }
  return null;
}
