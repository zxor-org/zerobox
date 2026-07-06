enum CommunitySourceId {
  astroboxRepo('astrobox-repo');

  const CommunitySourceId(this.storageKey);

  final String storageKey;

  String get displayName {
    return switch (this) {
      CommunitySourceId.astroboxRepo => 'AstroBox Repo',
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
