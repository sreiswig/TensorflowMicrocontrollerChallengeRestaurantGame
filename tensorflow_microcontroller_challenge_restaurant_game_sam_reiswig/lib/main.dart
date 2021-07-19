import 'package:flutter/material.dart';
import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';
import 'package:flutter_web_bluetooth/js_web_bluetooth.dart';
import 'dart:convert';
import 'dart:typed_data';

const redirect = bool.fromEnvironment('redirectToHttps', defaultValue: false);

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: FlutterWebBluetooth.instance.isAvailable,
      initialData: false,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        final available = snapshot.requireData;
        return MaterialApp(
            home: Scaffold(
          appBar: AppBar(
            title: const SelectableText('Bluetooth web example app'),
          ),
          body: MainPage(
            isBluetoothAvailable: available,
          ),
          floatingActionButton: Builder(
            builder: (BuildContext context) {
              final theme = Theme.of(context);
              final errorColor = theme.errorColor;
              return ElevatedButton(
                  onPressed: () async {
                    if (!FlutterWebBluetooth.instance.isBluetoothApiSupported) {
                    } else {
                      try {
                        final device = await FlutterWebBluetooth.instance
                            .requestDevice(
                                RequestOptionsBuilder.acceptAllDevices(
                                    optionalServices:
                                        BluetoothDefaultServiceUUIDS.VALUES
                                            .map((e) => e.uuid)
                                            .toList()));
                        debugPrint("Device got! ${device.name}, ${device.id}");
                      } on BluetoothAdapterNotAvailable {
                        ScaffoldMessenger.maybeOf(context)
                            ?.showSnackBar(SnackBar(
                          content: Text('No bluetooth adapter available'),
                          backgroundColor: errorColor,
                        ));
                      } on UserCancelledDialogError {
                        ScaffoldMessenger.maybeOf(context)
                            ?.showSnackBar(SnackBar(
                          content: Text('User canceled the dialog'),
                          backgroundColor: errorColor,
                        ));
                      } on DeviceNotFoundError {
                        ScaffoldMessenger.maybeOf(context)
                            ?.showSnackBar(SnackBar(
                          content: Text('No devices found'),
                          backgroundColor: errorColor,
                        ));
                      }
                    }
                  },
                  child: Icon(Icons.search));
            },
          ),
        ));
      },
    );
  }
}

class MainPage extends StatefulWidget {
  final bool isBluetoothAvailable;

