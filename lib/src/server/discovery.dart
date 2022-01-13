part of upnp.server;

final InternetAddress _v4_Multicast = InternetAddress('239.255.255.250');
final InternetAddress _v6_Multicast = InternetAddress('FF05::C');

class UpnpDiscoveryServer {
  final UpnpHostDevice device;
  final String rootDescriptionUrl;

  UpnpDiscoveryServer(this.device, this.rootDescriptionUrl);

  late RawDatagramSocket? _socket;
  late Timer? _timer;
  late List<NetworkInterface> _interfaces;

  Future start() async {
    await stop();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_socket != null) {
        notify();
      }
    });

    _socket = await RawDatagramSocket.bind('0.0.0.0', 1900);

    _interfaces = await NetworkInterface.list();
    if (_socket != null) {
      var joinMulticastFunction = _socket!.joinMulticast;
      for (var interface in _interfaces) {
        void withAddress(InternetAddress address) {
          try {
            Function.apply(
                joinMulticastFunction, [address], {#interface: interface});
          } on NoSuchMethodError {
            Function.apply(joinMulticastFunction, [address, interface]);
          }
        }

        try {
          withAddress(_v4_Multicast);
        } on SocketException {
          try {
            withAddress(_v6_Multicast);
          } on OSError catch (osErr) {
            print(osErr.message);
          }
        } on OSError catch (osErr) {
          print(osErr.message);
        }
      }

      _socket!.broadcastEnabled = true;
      _socket!.multicastHops = 100;

      _socket!.listen((RawSocketEvent e) async {
        if (e == RawSocketEvent.read) {
          var packet = _socket!.receive();
          _socket!.writeEventsEnabled = true;

          try {
            var string = utf8.decode(packet!.data);
            var lines = string.split('\r\n');
            var firstLine = lines.first;

            if (firstLine.trim() == 'M-SEARCH * HTTP/1.1') {
              var map = {};
              for (var line in lines.skip(1)) {
                if (line.trim().isEmpty) continue;
                if (!line.contains(':')) continue;
                var parts = line.split(':');
                var key = parts.first;
                var value = parts.skip(1).join(':');
                map[key.toUpperCase()] = value;
              }

              if (map['ST'] is String) {
                var search = map['ST'];
                var devices = await respondToSearch(
                    search as String, packet, map as Map<String, String>);
                for (var dev in devices) {
                  _socket!.send(utf8.encode(dev), packet.address, packet.port);
                }
              }
            }
            // ignore: empty_catches
          } catch (e) {}
        }
      });

      await notify();
    }
  }

  Future<List<String>> respondToSearch(
      String target, Datagram pkt, Map<String, String> headers) async {
    var out = <String>[];

    // ignore: always_declare_return_types
    addDevice(String profile) {
      var buff = StringBuffer();
      buff.write('HTTP/1.1 200 OK\r\n');
      buff.write('CACHE-CONTROL: max-age=180\r\n');
      buff.write('EXT:\r\n');
      buff.write('LOCATION: $rootDescriptionUrl\r\n');
      buff.write('SERVER: UPnP.dart/1.0\r\n');
      buff.write('ST: $profile\r\n');
      buff.write('USN: ${device.deviceType}::$profile\r\n');
      out.add(buff.toString());
    }

    if (device.deviceType != null) {
      if (target == 'ssdp:all') {
        addDevice(device.deviceType!);
        for (var svc in device.services) {
          addDevice(svc.type);
        }
      } else if (target == device.deviceType || target == 'upnp:rootdevice') {
        addDevice(device.deviceType!);
      } else if (target == device.udn) {
        addDevice(device.deviceType!);
      }
    }

    var svc = device.findService(target);

    addDevice(svc.type);

    return out;
  }

  Future notify() async {
    if (_socket != null) {
      var buff = StringBuffer();
      buff.write('NOTIFY * HTTP/1.1\r\n');
      buff.write('HOST: 239.255.255.250:1900\r\n');
      buff.write('CACHE-CONTROL: max-age=10');
      buff.write('LOCATION: $rootDescriptionUrl\r\n');
      buff.write('NT: ${device.deviceType}\r\n');
      buff.write('NTS: ssdp:alive\r\n');
      buff.write('USN: uuid:${UpnpHostUtils.generateToken()}\r\n');
      var bytes = utf8.encode(buff.toString());
      _socket!.send(bytes, _v4_Multicast, 1900);
    }
  }

  Future stop() async {
    if (_socket != null) {
      _socket!.close();
      _socket = null;
    }

    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }
}
