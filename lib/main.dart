import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart";
import "package:latlong2/latlong.dart";
import 'package:location/location.dart';
import 'loginPage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "ParkU",
      home: HomeScreen(),
    );
  }
}

//get current location
Future<LocationData?> _currentLocation() async {
  bool serviceEnabled;
  PermissionStatus permissionGranted;

  Location location = new Location();

  serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) {
      return null;
    }
  }

  permissionGranted = await location.hasPermission();
  if (permissionGranted == PermissionStatus.denied) {
    permissionGranted = await location.requestPermission();
    if (permissionGranted != PermissionStatus.granted) {
      return null;
    }
  }
  return await location.getLocation();
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 18; i++) {
      _markers.add(Marker(
        width: 80.0,
        height: 80.0,
        point: LatLng(51.229749, 4.41736 + i * 0.00007),
        builder: (ctx) => const Icon(Icons.location_on),
      ));
      _markers.add(Marker(
        width: 80.0,
        height: 80.0,
        point: LatLng(51.228982 + i * 0.000006, 4.41736 + i * 0.00007),
        builder: (ctx) => const Icon(Icons.location_on),
      ));
      if (i < 10) {
        _markers.add(Marker(
          width: 80.0,
          height: 80.0,
          point: LatLng(51.229678 - i * 0.00006, 4.418661),
          builder: (ctx) => const Icon(Icons.location_on),
        ));
      }
      if (i < 12) {
        _markers.add(Marker(
          width: 80.0,
          height: 80.0,
          point: LatLng(51.229686 - i * 0.00006, 4.417269),
          builder: (ctx) => const Icon(Icons.location_on),
        ));
      }
    }
  }

  Set<Marker> _markers = {};
  LatLng _markerLocation = LatLng(0, 0);
  Widget build(BuildContext context) {
    return FutureBuilder<LocationData?>(
        future: _currentLocation(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _markerLocation =
                LatLng(snapshot.data!.latitude!, snapshot.data!.longitude!);
            return Scaffold(
              appBar: AppBar(
                title: const Text("ParkU"),
              ),
              body: Center(
                child: Stack(
                  children: <Widget>[
                    FlutterMap(
                      options: MapOptions(
                        onPointerUp: (event, latlng) {
                          //move the marker to the new location
                          _markerLocation = latlng;
                          Marker newMarker = Marker(
                            width: 80.0,
                            height: 80.0,
                            point: _markerLocation,
                            builder: (ctx) => const Icon(Icons.location_on),
                          );
                          setState(() {
                            _markerLocation = latlng;
                            _markers.add(newMarker);
                          });
                          print(latlng);
                        },
                        center: LatLng(51.229263, 4.417997),
                        zoom: 18,
                        maxZoom: 18.4,
                        minZoom: 17.8,
                        /*LatLng(latitude:51.230702, longitude:4.415594)
js_primitives.dart:30 LatLng(latitude:51.228128, longitude:4.420529)*/
                        maxBounds: LatLngBounds(LatLng(51.230702, 4.415594),
                            LatLng(51.228128, 4.420529)),
                      ),
                      nonRotatedChildren: [
                        AttributionWidget.defaultWidget(
                          source: 'OpenStreetMap contributors',
                          onSourceTapped: null,
                        ),
                      ],
                      children: <Widget>[
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.app',
                        ),
                        MarkerClusterLayerWidget(
                            options: MarkerClusterLayerOptions(
                          maxClusterRadius: 10,
                          size: const Size(40, 40),
                          fitBoundsOptions: const FitBoundsOptions(
                            padding: EdgeInsets.all(50),
                          ),
                          markers: _markers.toList(),
                          polygonOptions: PolygonOptions(
                            borderColor: Colors.blueAccent,
                            color: Colors.blueAccent.withOpacity(0.3),
                            borderStrokeWidth: 3,
                          ),
                          builder: (context, markers) {
                            return FloatingActionButton(
                              onPressed: null,
                              child: Text(markers.length.toString()),
                            );
                          },
                        )),
                      ],
                    )
                  ],
                ),
              ),
              bottomNavigationBar: BottomAppBar(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.home),
                      onPressed: () {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                    ),
                    const Text("ParkU"),
                    IconButton(
                      icon: const Icon(Icons.person),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => LoginPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          } else {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
        });
  }
}
