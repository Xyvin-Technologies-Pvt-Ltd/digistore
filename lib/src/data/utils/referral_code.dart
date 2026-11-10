import 'dart:convert';
import 'dart:typed_data';

/// Referral codes are a leading `S` plus five digits (`S00001`–`S99999`).
class ReferralCode {
  static final RegExp exact = RegExp(r'^S\d{5}$');
  static final RegExp _embedded = RegExp(r'(?<![A-Z0-9])S\d{5}(?!\d)');

  static String? normalize(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toUpperCase();
    if (!exact.hasMatch(value)) return null;
    return value;
  }

  /// Pulls a code out of free text such as a clipboard string or share message.
  static String? extract(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return _embedded.firstMatch(raw.toUpperCase())?.group(0);
  }

  /// Reads `utm_campaign` from a Play Install Referrer payload.
  ///
  /// Accepts both raw and percent-encoded query strings.
  static String? fromInstallReferrer(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var value = raw.trim();
    for (var i = 0; i < 2; i++) {
      final decoded = _decode(value);
      if (decoded == value) break;
      value = decoded;
    }
    final query = value.startsWith('?') ? value.substring(1) : value;
    final params = _splitQuery(query);
    final fromCampaign = normalize(params['utm_campaign']);
    if (fromCampaign != null) return fromCampaign;
    return extract(value);
  }

  /// Landing page for invite links, derived from the app's API [baseUrl].
  ///
  /// `https://uat-api.../api/mobile` → `https://uat-api.../app`
  /// `https://api-deals.../api/mobile` → `https://api-deals.../app`
  static String landingBaseFromApi(String apiBaseUrl) {
    final uri = Uri.tryParse(apiBaseUrl.trim());
    if (uri == null || uri.host.isEmpty) {
      return 'https://api-deals.setgoinnovations.com/app';
    }
    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
    return '$scheme://${uri.host}/app';
  }

  /// Reads a code from a share link, custom scheme, or store referrer URL.
  static String? fromUri(Uri uri) {
    for (final key in const ['ref', 'code', 'referralCode', 'utm_campaign']) {
      final code = normalize(uri.queryParameters[key]);
      if (code != null) return code;
    }
    final fromReferrer = fromInstallReferrer(uri.queryParameters['referrer']);
    if (fromReferrer != null) return fromReferrer;
    for (final segment in uri.pathSegments.reversed) {
      final code = normalize(segment);
      if (code != null) return code;
    }
    return extract(uri.toString());
  }

  /// True when this link should only prefill a referral code.
  ///
  /// Limited to SetGo hosts and the `setgo://referral` scheme so an unrelated
  /// site that happens to use `/app?ref=` still opens in the browser.
  static bool isAttributionLink(Uri uri) {
    if (fromUri(uri) == null) return false;
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    if (scheme == 'setgo') return host == 'referral';
    if (scheme != 'http' && scheme != 'https') return false;
    const hosts = {
      'setgo.in',
      'www.setgo.in',
      'setgoinnovations.com',
      'www.setgoinnovations.com',
      'api-deals.setgoinnovations.com',
      'uat-api.setgoinnovations.com',
    };
    if (!hosts.contains(host)) return false;
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty && segment != 'app')
        .toList();
    return segments.isEmpty;
  }

  /// Decodes a `data:image/...;base64,` QR payload. Null when it is not usable.
  static Uint8List? decodeQr(String? dataUri) {
    if (dataUri == null || dataUri.isEmpty) return null;
    final comma = dataUri.indexOf(',');
    if (!dataUri.startsWith('data:image') || comma < 0) return null;
    final payload = dataUri.substring(comma + 1).replaceAll(RegExp(r'\s'), '');
    if (payload.isEmpty) return null;
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  static String _decode(String value) {
    try {
      return Uri.decodeQueryComponent(value);
    } catch (_) {
      return value;
    }
  }

  static Map<String, String> _splitQuery(String query) {
    try {
      return Uri.splitQueryString(query);
    } catch (_) {
      return const {};
    }
  }
}
