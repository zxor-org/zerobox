import 'package:dio/dio.dart';
import 'package:zerobox/src/data/astrobox/astrobox_cdn.dart';

class GithubCdnInterceptor extends Interceptor {
  GithubCdnInterceptor({required this.cdn});

  final AstroBoxCdn Function() cdn;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final rewritten = _rewriteGithubUri(options.uri, cdn());
    if (rewritten != options.uri) {
      options.path = rewritten.toString();
      options.queryParameters.clear();
    }
    handler.next(options);
  }
}

Uri _rewriteGithubUri(Uri uri, AstroBoxCdn cdn) {
  if (cdn == AstroBoxCdn.raw) return uri;
  if (!_isConvertibleGithubUri(uri)) {
    return uri;
  }

  final origin = uri.toString();
  return switch (cdn) {
    AstroBoxCdn.raw => uri,
    AstroBoxCdn.ghfast => Uri.parse('https://ghfast.top/$origin'),
    AstroBoxCdn.ghproxy => Uri.parse('https://gh-proxy.com/$origin'),
  };
}

bool _isConvertibleGithubUri(Uri uri) {
  if (uri.scheme != 'https') return false;
  if (uri.host == 'raw.githubusercontent.com' ||
      uri.host == 'gist.githubusercontent.com') {
    return true;
  }
  if (uri.host != 'github.com') return false;

  final path = uri.path;
  return path.contains('/releases/download/') ||
      path.contains('/releases/latest/download/') ||
      path.contains('/archive/');
}
