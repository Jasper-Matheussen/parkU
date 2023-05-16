import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import "package:flutter/material.dart";
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import "package:flutter_map/flutter_map.dart";
import "package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart";
import 'package:intl/intl.dart'; //for date formatting
import "package:latlong2/latlong.dart";
import 'package:location/location.dart';
import 'package:parku/car.dart';
import 'package:parku/profilePage.dart';

import 'firebase_options.dart';
import 'loginPage.dart';
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

  Location location = Location();

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

Car? selectedCar;

Future<List<Car>> getCars() async {
  List<Car> _cars = [];
  final user = await st.getLoggedInUser();
  final carsSnapshot = await user.docs.first.reference.collection('cars').get();
  //for each document in the collection print the data
  carsSnapshot.docs.forEach((doc) {
    _cars.add(Car(doc['merk'], doc['kleur'], doc.id, doc['type']));
  });
  return _cars;
}

//get user id from firebase
Future<String> getUserId() async {
  final user = await st.getLoggedInUser();
  return user.docs.first.id;
}

DateTime? selectedTime;

addMarker(BuildContext context, LatLng latLng) {
  //display a dialog to add a marker
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return FutureBuilder<List<Car>>(
        future: getCars(),
        builder: (BuildContext context, AsyncSnapshot<List<Car>> snapshot) {
          if (snapshot.hasError || !snapshot.hasData) {
            // show an error message if there was an error fetching the data
            return AlertDialog(
              title: const Text('Error'),
              content: const Text('Er is iets mis gegaan'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Ok'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          } else if (snapshot.data!.isEmpty) {
            if (loggedInUser == null) {
              return AlertDialog(
                title: const Text('Error'),
                content: const Text(
                    'Log in voor je een parkeerplaats kan toevoegen'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Ok'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              );
            }
            return AlertDialog(
              title: const Text('Error'),
              content: const Text('Voeg eerst een auto toe'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Ok'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          } else {
            final List<Car> cars = snapshot.data ?? [];
            String? selectedType;

            TextEditingController timeController = TextEditingController();
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
                              child: Text(car.merk + ' - ' + car.kleur),
                            );
                          }).toList(),
                        ),
                        //widget to slect the time
                        TextFormField(
                          controller: timeController,
                          decoration: InputDecoration(
                            labelText: 'Selecteer de tijd',
                            suffixIcon: IconButton(
                              icon: Icon(Icons.timer),
                              onPressed: () {
                                DatePicker.showTimePicker(
                                  context,
                                  showSecondsColumn: false,
                                  onConfirm: (time) {
                                    selectedTime = time;
                                    timeController.text = DateFormat.Hm().format(
                                        time); // use DateFormat to format the time
                                  },
                                );
                              },
                            ),
                          ),
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
                      onPressed: () async {
                        //if dropdown is empty show an error message
                        if (selectedType == null) {
                          //show message
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Error'),
                                content: Text('Selecteer een auto'),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text('Ok'),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ],
                              );
                            },
                          );
                        } else {
                          String userid = await getUserId();
                          FirebaseFirestore.instance.collection('markers').add({
                            'status': 'in_use',
                            'lat': latLng.latitude,
                            'lng': latLng.longitude,
                            'car': selectedType,
                            'user': userid,
                            'time': selectedTime.toString(),
                          });

                          Navigator.of(context).pop();
                          //reload the page
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (BuildContext context) => HomeScreen(),
                            ),
                          );
                        }
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

//do the same as addMarker but for the marker that is already in the database
updateMarker(BuildContext context, String marker) {
  //display a dialog to add a marker
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return FutureBuilder<List<Car>>(
        future: getCars(),
        builder: (BuildContext context, AsyncSnapshot<List<Car>> snapshot) {
          if (snapshot.hasError || !snapshot.hasData) {
            // show an error message if there was an error fetching the data
            return AlertDialog(
              title: const Text('Error'),
              content: const Text('Er is iets mis gegaan'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Ok'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          } else if (snapshot.data!.isEmpty) {
            if (loggedInUser == null) {
              return AlertDialog(
                title: const Text('Error'),
                content: const Text(
                    'Log in voor je een parkeerplaats kan toevoegen'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Ok'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              );
            }
            return AlertDialog(
              title: const Text('Error'),
              content: const Text('Voeg eerst een auto toe'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Ok'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          } else {
            final List<Car> cars = snapshot.data ?? [];
            String? selectedType;

            TextEditingController timeController = TextEditingController();
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
                              child: Text(car.merk + ' - ' + car.kleur),
                            );
                          }).toList(),
                        ),
                        //widget to slect the time
                        TextFormField(
                          controller: timeController,
                          decoration: InputDecoration(
                            labelText: 'Selecteer de tijd',
                            suffixIcon: IconButton(
                              icon: Icon(Icons.timer),
                              onPressed: () {
                                DatePicker.showTimePicker(
                                  context,
                                  showSecondsColumn: false,
                                  onConfirm: (time) {
                                    selectedTime = time;
                                    timeController.text = DateFormat.Hm().format(
                                        time); // use DateFormat to format the time
                                  },
                                );
                              },
                            ),
                          ),
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
                      onPressed: () async {
                        //if dropdown is empty show an error message
                        if (selectedType == null) {
                          //show message
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Error'),
                                content: Text('Selecteer een auto'),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text('Ok'),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ],
                              );
                            },
                          );
                        } else {
                          String userid = await getUserId();
                          //get marker from database
                          DocumentSnapshot doc = await FirebaseFirestore
                              .instance
                              .collection('markers')
                              .doc(marker)
                              .get();
                          //update the marker in the database
                          FirebaseFirestore.instance
                              .collection('markers')
                              .doc(marker)
                              .update({
                            'status': 'in_use',
                            'lat': doc['lat'],
                            'lng': doc['lng'],
                            'car': selectedType,
                            'user': userid,
                            'time': selectedTime.toString(),
                          });

                          Navigator.of(context).pop();
                          //reload the page
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (BuildContext context) => HomeScreen(),
                            ),
                          );
                        }
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
    //connect to the firestore database and add a marker tot the map for each marker in the database
    FirebaseFirestore.instance.collection('markers').get().then((QuerySnapshot
            querySnapshot) =>
        {
          querySnapshot.docs.forEach((doc) {
            _markers.add(Marker(
              width: 80.0,
              height: 80.0,
              point: LatLng(doc['lat'], doc['lng']),
              builder: (ctx) => GestureDetector(
                onTap: () {
                  // if the time is before the time the marker is reserved till
                  if (DateTime.now()
                      .isBefore(DateTime.parse(doc['time']).toLocal())) {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Parkeerplaats'),
                          content: FutureBuilder<Car>(
                            future: getCar(doc),
                            builder: (BuildContext context,
                                AsyncSnapshot<Car> snapshot) {
                              if (snapshot.hasData) {
                                Car car = snapshot.data!;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Card(
                                      child: ListTile(
                                        title: Text('Gereserveerd tot'),
                                        subtitle:
                                            Text(doc['time'].substring(0, 16)),
                                      ),
                                    ),
                                    Card(
                                      child: FutureBuilder<DocumentSnapshot>(
                                        future: FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(doc['user'])
                                            .get(),
                                        builder: (BuildContext context,
                                            AsyncSnapshot<DocumentSnapshot>
                                                userSnapshot) {
                                          if (userSnapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return CircularProgressIndicator();
                                          } else if (userSnapshot.hasData) {
                                            String username =
                                                userSnapshot.data!['username'];
                                            return ListTile(
                                              title: Text('Gereserveerd door'),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(username),
                                                  const Text('Rating: 4.5/5'),
                                                ],
                                              ),
                                            );
                                          } else if (userSnapshot.hasError) {
                                            return Text(
                                                'Error: ${userSnapshot.error}');
                                          } else {
                                            return Text('User not found');
                                          }
                                        },
                                      ),
                                    ),
                                    Card(
                                      child: ListTile(
                                        title: Text('Merk auto'),
                                        subtitle:
                                            Text("${car.merk} ${car.type}"),
                                      ),
                                    ),
                                    Card(
                                      child: ListTile(
                                        title: Text('Kleur auto'),
                                        subtitle: Text(car.kleur),
                                      ),
                                    ),
                                  ],
                                );
                              } else if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}');
                              } else {
                                return LinearProgressIndicator();
                              }
                            },
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('Sluiten'),
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    doc.reference.update({'status': 'free'});
                    //show a dialog that the marker is free and that you can reserve it so in the title you have to put the time the marker is free than you have a buton to reserve it
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Parkeerplaats'),
                          content: Text(
                              'Deze parkeerplaats is vrij, wil je deze reserveren?'),
                          actions: <Widget>[
                            TextButton(
                              child: Text('Annuleren'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            TextButton(
                              child: Text('Reserveren'),
                              onPressed: () {
                                Navigator.of(context).pop();
                                updateMarker(context, doc.id);
                              },
                            ),
                          ],
                        );
                      },
                    );
                  }
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

  Future<Car> getCar(QueryDocumentSnapshot<Object?> doc) async {
    DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(doc['user'])
        .collection('cars')
        .doc(doc['car'])
        .get();

    if (documentSnapshot.exists) {
      String merk = documentSnapshot['merk'];
      String kleur = documentSnapshot['kleur'];
      String type = documentSnapshot['type'];
      String id = documentSnapshot.id;
      return Car(merk, kleur, id, type);
    } else {
      throw Exception('Car not found');
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
                        onLongPress: (event, latlng) {
                          addMarker(context, latlng);
                        },
                        center: LatLng(51.229263, 4.417997),
                        zoom: 18,
                        maxZoom: 18.4,
                        minZoom: 17.8,
                        maxBounds: LatLngBounds(LatLng(51.230061, 4.416823),
                            LatLng(51.228677, 4.419216)),
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
                        //onpressed show info dialog that they need to longpress to add a marker
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Marker toevoegen'),
                                content: const Text(
                                    'Houdt de kaart ingedrukt om een marker toe te voegen'),
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