  const MainPage({
    Key? key,
    required this.isBluetoothAvailable,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return MainPageState();
  }
}

class MainPageState extends State<MainPage> {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      MainPageHeader(
        isBluetoothAvailable: widget.isBluetoothAvailable,
      ),
      Divider(),
      Expanded(
        child: StreamBuilder(
          stream: FlutterWebBluetooth.instance.devices,
          initialData: Set<BluetoothDevice>(),
          builder: (BuildContext context,
              AsyncSnapshot<Set<BluetoothDevice>> snapshot) {
            final devices = snapshot.requireData;
            return ListView.builder(
              itemCount: devices.length,
              itemBuilder: (BuildContext context, int index) {
                final device = devices.toList()[index];
                return BluetoothDeviceWidget(
                  bluetoothDevice: device,
                  onTap: () async {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (BuildContext context) {
                      return DeviceServicesPage(bluetoothDevice: device);
                    }));
                  },
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

class MainPageHeader extends StatelessWidget {
  MainPageHeader({Key? key, required this.isBluetoothAvailable})
      : super(key: key);

  final bool isBluetoothAvailable;

  @override
  Widget build(BuildContext context) {
    final text = isBluetoothAvailable ? 'supported' : 'unsupported';

    final screenWidth = MediaQuery.of(context).size.width;
    final phoneSize = screenWidth <= 620.0;

    final children = <Widget>[
      Container(
          width: phoneSize ? screenWidth : screenWidth * 0.5,
          child: ListTile(
            title: SelectableText('Bluetooth api available'),
            subtitle: SelectableText(
                FlutterWebBluetooth.instance.isBluetoothApiSupported
                    ? 'true'
                    : 'false'),
          )),
      Container(
          width: phoneSize ? screenWidth : screenWidth * 0.5,
          child: ListTile(
            title: SelectableText('Bluetooth available'),
            subtitle: SelectableText(text),
          )),
    ];

    if (phoneSize) {
      children.insert(1, Divider());
      return Column(
        children: children,
      );
    } else {
      return Row(children: children);
    }
  }
}

class BluetoothDeviceWidget extends StatelessWidget {
  final BluetoothDevice bluetoothDevice;
  final VoidCallback? onTap;

  BluetoothDeviceWidget({
    Key? key,
    required this.bluetoothDevice,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cursive = Theme.of(context)
        .textTheme
        .bodyText1
        ?.copyWith(fontStyle: FontStyle.italic);

    return Column(
      children: [
        Container(
            child: ListTile(
          onTap: this.onTap,
          title: Row(
            children: [
              StreamBuilder(
                  stream: this.bluetoothDevice.connected,
                  initialData: false,
                  builder:
                      (BuildContext context, AsyncSnapshot<bool> snapshot) {
                    return Icon(Icons.circle,
                        color:
                            snapshot.requireData ? Colors.green : Colors.red);
                  }),
              SelectableText(this.bluetoothDevice.name ?? 'null',
                  style: this.bluetoothDevice.name == null ? cursive : null),
            ],
          ),
          subtitle: SelectableText(this.bluetoothDevice.id),
          trailing: this.onTap != null ? Icon(Icons.arrow_forward_ios) : null,
        )),
        Divider(),
      ],
    );
  }
}

class DeviceServicesPage extends StatefulWidget {
  DeviceServicesPage({Key? key, required this.bluetoothDevice})
      : super(key: key);

  final BluetoothDevice bluetoothDevice;

  @override
  State<StatefulWidget> createState() {
    return DeviceServicesState();
  }
}

class DeviceServicesState extends State<DeviceServicesPage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: widget.bluetoothDevice.connected,
      initialData: false,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        final connected = snapshot.requireData;
        final theme = Theme.of(context);

        return Scaffold(
            appBar: AppBar(
              title:
                  SelectableText(widget.bluetoothDevice.name ?? 'No name set'),
              actions: [
                Builder(
                  builder: (BuildContext context) {
                    return ElevatedButton(
                      onPressed: () async {
                        if (!widget.bluetoothDevice.hasGATT) {
                          ScaffoldMessenger.maybeOf(context)
                              ?.showSnackBar(SnackBar(
                            content: Text('This device has no gatt'),
                            backgroundColor: theme.errorColor,
                          ));
                          return;
                        }
                        if (connected) {
                          widget.bluetoothDevice.disconnect();
                        } else {
                          await widget.bluetoothDevice.connect();
                        }
                      },
                      child: Text(connected ? 'Disconnect' : 'Connect'),
                    );
                  },
                ),
              ],
            ),
            body: Builder(builder: (BuildContext context) {
              if (connected) {
                return StreamBuilder<List<BluetoothService>>(
                  stream: widget.bluetoothDevice.services,
                  initialData: [],
                  builder: (BuildContext context,
                      AsyncSnapshot<List<BluetoothService>> serviceSnapshot) {
                    if (serviceSnapshot.hasError) {
                      final error = serviceSnapshot.error.toString();
                      debugPrint('Error!: $error');
                      return Center(
                        child: Text(error),
                      );
                    }
                    final services = serviceSnapshot.requireData;
                    if (services.isEmpty) {
                      return Center(
                        child: Text('No services found!'),
                      );
                    }

                    final serviceWidgets = List.generate(services.length,
                        (index) => ServiceWidget(service: services[index]));

                    return Container(
                        child: ListView(
                      children: serviceWidgets,
                    ));
                  },
                );
              } else {
                return Center(
                  child: Text('Click connect first'),
                );
              }
            }));
      },
    );
  }
}

class _ServiceAndCharacteristic {
  final List<BluetoothService> services;
  final List<BluetoothCharacteristic> characteristics;

  const _ServiceAndCharacteristic(this.services, this.characteristics);
}

class ServiceWidget extends StatelessWidget {
  final BluetoothService service;
  late final String? serviceName;

  ServiceWidget({Key? key, required this.service}) : super(key: key) {
    serviceName = BluetoothDefaultServiceUUIDS.VALUES
        .cast<BluetoothDefaultServiceUUIDS?>()
        .firstWhere((element) => element?.uuid == this.service.uuid)
        ?.name;
  }

  Future<_ServiceAndCharacteristic> getServicesAndCharacteristics() async {
    final List<BluetoothService> services = [];
    if (this.service.hasIncludedService) {
      for (final defaultService in BluetoothDefaultServiceUUIDS.VALUES) {
        try {
          final service =
              await this.service.getIncludedService(defaultService.uuid);
          services.add(service);
        } catch (e) {
          if (e is NotFoundError) {
            // Don't want to spam the console.
          } else {
            print(e);
          }
        }
      }
    }
    final List<BluetoothCharacteristic> characteristics = [];
    for (final defaultCharacteristics
        in BluetoothDefaultCharacteristicUUIDS.VALUES) {
      try {
        final characteristic =
            await this.service.getCharacteristic(defaultCharacteristics.uuid);
        characteristics.add(characteristic);
      } catch (e) {
        if (e is NotFoundError) {
          // Don't want to spam the console.
        } else {
          print(e);
        }
      }
    }

    return _ServiceAndCharacteristic(services, characteristics);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: getServicesAndCharacteristics(),
        initialData: _ServiceAndCharacteristic([], []),
        builder: (BuildContext context,
            AsyncSnapshot<_ServiceAndCharacteristic> snapshot) {
          final data = snapshot.requireData;

          final subServices = <Widget>[];
          for (final service in data.services) {
            subServices.addAll([
              Text('Service with uuid: ${service.uuid}'),
              Divider(),
            ]);
          }
          if (subServices.isNotEmpty) {
            subServices.add(Divider(
              thickness: 1.5,
            ));
          }

          final characteristics = <Widget>[];
          for (final characteristic in data.characteristics) {
            characteristics.addAll([
              CharacteristicWidget(characteristic: characteristic),
              Divider(),
            ]);
          }

          return Column(
            children: [
              ListTile(
                title: Text('Service'),
                subtitle: SelectableText(serviceName == null
                    ? service.uuid
                    : '${service.uuid} ($serviceName)'),
              ),
              Divider(
                thickness: 1.5,
              ),
              ...subServices,
              ...characteristics,
              Divider(
                thickness: 2.0,
              ),
            ],
          );
        });
  }
}

class CharacteristicWidget extends StatefulWidget {
  CharacteristicWidget({required this.characteristic, Key? key})
      : super(key: key) {
    characteristicName = BluetoothDefaultCharacteristicUUIDS.VALUES
        .cast<BluetoothDefaultCharacteristicUUIDS?>()
        .firstWhere((element) => element?.uuid == this.characteristic.uuid)
        ?.name;
  }

