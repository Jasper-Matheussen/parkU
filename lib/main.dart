import 'package:cloud_firestore/cloud_firestore.dart';
import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart";
import "package:latlong2/latlong.dart";
import 'package:location/location.dart';
import 'package:parku/car.dart';
import 'package:parku/profilePage.dart';
import 'loginPage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';
import 'storage.dart';
import 'storage.dart' as st;

//make an enum for the status of the marker

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

Future<List<Car>> getCars() async {
  List<Car> _cars = [];
  final user = await st.getLoggedInUser();
  final carsSnapshot = await user.docs.first.reference.collection('cars').get();
  //for each document in the collection print the data
  carsSnapshot.docs.forEach((doc) {
    _cars.add(Car(doc['merk'], doc['kleur'], doc.id));
  });
  return _cars;
}

addMarker(BuildContext context) {
  //display a dialog to add a marker
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return FutureBuilder<List<Car>>(
        future: getCars(),
        builder: (BuildContext context, AsyncSnapshot<List<Car>> snapshot) {
          if (snapshot.hasError || !snapshot.hasData) {
            // show an error message if there was an error fetching the data
            print(snapshot.error);
            return AlertDialog(
              title: Text('Error'),
              content: Text('Failed to load cars'),
              actions: <Widget>[
                TextButton(
                  child: Text('Ok'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          } else if (snapshot.data!.isEmpty) {
            return AlertDialog(
              title: Text('Error'),
              content: Text('You have no cars'),
              actions: <Widget>[
                TextButton(
                  child: Text('Ok'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          } else {
            final List<Car> cars = snapshot.data ?? [];
            String ?selectedType;
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return AlertDialog(
                  title: const Text('Parkeer plaats toevoegen'),
                  content: SingleChildScrollView(
                    child: ListBody(
                      children: <Widget>[
                        DropdownButton<String>(
                          key: UniqueKey(),
                          hint: const Text('Selecteer een auto'),
                          value: selectedType,
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedType = newValue!;
                            });
                          },

                          items: cars.map<DropdownMenuItem<String>>((Car car) {
                            return DropdownMenuItem<String>(
                              value: car.id,
                              child: Text(car.merk),
                            );
                          }).toList(),
                        ),

                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Annuleren'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    TextButton(
                      child: const Text('Toevoegen'),
                      onPressed: () {
                        //add the marker to the database

                        FirebaseFirestore.instance
                            .collection('markers')
                            .doc('marker100')
                            .set({
                          'status': 'free',
                          'lat': 3,
                          'lng': 3,
                          'car': selectedType,
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          }
        },
      );
    },
  );
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
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      //connect to the fire base database and add markers to the database in latlng format if there are no markers
      firestore.collection('markers').doc('marker$i').set({
        'status': 'free',
        'lat': 51.229749,
        'lng': 4.41736 + i * 0.00007,
        'type': '',
        'color': '',
      });
      if (i == 3 || i == 4 || i == 6 || i == 7) {
        firestore.collection('markers').doc('marker$i').set({
          'status': 'in_use',
          'lat': 51.229749,
          'lng': 4.41736 + i * 0.00007,
          'type': 'BMW',
          'color': 'rood',
        });
      }
    }

    //connect to the firestore database and add a marker tot the map for each marker in the database
    FirebaseFirestore.instance
        .collection('markers')
        .get()
        .then((QuerySnapshot querySnapshot) => {
              querySnapshot.docs.forEach((doc) {
                _markers.add(Marker(
                  width: 80.0,
                  height: 80.0,
                  point: LatLng(doc['lat'], doc['lng']),
                  builder: (ctx) => GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Parkeer plaats'),
                            content:
                                //show the status of the marker, type of car, color of car
                                Text('Status: ' +
                                    doc['status'] +
                                    '\n' +
                                    'Merk auto: ' +
                                    doc['type'] +
                                    '\n' +
                                    'kleur auto: ' +
                                    doc['color']),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Sluiten'),
                              )
                            ],
                          );
                        },
                      );
                    },
                    child: Icon(
                      doc['status'] == 'free'
                          ? Icons.location_on
                          : doc['status'] == 'in_use'
                              ? Icons.location_on
                              : Icons.location_off,
                      color: doc['status'] == 'free'
                          ? Colors.green
                          : doc['status'] == 'in_use'
                              ? Colors.red
                              : Colors.grey,
                    ),
                  ),
                ));
              })
            });
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
                    ),
                    //add a + icon in the bottom right corner to add a marker
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: FloatingActionButton(
                        onPressed: () => addMarker(context),
                        tooltip: 'Voeg een nieuwe marker toe',
                        child: Icon(Icons.add),
                      ),
                    ),
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
                        if (loggedInUser != null) {
                          // User is logged in, navigate to profile page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ProfilePage()),
                          );
                        } else {
                          // User is not logged in, navigate to login page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => LoginPage()),
                          );
                        }
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
