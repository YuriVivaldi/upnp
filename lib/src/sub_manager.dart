part of upnp;

class StateSubscriptionManager {
  late HttpServer? server;
  final Map<String, StateSubscription> _subs = {};

  void init() async {
    close();

    await HttpServer.bind('0.0.0.0', 0).then((srv) {
      server = srv;
      server!.listen((HttpRequest request) {
        var id = request.uri.path.substring(1);

        if (_subs.containsKey(id)) {
          _subs[id]!.deliver(request);
        } else if (request.uri.path == '/_list') {
          request.response
            ..writeln(_subs.keys.join('\n'))
            ..close();
        } else if (request.uri.path == '/_state') {
          var out = '';
          for (var sid in _subs.keys) {
            out += '$sid: ${_subs[sid]!._lastValue}\n';
          }
          request.response
            ..write(out)
            ..close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
        }
      });
    }, onError: (e) {});
  }

  void close() async {
    for (var key in _subs.keys.toList()) {
      _subs[key]!._done();
      _subs.remove(key);
    }

    if (server != null) {
      await server!.close(force: true);
      server = null;
    }
  }

  Stream<dynamic> subscribeToVariable(StateVariable v) {
    var id = v.getGenericId();
    StateSubscription sub;
    if (_subs.containsKey(id)) {
      sub = _subs[id]!;
    } else {
      sub = _subs[id] = StateSubscription();
      sub.eventUrl = v.service.eventSubUrl;
      sub.lastStateVariable = v;
      sub.manager = this;
      sub.init();
    }

    return sub._controller.stream;
  }

  Stream<dynamic>? subscribeToService(Service service) {
    var id = sha256.convert(utf8.encode(service.eventSubUrl)).toString();
    if (_subs.containsKey(id)) {
      var sub = _subs[id]!;

      sub = _subs[id] = StateSubscription();
      sub.eventUrl = service.eventSubUrl;
      sub.manager = this;
      sub.init();

      return sub._controller.stream;
    } else {
      throw Exception('_subs[$id] not found');
    }
  }
}

class InternalNetworkUtils {
  static Future<String> getMostLikelyHost(Uri uri) async {
    var parts = uri.host.split('.');
    var interfaces = await NetworkInterface.list();

    String? calc(int skip) {
      var prefix = parts.take(parts.length - skip).join('.') + '.';

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.address.startsWith(prefix)) {
            return addr.address;
          }
        }
      }

      return null;
    }

    for (var i = 1; i <= 3; i++) {
      var ip = calc(i);
      if (ip != null) {
        return ip;
      }
    }

    return Platform.localHostname;
  }
}

class StateSubscription {
  static int REFRESH = 30;

  late StateSubscriptionManager manager;
  late StateVariable lastStateVariable;
  late String eventUrl;
  late StreamController<dynamic> _controller;
  Timer? _timer;
  late String lastCallbackUrl;

  late String _lastSid;

  dynamic _lastValue;

  void init() {
    _controller = StreamController<dynamic>.broadcast(
        onListen: () async {
          try {
            await _sub();
          } catch (e, stack) {
            _controller.addError(e, stack);
          }
        },
        onCancel: () => _unsub());
  }

  void deliver(HttpRequest request) async {
    var content =
        utf8.decode(await request.fold(<int>[], (List<int> a, List<int> b) {
      return a..addAll(b);
    }));
    await request.response.close();

    var doc = XmlDocument.parse(content);
    var props = doc.rootElement.children.whereType<XmlElement>().toList();
    var map = <String, dynamic>{};
    for (var prop in props) {
      if (prop.children.isEmpty) {
        continue;
      }

      var child =
          prop.children.firstWhere((x) => x is XmlElement) as XmlElement;
      var p = child.name.local;
      if (lastStateVariable.name == p) {
        var value = XmlUtils.asRichValue(child.text);
        _controller.add(value);
        _lastValue = value;
        return;
      } else {
        map[p] = XmlUtils.asRichValue(child.text);
      }
    }

    if (map.isNotEmpty) {
      _controller.add(map);
      _lastValue = map;
    }
  }

  String _getId() {
    // ignore: unnecessary_null_comparison
    if (lastStateVariable != null) {
      return lastStateVariable.getGenericId();
    } else {
      return sha256.convert(utf8.encode(eventUrl)).toString();
    }
  }

  Future _sub() async {
    var id = _getId();

    var uri = Uri.parse(eventUrl);

    var request = await UpnpCommon.httpClient.openUrl('SUBSCRIBE', uri);

    var url = await _getCallbackUrl(uri, id);
    if (url != null) {
      lastCallbackUrl = url;

      request.headers.set('User-Agent', 'UPNP.dart/1.0');
      request.headers.set('ACCEPT', '*/*');
      request.headers.set('CALLBACK', '<$url>');
      request.headers.set('NT', 'upnp:event');
      request.headers.set('TIMEOUT', 'Second-$REFRESH');
      request.headers.set('HOST', '${request.uri.host}:${request.uri.port}');

      var response = await request.close();
      await response.drain();

      if (response.statusCode != HttpStatus.ok) {
        throw Exception('Failed to subscribe.');
      }
      if (response.headers.value('SID') != null) {
        _lastSid = response.headers.value('SID')!;
      }

      _timer = Timer(Duration(seconds: REFRESH), () {
        _timer = null;
        _refresh();
      });
    }
  }

  Future _refresh() async {
    var uri = Uri.parse(eventUrl);

    var id = _getId();
    var url = await _getCallbackUrl(uri, id);
    if (url != lastCallbackUrl) {
      await _unsub().timeout(const Duration(seconds: 10), onTimeout: () {
        return null;
      });
      await _sub();
      return;
    }

    var request = await UpnpCommon.httpClient.openUrl('SUBSCRIBE', uri);

    request.headers.set('User-Agent', 'UPNP.dart/1.0');
    request.headers.set('ACCEPT', '*/*');
    request.headers.set('TIMEOUT', 'Second-$REFRESH');
    request.headers.set('SID', _lastSid);
    request.headers.set('HOST', '${request.uri.host}:${request.uri.port}');

    var response = await request.close().timeout(const Duration(seconds: 10),
        onTimeout: () {
      throw Exception('Error on: ' + request.uri.toString());
    });

    if (response.statusCode != HttpStatus.ok) {
      await _controller.close();
      return;
    } else {
      _timer = Timer(Duration(seconds: REFRESH), () {
        _timer = null;
        _refresh();
      });
    }
  }

  Future<String?> _getCallbackUrl(Uri uri, String id) async {
    var host = await InternalNetworkUtils.getMostLikelyHost(uri);
    if (manager.server != null) {
      return 'http://$host:${manager.server!.port}/$id';
    } else {
      return null;
    }
  }

  // ignore: unused_element
  Future _unsub([bool close = false]) async {
    var request =
        await UpnpCommon.httpClient.openUrl('UNSUBSCRIBE', Uri.parse(eventUrl));

    request.headers.set('User-Agent', 'UPNP.dart/1.0');
    request.headers.set('ACCEPT', '*/*');
    request.headers.set('SID', _lastSid);

    var response = await request.close().timeout(const Duration(seconds: 10),
        onTimeout: () {
      throw Exception('Error on: ' + request.uri.toString());
    });

    await response.drain();

    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  void _done() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }

    _controller.close();
  }
}