  final BluetoothCharacteristic characteristic;
  late final String? characteristicName;

  @override
  State<StatefulWidget> createState() {
    return CharacteristicWidgetState();
  }
}

class CharacteristicWidgetState extends State<CharacteristicWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text(widget.characteristicName == null
              ? 'Characteristic'
              : 'Characteristic (${widget.characteristicName})'),
          subtitle: SelectableText(widget.characteristicName == null
              ? widget.characteristic.uuid
              : '${widget.characteristic.uuid} (${widget.characteristicName})'),
        ),
        StreamBuilder<ByteData>(
            stream: widget.characteristic.value,
            builder: (BuildContext context, AsyncSnapshot<ByteData> snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error.toString()}');
              }
              final data = snapshot.data;
              if (data != null) {
                return DataWidget(data: data);
              }
              return Text('No data retrieved!');
            }),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              OutlinedButton(
                  onPressed: () async {
                    await widget.characteristic.readValue();
                  },
                  child: Text('Get value')),
              OutlinedButton(
                  onPressed: () async {
                    if (widget.characteristic.isNotifying) {
                      await widget.characteristic.stopNotifications();
                    } else {
                      await widget.characteristic.startNotifications();
                    }
                    setState(() {});
                  },
                  child: Text(widget.characteristic.isNotifying
                      ? 'Stop notifying'
                      : 'Start notifying'))
            ],
          ),
        ),
      ],
    );
  }
}

class DataWidget extends StatelessWidget {
  DataWidget({required this.data, Key? key}) : super(key: key);

  final ByteData data;

  String _toHex() {
    var output = '0x';
    for (var i = 0; i < data.lengthInBytes; i++) {
      output += data.getUint8(i).toRadixString(16).toUpperCase();
    }
    return output;
  }

  String _asUTF8String() {
    final list =
        List.generate(data.lengthInBytes, (index) => data.getUint8(index));
    try {
      return Utf8Decoder().convert(list);
    } on FormatException {
      print('COULD NOT CONVERT');
      return '';
    } catch (e) {
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              Text('Data as hex:'),
              VerticalDivider(),
              SelectableText(_toHex())
            ],
          ),
          Row(
            children: [
              Text('Data as UTF-8 String:'),
              VerticalDivider(),
              SelectableText(_asUTF8String())
            ],
          ),
        ],
      ),
    );
  }
}
