part of upnp.router;

class Router {
  static Future<Router> find() async {
    try {
      var discovery = DeviceDiscoverer();
      var client = await discovery
          .quickDiscoverClients(
              timeout: const Duration(seconds: 10),
              query: CommonDevices.WAN_ROUTER)
          .first;

      var device = await client.getDevice();
      discovery.stop();
      if (device != null) {
        var router = Router(device);
        await router.init();
        return router;
      } else {
        throw Exception('Device is null!');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Stream<Router> findAll(
      {bool silent = true,
      bool unique = true,
      bool enableIpv4Only = true,
      Duration timeout = const Duration(seconds: 10)}) async* {
    var discovery = DeviceDiscoverer();
    await discovery.start(ipv4: true, ipv6: !enableIpv4Only);
    await for (DiscoveredClient client in discovery.quickDiscoverClients(
        timeout: timeout, query: CommonDevices.WAN_ROUTER, unique: unique)) {
      try {
        var device = await client.getDevice();
        if (device != null) {
          var router = Router(device);
          await router.init();
          yield router;
        }
      } catch (e) {
        if (!silent) {
          rethrow;
        }
      }
    }
  }

  final Device device;

  late Service? _wanExternalService, _wanCommonService, _wanEthernetLinkService;

  Router(this.device);

  bool get hasEthernetLink => _wanEthernetLinkService != null;

  Future init() async {
    _wanExternalService =
        await device.getService('urn:upnp-org:serviceId:WANIPConn1');
    _wanCommonService =
        await device.getService('urn:upnp-org:serviceId:WANCommonIFC1');
    _wanEthernetLinkService =
        await device.getService('urn:upnp-org:serviceId:WANEthLinkC1');
  }

  Future<String?> getExternalIpAddress() async {
    if (_wanExternalService != null) {
      var result =
          await _wanExternalService!.invokeAction('GetExternalIPAddress', {});
      return result!['NewExternalIPAddress'];
    } else {
      return null;
    }
  }

  Future<int> getTotalBytesSent() async {
    if (_wanCommonService != null) {
      var result =
          await _wanCommonService!.invokeAction('GetTotalBytesSent', {});
      return num.tryParse(result!['NewTotalBytesSent'] ?? '0') as int;
    } else {
      return 0;
    }
  }

  Future<int> getTotalBytesReceived() async {
    if (_wanCommonService != null) {
      var result =
          await _wanCommonService!.invokeAction('GetTotalBytesReceived', {});
      return num.tryParse(result!['NewTotalBytesReceived'] ?? '0')!.toInt();
    } else {
      return 0;
    }
  }

  Future<int> getTotalPacketsSent() async {
    if (_wanCommonService != null) {
      var result =
          await _wanCommonService!.invokeAction('GetTotalPacketsSent', {});
      return num.tryParse(result!['NewTotalPacketsSent'] ?? '0')!.toInt();
    } else {
      return 0;
    }
  }

  Future<int> getTotalPacketsReceived() async {
    if (_wanCommonService != null) {
      var result =
          await _wanCommonService!.invokeAction('GetTotalPacketsReceived', {});
      return num.tryParse(result!['NewTotalPacketsReceived'] ?? '0')!.toInt();
    } else {
      return 0;
    }
  }
}
