part of upnp.dial;

class DialScreen {
  static Stream<DialScreen> find({bool silent = true}) async* {
    var discovery = DeviceDiscoverer();
    var ids = <String>{};

    await for (DiscoveredClient client in discovery.quickDiscoverClients(
        timeout: const Duration(seconds: 5), query: CommonDevices.DIAL)) {
      if (ids.contains(client.usn)) {
        continue;
      }
      ids.add(client.usn);

      try {
        var dev = await client.getDevice();
        if (dev != null /* && dev.friendlyName != null */) {
          yield DialScreen(
              Uri.parse(Uri.parse(client.location).origin), dev.friendlyName);
        }
      } catch (e) {
        if (!silent) {
          rethrow;
        }
      }
    }
  }

  final Uri baseUri;
  final String name;

  DialScreen(this.baseUri, this.name);

  factory DialScreen.forCastDevice(String ip, String deviceName) {
    return DialScreen(Uri.parse('http://$ip:8008/'), deviceName);
  }

  Future<bool> isIdle() async {
    HttpClientResponse? response;

    try {
      response = await send('GET', '/apps');
      if (response.statusCode == 302) {
        return false;
      }
      return true;
    } finally {
      if (response != null) {
        await response.drain();
      }
    }
  }

  Future launch(String app, {payload}) async {
    if (payload is Map) {
      var out = '';
      for (var key in payload.keys as List<String>) {
        if (out.isNotEmpty) {
          out += '&';
        }

        out +=
            '${Uri.encodeComponent(key)}=${Uri.encodeComponent(payload[key].toString())}';
      }
      payload = out;
    }

    HttpClientResponse response;

    response = await send('POST', '/apps/$app', body: payload);
    if (response.statusCode == 201) {
      return true;
    }
    return false;
  }

  Future<bool> hasApp(String app) async {
    HttpClientResponse response;

    response = await send('GET', '/apps/$app');
    if (response.statusCode == 404) {
      return false;
    }
    return true;
  }

  Future<String?> getCurrentApp() async {
    HttpClientResponse response;

    response = await send('GET', '/apps');
    if (response.statusCode == 302) {
      var loc = response.headers.value('location');
      if (loc != null) {
        var uri = Uri.parse(loc);
        return uri.pathSegments[1];
      }
    }
    return null;
  }

  Future<bool> close([String? app]) async {
    var toClose = app ?? await getCurrentApp();
    if (toClose != null) {
      HttpClientResponse response;

      response = await send('DELETE', '/apps/$toClose');
      if (response.statusCode != 200) {
        return false;
      }
      return true;
    }
    return false;
  }

  Future<HttpClientResponse> send(String method, String path,
      {body, Map<String, dynamic>? headers}) async {
    var request =
        await UpnpCommon.httpClient.openUrl(method, baseUri.resolve(path));

    if (body is String) {
      request.write(body);
    } else if (body is List<int>) {
      request.add(body);
    }
    for (var key in headers!.keys) {
      if (headers[key] != null) {
        request.headers.set(key, headers[key].toString());
      }
    }

    return await request.close();
  }
}
