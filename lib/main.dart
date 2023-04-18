import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart";
import "package:latlong2/latlong.dart";
import 'package:location/location.dart';
import 'package:syncfusion_flutter_maps/maps.dart';


void main() => runApp(MyApp());

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

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocationData?>(

        future: _currentLocation(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Scaffold(
              body: Center(
                child: Stack(
                  children: <Widget>[
                    FlutterMap(
                      options: MapOptions(
                        center: LatLng(snapshot.data!.latitude!, snapshot.data!.longitude!),
                        zoom: 18,
                      ),
                      nonRotatedChildren: [
                        AttributionWidget.defaultWidget(
                          source: 'OpenStreetMap contributors',
                          onSourceTapped: null,
                        ),
                      ],
                      children: <Widget> [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.app',
                        ),
                        MarkerClusterLayerWidget(options: MarkerClusterLayerOptions(
                          maxClusterRadius: 120,
                          size: const Size(40, 40),
                          fitBoundsOptions: const FitBoundsOptions(
                            padding: EdgeInsets.all(50),
                          ),
                          markers: [
                            Marker(
                              width: 80.0,
                              height: 80.0,
                              point: LatLng(snapshot.data!.latitude!, snapshot.data!.longitude!),
                              builder: (ctx) =>
                                  const Icon(Icons.location_on),
                            ),
                          ],
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
