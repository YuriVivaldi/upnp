part of upnp;

class Action {
  late Service service;
  late String name;
  late List<ActionArgument> arguments = [];

  Action();

  Action.fromXml(XmlElement e) {
    if (XmlUtils.getTextSafe(e, 'name') != null) {
      name = XmlUtils.getTextSafe(e, 'name')!;

      void addArgDef(XmlElement argdef, [bool stripPrefix = false]) {
        if (XmlUtils.getTextSafe(argdef, 'name') != null) {
          var name = XmlUtils.getTextSafe(argdef, 'name')!;

          var direction = XmlUtils.getTextSafe(argdef, 'direction');
          var relatedStateVariable =
              XmlUtils.getTextSafe(argdef, 'relatedStateVariable');
          var isRetVal = direction == 'out';

          if (this.name.startsWith('Get')) {
            var of = this.name.substring(3);
            if (of == name) {
              isRetVal = true;
            }
          }

          if (name.startsWith('Get') && stripPrefix) {
            name = name.substring(3);
          }

          arguments.add(ActionArgument(
              this, name, direction, relatedStateVariable, isRetVal));
        }
      }

      var argumentLists = e.findElements('argumentList');
      if (argumentLists.isNotEmpty) {
        var argList = argumentLists.first;
        if (argList.children
            .any((x) => x is XmlElement && x.name.local == 'name')) {
          // Bad UPnP Implementation fix for WeMo
          addArgDef(argList, true);
        } else {
          for (var argdef in argList.children.whereType<XmlElement>()) {
            addArgDef(argdef);
          }
        }
      }
    }
  }

  Future<Map<String, String>?> invoke(Map<String, dynamic> args) async {
    var param = '  <u:$name xmlns:u="${service.type}">' +
        args.keys.map((it) {
          var argsIt = args[it].toString();
          return '<$it>$argsIt</$it>';
        }).join('\n') +
        '</u:$name>\n';

    return await service.sendToControlUrl(name, param).then((res) {
      var doc = XmlDocument.parse(res);
      var response = doc.rootElement;

      if (response.name.local != 'Body') {
        response =
            response.children.firstWhere((x) => x is XmlElement) as XmlElement;
      }

      if (const bool.fromEnvironment('upnp.action.show_response',
          defaultValue: false)) {
        print('Got Action Response: ${response.toXmlString()}');
      }

      if (!response.name.local.contains('Response') &&
          response.children.length > 1) {
        response = response.children[1] as XmlElement;
      }

      if (response.children.length == 1) {
        var d = response.children[0];

        if (d is XmlElement) {
          if (d.name.local.contains('Response')) {
            response = d;
          }
        }
      }

      if (const bool.fromEnvironment('upnp.action.show_response',
          defaultValue: false)) {
        print('Got Action Response (Real): ${response.toXmlString()}');
      }

      var results = response.children.whereType<XmlElement>().toList();
      var map = <String, String>{};
      for (var r in results) {
        map[r.name.local] = r.text;
      }
      return map;
    }).catchError((e, _s) {
      developer.log('Error :',
          name: 'invoke', error: e, stackTrace: _s as StackTrace);
      return {'_error': '$e', '_stack': '$_s'};
    });
  }
}

class StateVariable {
  late Service service;
  late String name, dataType;
  late dynamic defaultValue;
  late bool doesSendEvents = false;

  StateVariable();

  StateVariable.fromXml(XmlElement e) {
    if (XmlUtils.getTextSafe(e, 'dataType') != null) {
      dataType = XmlUtils.getTextSafe(e, 'dataType')!;
      defaultValue = XmlUtils.asValueType(
          XmlUtils.getTextSafe(e, 'defaultValue'), dataType);
      doesSendEvents = e.getAttribute('sendEvents') == 'yes';
    }
  }

  String getGenericId() {
    return sha1
        .convert(utf8.encode('${service.device.uuid}::${service.id}::$name'))
        .toString();
  }
}

class ActionArgument {
  final Action action;
  final String name;
  final String? direction;
  final String? relatedStateVariable;
  final bool? isRetVal;

  ActionArgument(this.action, this.name, this.direction,
      this.relatedStateVariable, this.isRetVal);

  StateVariable? getStateVariable() {
    if (relatedStateVariable != null) {
      return null;
    }

    var vars = action.service.stateVariables
        .where((x) => x.name == relatedStateVariable);

    if (vars.isNotEmpty) {
      return vars.first;
    }

    return null;
  }
}
