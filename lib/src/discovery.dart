part of upnp;

final InternetAddress _v4_Multicast = InternetAddress('239.255.255.250');
final InternetAddress _v4_Hotspot = InternetAddress('239.255.255.255');
final InternetAddress _v6_Multicast = InternetAddress('FF05::C');

class DeviceDiscoverer {
  final List<RawDatagramSocket> _sockets = <RawDatagramSocket>[];
  StreamController<DiscoveredClient> _clientController =
      StreamController.broadcast();

  late List<NetworkInterface> _interfaces;

  Future start({bool ipv4 = true, bool ipv6 = true}) async {
    _interfaces = await NetworkInterface.list();

    if (ipv4) {
      _createSocket(InternetAddress.anyIPv4);
    }

    if (ipv6) {
      _createSocket(InternetAddress.anyIPv6);
    }
  }

  void _createSocket(InternetAddress address) async {
    var socket = await RawDatagramSocket.bind(address, 0);

    socket.broadcastEnabled = true;
    socket.readEventsEnabled = true;
    socket.multicastHops = 50;

    socket.listen((event) {
      switch (event) {
        case RawSocketEvent.read:
          var packet = socket.receive();
          socket.writeEventsEnabled = true;
          socket.readEventsEnabled = true;

          if (packet == null) {
            return;
          }

          var data = utf8.decode(packet.data);
          var parts = data.split('\r\n');
          parts.removeWhere((x) => x.trim().isEmpty);
          var firstLine = parts.removeAt(0);

          if ((firstLine.toLowerCase().trim() ==
                  'HTTP/1.1 200 OK'.toLowerCase()) ||
              (firstLine.toLowerCase().trim() ==
                  'NOTIFY * HTTP/1.1'.toLowerCase())) {
            var headers = <String, String>{};
            var client = DiscoveredClient();

            for (var part in parts) {
              var hp = part.split(':');
              var name = hp[0].trim();
              var value = (hp..removeAt(0)).join(':').trim();
              headers[name.toUpperCase()] = value;
            }

            if (!headers.containsKey('LOCATION')) {
              return;
            }

            client.st = headers['ST']!;
            client.usn = headers['USN']!;
            client.location = headers['LOCATION']!;
            client.server = headers['SERVER']!;
            client.headers = headers;

            _clientController.add(client);
          }

          break;
        case RawSocketEvent.write:
        case RawSocketEvent.closed:
        case RawSocketEvent.readClosed:
        default:
          break;
      }
    });
    try {
      try {
        socket.joinMulticast(_v4_Multicast);
      } on OSError catch (e) {
        print('DiscoveryErro[_v4_Multicast]: ' +
            _v4_Multicast.toString() +
            '\n' +
            e.toString());
        try {
          socket.joinMulticast(_v4_Hotspot);
        } on OSError catch (e) {
          print('DiscoveryError[_v4_Hotspot]: ' +
              _v4_Hotspot.toString() +
              '\n' +
              e.toString());
          try {
            socket.joinMulticast(_v6_Multicast);
          } on OSError catch (e) {
            print('DiscoveryError[_v6_Multicast]: ' +
                _v6_Multicast.toString() +
                '\n' +
                e.toString());
          }
        }
      }
    } catch (e) {
      print('DiscoveryError: ' + e.toString());

      for (var interface in _interfaces) {
        try {
          socket.joinMulticast(_v4_Multicast, interface);
        } on OSError catch (e) {
          print('DiscoveryError[_v4_Multicast]: ' +
              _v4_Multicast.toString() +
              '\n' +
              e.toString());
          try {
            socket.joinMulticast(_v4_Hotspot, interface);
          } on OSError catch (e) {
            print('DiscoveryError[_v4_Hotspot]: ' +
                _v4_Hotspot.toString() +
                '\n' +
                e.toString());
            try {
              socket.joinMulticast(_v6_Multicast, interface);
            } on OSError catch (e) {
              print('DiscoveryError[_v6_Multicast]: ' +
                  _v6_Multicast.toString() +
                  '\n' +
                  e.toString());
            }
          }
        }
      }
    }
    _sockets.add(socket);
  }

  void stop() {
    if (_discoverySearchTimer != null) {
      _discoverySearchTimer!.cancel();
      _discoverySearchTimer = null;
    }

    for (var socket in _sockets) {
      socket.close();
    }

    if (!_clientController.isClosed) {
      _clientController.close();
      _clientController = StreamController<DiscoveredClient>.broadcast();
    }
  }

  Stream<DiscoveredClient> get clients => _clientController.stream;

  void search([String? searchTarget]) {
    searchTarget ??= 'upnp:rootdevice';

    var buff = StringBuffer();

    buff.write('M-SEARCH * HTTP/1.1\r\n');
    buff.write('HOST: 239.255.255.250:1900\r\n');
    buff.write('MAN: "ssdp:discover"\r\n');
    buff.write('MX: 1\r\n');
    buff.write('ST: $searchTarget\r\n');
    buff.write('USER-AGENT: unix/5.1 UPnP/1.1 crash/1.0\r\n\r\n');
    var data = utf8.encode(buff.toString());

    for (var socket in _sockets) {
      if (socket.address.type == _v4_Multicast.type) {
        try {
          socket.send(data, _v4_Multicast, 1900);
          // ignore: empty_catches
        } on SocketException {
          try {
            socket.send(data, _v4_Hotspot, 1900);
            // ignore: empty_catches
          } on SocketException {}
        }

        try {
          socket.send(data, _v4_Multicast, 1900);
          // ignore: empty_catches
        } on SocketException {
          try {
            socket.send(data, _v4_Hotspot, 1900);
            // ignore: empty_catches
          } on SocketException {}
        }
      }

      if (socket.address.type == _v6_Multicast.type) {
        try {
          socket.send(data, _v6_Multicast, 1900);
          // ignore: empty_catches
        } on SocketException {
          try {
            socket.send(data, _v6_Multicast, 1900);
            // ignore: empty_catches
          } on SocketException {}
        }
      }
    }
  }

