part of upnp.server;

class UpnpHostDevice {
  String? deviceType,
      friendlyName,
      manufacturer,
      manufacturerUrl,
      modelName,
      modelDescription,
      modelNumber,
      modelUrl,
      udn,
      serialNumber,
      presentationUrl,
      upc;

  List<UpnpHostIcon> icons = <UpnpHostIcon>[];
  List<UpnpHostService> services = <UpnpHostService>[];

  UpnpHostDevice({
    required this.deviceType,
    required this.friendlyName,
    required this.manufacturer,
    required this.manufacturerUrl,
    required this.modelName,
    required this.modelNumber,
    required this.modelDescription,
    required this.modelUrl,
    required this.serialNumber,
    required this.presentationUrl,
    required this.udn,
    required this.upc,
  });

  UpnpHostService findService(String name) {
    return services.firstWhere(
        (service) => service.simpleName == name || service.id == name,
        orElse: () => UpnpHostService(
              id: '_notUpnpHostService_',
              type: '_error_',
            ));
  }

  xml.XmlNode toRootXml({String? urlBase}) {
    var x = xml.XmlBuilder();
    x.element('root', nest: () {
      x.namespace('urn:schemas-upnp-org:device-1-0');
      x.element('specVersion', nest: () {
        x.element('major', nest: '1');
        x.element('minor', nest: '0');
      });

      if (urlBase != null) {
        x.element('URLBase', nest: urlBase);
      }

      x.element('device', nest: () {
        if (deviceType != null) {
          x.element('deviceType', nest: deviceType);
        }

        if (friendlyName != null) {
          x.element('friendlyName', nest: friendlyName);
        }

        if (manufacturer != null) {
          x.element('manufacturer', nest: manufacturer);
        }

        if (manufacturerUrl != null) {
          x.element('manufacturerURL', nest: manufacturerUrl);
        }

        if (modelName != null) {
          x.element('modelName', nest: modelName);
        }

        if (modelDescription != null) {
          x.element('modelDescription', nest: modelDescription);
        }

        if (modelNumber != null) {
          x.element('modelNumber', nest: modelNumber);
        }

        if (modelUrl != null) {
          x.element('modelURL', nest: modelUrl);
        }

        if (serialNumber != null) {
          x.element('serialNumber', nest: serialNumber);
        }

        if (udn != null) {
          x.element('UDN', nest: udn);
        }

        if (presentationUrl != null) {
          x.element('presentationURL', nest: presentationUrl);
        }

        if (icons.isNotEmpty) {
          x.element('iconList', nest: () {
            for (var icon in icons) {
              icon.applyToXml(x);
            }
          });
        }

        x.element('serviceList', nest: () {
          for (var service in services) {
            x.element('service', nest: () {
              var svcName =
                  service.simpleName ?? Uri.encodeComponent(service.id);
              x.element('serviceType', nest: service.type);
              x.element('serviceId', nest: service.id);
              x.element('controlURL', nest: '/upnp/control/$svcName');
              x.element('eventSubURL', nest: '/upnp/events/$svcName');
              x.element('SCPDURL', nest: '/upnp/services/$svcName.xml');
            });
          }
        });
      });
    });
    // ignore: deprecated_member_use
    return x.build();
  }
}

class UpnpHostIcon {
  final int width;
  final int height;
  final int depth;
  final String mimetype;
  final String url;

  UpnpHostIcon(
      {required this.mimetype,
      required this.width,
      required this.height,
      required this.depth,
      required this.url});

  void applyToXml(xml.XmlBuilder builder) {
    builder.element('icon', nest: () {
      builder.element('mimetype', nest: mimetype);
      builder.element('width', nest: width.toString());
      builder.element('height', nest: height.toString());
      builder.element('depth', nest: depth.toString());
      builder.element('url', nest: url.toString());
    });
  }
}
