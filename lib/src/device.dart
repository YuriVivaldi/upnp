part of upnp;

class Device {
  late XmlElement deviceElement;

  late String deviceType,
      urlBase,
      friendlyName,
      manufacturer,
      modelName,
      udn,
      uuid,
      url,
      presentationUrl,
      modelType,
      modelDescription,
      modelNumber,
      manufacturerUrl;

  bool log;

  List<Icon> icons = [];
  late List<ServiceDescription> services;

  List<String> get serviceNames => services.map((x) => x.id).toList();
  Device([bool? printLog])
      : log = printLog ?? false,
        services = [];

  Device.loadFromXml(String u, XmlElement e, [bool? printLog])
      : log = printLog ?? false,
        services = [] {
    url = u;
    deviceElement = e;
    var uri = Uri.parse(url);

    log ? print(e.toString()) : null;
    urlBase = uri.toString();

    if (deviceElement.findElements('device').isEmpty) {
      log ? print('No device XML') : null;
      throw Exception('ERROR: Invalid Device XML!\n\n$deviceElement');
    }

    var deviceNode = XmlUtils.getElementByName(deviceElement, 'device');

    deviceType = XmlUtils.getTextSafe(deviceNode, 'deviceType') ?? 'deviceType';
    friendlyName =
        XmlUtils.getTextSafe(deviceNode, 'friendlyName') ?? 'friendlyName';
    modelName = XmlUtils.getTextSafe(deviceNode, 'modelName') ?? 'modelName';
    manufacturer =
        XmlUtils.getTextSafe(deviceNode, 'manufacturer') ?? 'manufacturer';
    udn = XmlUtils.getTextSafe(deviceNode, 'UDN') ?? 'UDN';
    presentationUrl = XmlUtils.getTextSafe(deviceNode, 'presentationURL') ??
        'presentationURL';
    modelType = XmlUtils.getTextSafe(deviceNode, 'modelType') ?? 'modelType';
    modelDescription = XmlUtils.getTextSafe(deviceNode, 'modelDescription') ??
        'modelDescription';
    manufacturerUrl = XmlUtils.getTextSafe(deviceNode, 'manufacturerURL') ??
        'manufacturerURL';

    if (udn != 'UDN') {
      uuid = udn.substring('uuid:'.length);
    }

    if (deviceNode.findElements('iconList').isNotEmpty) {
      var iconList = deviceNode.findElements('iconList').first;
      for (var child in iconList.children) {
        if (child is XmlElement) {
          var icon = Icon();
          if (XmlUtils.getTextSafe(child, 'mimetype') != null &&
              XmlUtils.getTextSafe(child, 'width') != null &&
              XmlUtils.getTextSafe(child, 'height') != null &&
              XmlUtils.getTextSafe(child, 'depth') != null &&
              XmlUtils.getTextSafe(child, 'url') != null) {
            icon.mimetype = XmlUtils.getTextSafe(child, 'mimetype')!;
            var width = XmlUtils.getTextSafe(child, 'width')!;
            var height = XmlUtils.getTextSafe(child, 'height')!;
            var depth = XmlUtils.getTextSafe(child, 'depth')!;
            var url = XmlUtils.getTextSafe(child, 'url')!;

            icon.width = int.parse(width);
            icon.height = int.parse(height);
            icon.depth = int.parse(depth);
            icon.url = url;

            icons.add(icon);
          }
        }
      }
    }

    processDeviceNode(deviceNode);
  }

  Future<Service> getService(String type) async {
    try {
      var service =
          services.firstWhere((it) => it.type == type || it.id == type);

      return await service.getService(device: this).catchError((e) {
        log ? print('Error on ${e as Object}') : null;
      });
    } on StateError catch (state) {
      log ? print(url + '\n' + state.toString()) : null;
      rethrow;
    } catch (generic) {
      log ? print(generic) : null;
      rethrow;
    }
  }

  void processDeviceNode(XmlElement e) {
    if (e.findElements('serviceList').isNotEmpty) {
      var list = e.findElements('serviceList').first;
      for (var svc in list.children) {
        if (svc is XmlElement) {
          services.add(ServiceDescription.fromXml(Uri.parse(urlBase), svc));
        }
      }
    }

    if (e.findElements('deviceList').isNotEmpty) {
      var list = e.findElements('deviceList').first;
      for (var dvc in list.children) {
        if (dvc is XmlElement) {
          processDeviceNode(dvc);
        }
      }
    }
  }
}

class Icon {
  late String mimetype;
  late int width, height, depth;
  late String url;
}

class CommonDevices {
  static const String DIAL = 'urn:dial-multiscreen-org:service:dial:1';
  static const String CHROMECAST = DIAL;
  static const String WEMO = 'urn:Belkin:device:controllee:1';
  static const String WIFI_ROUTER =
      'urn:schemas-wifialliance-org:device:WFADevice:1';
  static const String WAN_ROUTER =
      'urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1';
}
