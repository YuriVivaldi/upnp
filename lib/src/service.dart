part of upnp;

const String _SOAP_BODY =
    '''
<?xml version='1.0' encoding='utf-8'?>
<s:Envelope xmlns:s='http://schemas.xmlsoap.org/soap/envelope/' s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/'>
  <s:Body>
  {param}
  </s:Body>
</s:Envelope>
''';

class ServiceDescription {
  late String type, id, controlUrl, eventSubUrl;
  late String scpdUrl;

  ServiceDescription.fromXml(Uri uriBase, XmlElement service) {
    if (XmlUtils.getTextSafe(service, 'serviceType') != null &&
        XmlUtils.getTextSafe(service, 'serviceId') != null &&
        XmlUtils.getTextSafe(service, 'controlURL') != null &&
        XmlUtils.getTextSafe(service, 'eventSubURL') != null) {
      type = XmlUtils.getTextSafe(service, 'serviceType')!.trim();
      id = XmlUtils.getTextSafe(service, 'serviceId')!.trim();
      controlUrl = uriBase
          .resolve(XmlUtils.getTextSafe(service, 'controlURL')!.trim())
          .toString();
      eventSubUrl = uriBase
          .resolve(XmlUtils.getTextSafe(service, 'eventSubURL')!.trim())
          .toString();

      var m = XmlUtils.getTextSafe(service, 'SCPDURL');

      if (m != null) {
        scpdUrl = uriBase.resolve(m).toString();
      }
    }
  }

  Future<Service> getService({required Device device}) async {
    var dio = Dio();
    var response = await dio
        .getUri(Uri.parse(scpdUrl))
        .then((res) => res)
        .catchError((e, _s) =>
            throw Exception('Unable to get service from $scpdUrl\n $e : $_s'));

    if (response.statusCode != 200 && response.statusCode != 501) {
      await getService(device: Device());
    }

    XmlElement doc;

    try {
      doc = XmlDocument.parse(response.data.toString()).rootElement;
    } catch (e) {
      rethrow;
    }

    var actionList = doc.findElements('actionList');
    var varList = doc.findElements('serviceStateTable');
    var acts = <Action>[];

    if (actionList.isNotEmpty) {
      for (var e in actionList.first.children) {
        if (e is XmlElement) {
          acts.add(Action.fromXml(e));
        }
      }
    }

    var vars = <StateVariable>[];

    if (varList.isNotEmpty) {
      for (var e in varList.first.children) {
        if (e is XmlElement) {
          vars.add(StateVariable.fromXml(e));
        }
      }
    }

    var service =
        Service(device, type, id, controlUrl, eventSubUrl, scpdUrl, acts, vars);

    for (var act in acts) {
      act.service = service;
    }

    for (var v in vars) {
      v.service = service;
    }

    return service;
  }

  @override
  String toString() => 'ServiceDescription($id)';
}

class Service {
  final Device device;
  final String type;
  final String id;
  final List<Action> actions;
  final List<StateVariable> stateVariables;

  bool log;

  String controlUrl;
  String eventSubUrl;
  String scpdUrl;

  Service(this.device, this.type, this.id, this.controlUrl, this.eventSubUrl,
      this.scpdUrl, this.actions, this.stateVariables,
      [bool? printLog])
      : log = printLog ?? false;

  List<String> get actionNames => actions.map((x) => x.name).toList();

  Future<String> sendToControlUrl(String name, String param) async {
    log ? print('\"$type#$name\"') : null;
    var dio = Dio(BaseOptions(
      receiveTimeout: 10000,
      contentType: 'text/xml; charset="utf-8"',
      connectTimeout: 10000,
      headers: {
        'SOAPACTION': '\"$type#$name\"',
        'User-Agent': 'CyberGarage-HTTP/1.0'
      },
      responseType: ResponseType.plain,
      sendTimeout: 10000,
    ));
    // Response response;
    var body = _SOAP_BODY.replaceAll('{param}', param);

    // dio.options.headers['SOAPACTION'] = '\"$type#$name\"';
    // dio.options.headers['Content-Type'] = 'text/xml; charset="utf-8"';
    // dio.options.headers['User-Agent'] = 'CyberGarage-HTTP/1.0';

    return await dio.postUri(Uri.parse(controlUrl), data: body).then((res) {
      // developer.log(res.toString());
      if (res.statusCode != 200) {
        try {
          var doc = XmlDocument.parse(res.data.toString());
          throw UpnpException(doc.rootElement);
        } on DioError catch (e) {
          developer.log(
            'Unable to post to $controlUrl with body: $body',
            error: e.toString(),
            name: 'DioError on sendToControlUrl',
          );

          rethrow;
        } on SocketException catch (scke) {
          return '${scke.toString()}';
        } catch (e) {
          if (e is! UpnpException) {
            throw Exception('\n\n${res.data.toString()}');
          } else {
            rethrow;
          }
        }
      } else {
        // developer.log(
        //     controlUrl + '\n' + body + '\n' + dio.options.headers.toString());
        return res.data.toString();
      }
    }).catchError((e, StackTrace? _s) {
      developer.log(
        'Unable to post to $controlUrl with body: $body',
        error: e.toString(),
        stackTrace: _s,
        name: 'sendToControlUrl',
      );
      // throw Exception('Unable to post to $controlUrl with body: $body');
    });
  }

  Future<Map<String, String>?> invokeAction(
      String name, Map<String, dynamic> args) async {
    return await actions
        .firstWhere(
          (it) => it.name == name,
          orElse: () => throw Exception('Unable to invoke action'),
        )
        .invoke(args)
        .then((value) {
      if (value!.containsKey('_error')) {
        developer.log(
          'Error on invoke for $name => ${args.toString()}',
          error: value.toString(),
        );
      }
      return value;
    }).catchError((Object? e, StackTrace? _s) {
      developer.log('Error on invoke for $name => ${args.toString()}',
          error: e, stackTrace: _s, name: 'invokeAction');
      return {'_error': '$e', '_stack': '$_s'};
    });
  }
}
