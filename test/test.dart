import 'package:test/test.dart';
import 'package:upnp/upnp.dart';

void main() {
  test('test scan', () async {
// given
    var client = DeviceDiscoverer();
    await client.start();

    print('[discontinued:SSDP] Starting search...');
    var services = <Device>{};
    client.quickDiscoverClients().listen((client) async {
      try {
        var dev = await client.getDevice();
        // print('dev:' + dev.toString());
        services.add(dev);
      } catch (e) {
        print(
            '[discontinued:SSDP] ERROR: ${e.toString()} - ${client.location} ');
      }
    });

    expect(
        await Future.delayed(Duration(seconds: 5), () {
          client.stop();
          print(
              '[discontinued:SSDP] \nFinished search, found: [${services.fold<String>('', (prev, element) => prev + '\n\t\t' + element.friendlyName)}\t]');
          return services.length;
        }),
        greaterThan(0));
  });
}