  Future<List<DiscoveredClient>> discoverClients(
      {Duration timeout = const Duration(seconds: 5)}) async {
    var list = <DiscoveredClient>[];

    var sub = clients.listen((client) => list.add(client));

    if (_sockets.isEmpty) {
      await start();
    }

    search();
    await Future.delayed(timeout);
    await sub.cancel();
    stop();
    return list;
  }

  Timer? _discoverySearchTimer;

  Stream<DiscoveredClient> quickDiscoverClients(
      {Duration timeout = const Duration(seconds: 5),
      Duration searchInterval = const Duration(seconds: 10),
      String? query,
      bool unique = true}) async* {
    if (_sockets.isEmpty) {
      await start();
    }

    var seen = <String>{};

    search(query);
    Future.delayed(timeout, () {
      stop();
    });

    search(query);
    _discoverySearchTimer = Timer.periodic(searchInterval, (_) {
      search(query);
    });

    await for (var client in clients) {
      if (unique && seen.contains(client.usn)) {
        continue;
      }

      seen.add(client.usn);
      yield client;
    }
  }

  Future<List<DiscoveredDevice>> discoverDevices(
      {String? type, Duration timeout = const Duration(seconds: 5)}) {
    return discoverClients(timeout: timeout).then((clients) {
      if (clients.isEmpty) {
        return [];
      }

      var uuids = clients
          .where((client) => client.usn.contains('::'))
          .map((client) => client.usn.split('::').first)
          .toSet();
      var devices = <DiscoveredDevice>[];

      for (var uuid in uuids) {
        var deviceClients = clients.where((client) {
          return client.usn.split('::').first == uuid;
        }).toList();
        var location = deviceClients.first.location;
        var serviceTypes = deviceClients.map((it) => it.st).toSet().toList();
        var device = DiscoveredDevice();
        device.serviceTypes = serviceTypes;
        device.uuid = uuid;
        device.location = location;
        if (serviceTypes.contains(type)) {
          devices.add(device);
        }
      }

      for (var client in clients) {
        var device = DiscoveredDevice();
        device.serviceTypes = [client.st];
        device.uuid = '';
        device.location = client.location;
        if (device.serviceTypes.contains(type)) {
          devices.add(device);
        }
      }

      return devices;
    });
  }

  Future<List<Device>> getDevices(
      {required String type,
      Duration timeout = const Duration(seconds: 5),
      bool silent = true}) async {
    var results = await discoverDevices(type: type, timeout: timeout);

    var list = <Device>[];
    for (var result in results) {
      try {
        var device = await result.getRealDevice();

        if (device != null) {
          list.add(device);
        }
        // ignore: empty_catches
      } on ArgumentError {} catch (e) {
        if (!silent) {
          rethrow;
        }
      }
    }
    return list;
  }
}

class DiscoveredDevice {
  List<String> serviceTypes = [];
  late String uuid, location;

  Future<Device?> getRealDevice() async {
    var dio = Dio();
    Response response;

    try {
      await dio.getUri(Uri.parse(location)).then((res) async {
        response = res;

        if (response.statusCode != 200) {
          throw Exception('''ERROR: Failed to fetch device description.
               Status Code: ${response.statusCode}''');
        }

        XmlDocument doc;

        try {
          doc = XmlDocument.parse(response.data.toString());
        } on Exception catch (e) {
          throw FormatException('''ERROR: Failed to parse device description. 
                      $e''');
        }

        if (doc.findAllElements('device').isEmpty) {
          throw ArgumentError('Not SCPD Compatible');
        }

        return Device.loadFromXml(location, doc.rootElement);
      });
    } catch (_) {
      return null;
    }
  }
}

class DiscoveredClient {
  late String st;
  late String usn;
  late String server;
  late String location;
  late Map<String, String> headers;

  DiscoveredClient();

  DiscoveredClient.fake(this.location);

  @override
  String toString() {
    var buff = StringBuffer();
    buff.writeln('ST: $st');
    buff.writeln('USN: $usn');
    buff.writeln('SERVER: $server');
    buff.writeln('LOCATION: $location');
    return buff.toString();
  }

  Future<Device?> getDevice() async {
    Uri uri;

    try {
      uri = Uri.parse(location);

      var dio = Dio();
      Response response;
      await dio.getUri(uri).then((res) {
        response = res;

        if (response.statusCode != 200) {
          throw Exception('''ERROR: Failed to fetch device description.
             Status Code: ${response.statusCode}''');
        }

        XmlDocument doc;

        try {
          doc = XmlDocument.parse(response.data.toString());
        } on Exception catch (e) {
          throw FormatException('''ERROR: Failed to parse device
             description:
             => $e''');
        }

        return Device.loadFromXml(location, doc.getElement('root')!);
      });
    } catch (e) {
      return null;
    }
  }
}
