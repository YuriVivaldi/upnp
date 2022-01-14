import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:upnp/upnp.dart';
import 'package:xml/xml.dart';

void main() {
  test('parseXML', () async {
    // var xml =
    //     '<root xmlns="urn:schemas-upnp-org:device-1-0" xmlns:dlna="urn:schemas-dlna-org:device-1-0"><specVersion><major>1</major><minor>0</minor></specVersion><device><dlna:X_DLNADOC>DMR-1.50</dlna:X_DLNADOC><deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType><friendlyName>P30_SCRIVANIA</friendlyName><manufacturer>Vivaldi United Group</manufacturer><manufacturerURL>https://www.vivaldigroup.it/</manufacturerURL><modelDescription>30+30W Mixer Amplifier</modelDescription><modelName>Vivaldi_P30S_AC5A</modelName><modelURL>https://www.Vivaldigroup.it/</modelURL><UDN>uuid:FF31F0AB-6C48-D353-D9AA-6F53FF31F0AB</UDN><modelNumber>V01-Jan 8 2020 </modelNumber><serialNumber>00001</serialNumber><ssidName>Vivaldi P30S_AC5A</ssidName><uuid>FF31F0AB6C48D353D9AA6F53</uuid><qq:X_QPlay_SoftwareCapability xmlns:qq="http://www.tencent.com">QPlay:2</qq:X_QPlay_SoftwareCapability><iconList><icon><mimetype>image/png</mimetype><width>48</width><height>48</height><depth>24</depth><url>/upnp/grender-48x48.png</url></icon><icon><mimetype>image/png</mimetype><width>120</width><height>120</height><depth>24</depth><url>/upnp/grender-120x120.png</url></icon><icon><mimetype>image/jpeg</mimetype><width>48</width><height>48</height><depth>24</depth><url>/upnp/grender-48x48.jpg</url></icon><icon><mimetype>image/jpeg</mimetype><width>120</width><height>120</height><depth>24</depth><url>/upnp/grender-120x120.jpg</url></icon></iconList><serviceList><service><serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType><serviceId>urn:upnp-org:serviceId:AVTransport</serviceId><SCPDURL>/upnp/rendertransportSCPD.xml</SCPDURL><controlURL>/upnp/control/rendertransport1</controlURL><eventSubURL>/upnp/event/rendertransport1</eventSubURL></service><service><serviceType>urn:schemas-upnp-org:service:ConnectionManager:1</serviceType><serviceId>urn:upnp-org:serviceId:ConnectionManager</serviceId><SCPDURL>/upnp/renderconnmgrSCPD.xml</SCPDURL><controlURL>/upnp/control/renderconnmgr1</controlURL><eventSubURL>/upnp/event/renderconnmgr1</eventSubURL></service><service><serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType><serviceId>urn:upnp-org:serviceId:RenderingControl</serviceId><SCPDURL>/upnp/rendercontrolSCPD.xml</SCPDURL><controlURL>/upnp/control/rendercontrol1</controlURL><eventSubURL>/upnp/event/rendercontrol1</eventSubURL></service><service><serviceType>urn:schemas-wiimu-com:service:PlayQueue:1</serviceType><serviceId>urn:wiimu-com:serviceId:PlayQueue</serviceId><SCPDURL>/upnp/PlayQueueSCPD.xml</SCPDURL><controlURL>/upnp/control/PlayQueue1</controlURL><eventSubURL>/upnp/event/PlayQueue1</eventSubURL></service><service><serviceType>urn:schemas-tencent-com:service:QPlay:1</serviceType><serviceId>urn:tencent-com:serviceId:QPlay</serviceId><SCPDURL>/upnp/QPlaySCPD.xml</SCPDURL><controlURL>/upnp/control/QPlay1</controlURL><eventSubURL>/upnp/event/QPlay1</eventSubURL></service></serviceList></device></root>';

    var res =
        await Dio().get<String>('http://172.0.1.252:49152/description.xml');
    var xml = res.data.toString();

    var dev = Device.loadFromXml('http://172.0.1.252:49152/description.xml',
        XmlDocument.parse(xml).rootElement);
    print(dev.friendlyName + ' ' + dev.serviceNames.toString());
    expect(dev.friendlyName, 'VIVALDI_Keysol_227D');
  });
}
