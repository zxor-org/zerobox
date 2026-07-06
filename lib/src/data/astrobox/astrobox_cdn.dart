enum AstroBoxCdn { raw, ghfast, ghproxy }

extension AstroBoxCdnExtension on AstroBoxCdn {
  String get displayName {
    return switch (this) {
      AstroBoxCdn.raw => 'Raw',
      AstroBoxCdn.ghfast => 'GHFast',
      AstroBoxCdn.ghproxy => 'GHProxy',
    };
  }
}

AstroBoxCdn? astroBoxCdnByName(String name) {
  try {
    return AstroBoxCdn.values.byName(name);
  } on ArgumentError {
    return null;
  }
}
