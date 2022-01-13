part of upnp.server;

class UpnpServer {
  static final ContentType _xmlType =
      ContentType.parse('text/xml; charset="utf-8"');

  final UpnpHostDevice? device;

  UpnpServer(this.device);

  Future handleRequest(HttpRequest request) async {
    var uri = request.uri;
    var path = uri.path;

    if (path == '/upnp/root.xml') {
      await handleRootRequest(request);
    } else if (path.startsWith('/upnp/services/') && path.endsWith('.xml')) {
      await handleServiceRequest(request);
    } else if (path.startsWith('/upnp/control/') && request.method == 'POST') {
      await handleControlRequest(request);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  Future handleRootRequest(HttpRequest request) async {
    var urlBase = request.requestedUri.resolve('/').toString();
    if (device != null) {
      var xml = device!.toRootXml(urlBase: urlBase);
      request.response
        ..headers.contentType = _xmlType
        ..writeln(xml);
      await request.response.close();
    }
  }

  Future handleServiceRequest(HttpRequest request) async {
    var name = request.uri.pathSegments.last;
    if (name.endsWith('.xml')) {
      name = name.substring(0, name.length - 4);
    }
    if (device != null) {
      var service = device!.findService(name);
      if (service.type == '_error_') {
        service = device!.findService(Uri.decodeComponent(name));
      }

      if (service.type == '_error_') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      } else {
        var xml = service.toXml();
        request.response
          ..headers.contentType = _xmlType
          ..writeln(xml);
        await request.response.close();
      }
    }
  }

  Future handleControlRequest(HttpRequest request) async {
    var bytes =
        await request.fold(<int>[], (List<int> a, List<int> b) => a..addAll(b));
    var xml2 = xml.XmlDocument.parse(utf8.decode(bytes));
    var root = xml2.rootElement;
    var body = root.firstChild;
    if (device != null) {
      var service = device!.findService(request.uri.pathSegments.last);
      if (service.type == '_error_') {
        service = device!
            .findService(Uri.decodeComponent(request.uri.pathSegments.last));
      }

      if (service.type == '_error_') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      if (body != null) {
        for (var node in body.children) {
          if (node is xml.XmlElement) {
            var name = node.name.local;
            var act = service.actions.firstWhere((x) => x.name == name,
                orElse: () => UpnpHostAction('_notAnUpnpHostAction_',
                    handler: (Map<String, dynamic> params) {}));
            if (act.name == '_notAnUpnpHostAction_') {
              request.response.statusCode = HttpStatus.notFound;
              await request.response.close();
              return;
            }

            if (act.handler != null) {
              await act.handler!({});
              request.response.statusCode = HttpStatus.ok;
              await request.response.close();
              return;
            }
          }
        }
      }
    }
  }
}
