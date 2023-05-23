import 'dart:async';

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
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
  List<Car> cars = [];
  final user = await st.getLoggedInUser();
  final carsSnapshot = await user.docs.first.reference.collection('cars').get();
  //for each document in the collection print the data
  carsSnapshot.docs.forEach((doc) {
    cars.add(Car(doc['merk'], doc['kleur'], doc.id, doc['type']));
  });
  return cars;
}

//get user id from firebase
Future<String> getUserId() async {
  final user = await st.getLoggedInUser();
  return user.docs.first.id;
}

DateTime? selectedTime;

addMarker(BuildContext context, LatLng latLng) {
  // Display a dialog to add a marker
  showDialog(
    context: context,
    builder: (BuildContext context) {
      String? selectedType;
      TextEditingController timeController = TextEditingController();
      Completer<void> completer = Completer<void>();

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return FutureBuilder<List<Car>>(
            future: getCars(),
            builder: (BuildContext context, AsyncSnapshot<List<Car>> snapshot) {
              if (snapshot.hasError || !snapshot.hasData) {
                // Show an error message if there was an error fetching the data
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
                              selectedType = newValue;
                            });
                          },
                          items: cars.map<DropdownMenuItem<String>>((Car car) {
                            return DropdownMenuItem<String>(
                              value: car.id,
                              child: Text('${car.merk} - ${car.kleur}'),
                            );
                          }).toList(),
                        ),
                        // Widget to select the time
                        TextFormField(
                          controller: timeController,
                          decoration: InputDecoration(
                            labelText: 'Selecteer de tijd',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.timer),
                              onPressed: () {
                                DatePicker.showTimePicker(
                                  context,
                                  showSecondsColumn: false,
                                  onConfirm: (time) {
                                    selectedTime = time;
                                    timeController.text = DateFormat.Hm().format(
                                        time); // Use DateFormat to format the time
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
                        // If dropdown is empty, show an error message
                        if (selectedType == null) {
                          // Show message
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Error'),
                                content: const Text('Selecteer een auto'),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('Ok'),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ],
                              );
                            },
                          );
                        } else if (selectedTime == null) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Error'),
                                content: const Text('Selecteer een tijd'),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('Ok'),
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
                            'reserved': '',
                          });
                          Navigator.of(context).pop();

                          completer.complete(); // Complete the Future
                        }
                      },
                    ),
                  ],
                );
              }
            },
          );
        },
      );
    },
  ).then((_) {
    // Refresh after returning from the dialog
    //Refresh with pushreplacement
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    ).then((_) => _HomeScreenState().getMarkers());
    // Call the necessary methods to refresh data if required
  });
}

//do the same as addMarker but for the marker that is already in the database

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    //connect to the firestore database and add a marker tot the map for each marker in the database
    getMarkers();
  }

  void getMarkers() {
    FirebaseFirestore.instance
        .collection('markers')
        .get()
        .then((QuerySnapshot querySnapshot) {
      if (!mounted) {
        return; // Check if the widget is still mounted before updating the state
      }
      final context = this.context;
      setState(() {
        _markers.clear();
        querySnapshot.docs.forEach((doc) {
          //if time is in the past set status to unavailable
          if (DateTime.parse(doc['time']).isBefore(DateTime.now())) {
            FirebaseFirestore.instance
                .collection('markers')
                .doc(doc.id)
                .update({
              'status': 'unavailable',
            });
          } else {
            _markers.add(
              Marker(
                width: 80.0,
                height: 80.0,
                point: LatLng(doc['lat'], doc['lng']),
                builder: (ctx) => GestureDetector(
                  onTap: () async {
                    //if the user is logged in
                    if (st.loggedInUser != null) {
                      if (doc['status'] == 'in_use' &&
                          doc['user'] != await getUserId()) {
                        showDialog(
                          context: this.context,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Card(
                                          child: ListTile(
                                            title: const Text('In gebruik tot'),
                                            subtitle: Text(
                                                doc['time'].substring(0, 16)),
                                          ),
                                        ),
                                        Card(
                                          child:
                                              FutureBuilder<DocumentSnapshot>(
                                            future: FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(doc['user'])
                                                .get(),
                                            builder: (BuildContext context,
                                                AsyncSnapshot<DocumentSnapshot>
                                                    userSnapshot) {
                                              if (userSnapshot
                                                      .connectionState ==
                                                  ConnectionState.waiting) {
                                                return const CircularProgressIndicator();
                                              } else if (userSnapshot.hasData) {
                                                String username = userSnapshot
                                                    .data!['username'];
                                                int thumbsUp = userSnapshot
                                                    .data!['thumbsUp'];
                                                int thumbsDown = userSnapshot
                                                    .data!['thumbsDown'];
                                                return ListTile(
                                                  title:
                                                      const Text('In gebruik door'),
                                                  subtitle: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(username),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.thumb_up),
                                                          Text(thumbsUp
                                                              .toString()),
                                                          const Text(" - "),
                                                          const Icon(
                                                              Icons.thumb_down),
                                                          Text(thumbsDown
                                                              .toString()),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              } else if (userSnapshot
                                                  .hasError) {
                                                return Text(
                                                    'Error: ${userSnapshot.error}');
                                              } else {
                                                return const Text('User not found');
                                              }
                                            },
                                          ),
                                        ),
                                        Card(
                                          child: ListTile(
                                            title: const Text('Merk auto'),
                                            subtitle:
                                                Text("${car.merk} ${car.type}"),
                                          ),
                                        ),
                                        Card(
                                          child: ListTile(
                                            title: const Text('Kleur auto'),
                                            subtitle: Text(car.kleur),
                                          ),
                                        ),
                                        //add button to reserve the marker and center the button

                                        Center(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text('Reserveren'),
                                                    content: const Text(
                                                        'Weet u zeker dat u deze parkeerplaats wilt reserveren?'),
                                                    actions: <Widget>[
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop();
                                                        },
                                                        child:
                                                            const Text('Nee'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () async {
                                                          //if logedin user is null show a dialog that they need to login
                                                          if (loggedInUser ==
                                                              '') {
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                            showDialog(
                                                              context: context,
                                                              builder:
                                                                  (BuildContext
                                                                      context) {
                                                                return AlertDialog(
                                                                  title: const Text(
                                                                      'Error'),
                                                                  content: const Text(
                                                                      'Log in voor je een parkeerplaats kan reserveren'),
                                                                  actions: <
                                                                      Widget>[
                                                                    TextButton(
                                                                      child: const Text(
                                                                          'Ok'),
                                                                      onPressed:
                                                                          () =>
                                                                              Navigator.of(context).pop(),
                                                                    ),
                                                                  ],
                                                                );
                                                              },
                                                            );
                                                          } else {
                                                            // Update the marker in the database
                                                            FirebaseFirestore
                                                                .instance
                                                                .collection(
                                                                    'markers')
                                                                .doc(doc.id)
                                                                .update({
                                                              'status':
                                                                  'reserved',
                                                              'reserved':
                                                                  await getUserId(),
                                                            });
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                          }
                                                          if (!mounted) {
                                                            return; // Check if the widget is still mounted before updating the state
                                                          }
                                                          if (mounted) {
                                                            // Check if the widget is still mounted before updating the state
                                                            // Reload the page
                                                            //wait 2 seconds to make sure the database is updated
                                                            Future.delayed(
                                                                const Duration(
                                                                    seconds: 2),
                                                                () {
                                                              setState(() {
                                                                getMarkers();
                                                              });
                                                              // Any other necessary refresh logic
                                                            });
                                                          }
                                                        },
                                                        child: const Text('Ja'),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                            child: const Text('Reserveer'),
                                          ),
                                        ),
                                      ],
                                    );
                                  } else if (snapshot.hasError) {
                                    return Text('Error: ${snapshot.error}');
                                  } else {
                                    return const LinearProgressIndicator();
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
                      } else if (doc['status'] == 'in_use' &&
                          doc['user'] == await getUserId()) {
                        showDialog(
                          context: this.context,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Card(
                                          child: ListTile(
                                            title: const Text('In gebruik tot'),
                                            subtitle: Text(
                                                doc['time'].substring(0, 16)),
                                          ),
                                        ),
                                        Card(
                                          child:
                                              FutureBuilder<DocumentSnapshot>(
                                            future: FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(doc['user'])
                                                .get(),
                                            builder: (BuildContext context,
                                                AsyncSnapshot<DocumentSnapshot>
                                                    userSnapshot) {
                                              if (userSnapshot
                                                      .connectionState ==
                                                  ConnectionState.waiting) {
                                                return const CircularProgressIndicator();
                                              } else if (userSnapshot.hasData) {
                                                String username = userSnapshot
                                                    .data!['username'];
                                                int thumbsUp = userSnapshot
                                                    .data!['thumbsUp'];
                                                int thumbsDown = userSnapshot
                                                    .data!['thumbsDown'];
                                                return ListTile(
                                                  title:
                                                      const Text('In gebruik door'),
                                                  subtitle: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(username),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.thumb_up),
                                                          Text(thumbsUp
                                                              .toString()),
                                                          const Text(" - "),
                                                          const Icon(
                                                              Icons.thumb_down),
                                                          Text(thumbsDown
                                                              .toString()),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              } else if (userSnapshot
                                                  .hasError) {
                                                return Text(
                                                    'Error: ${userSnapshot.error}');
                                              } else {
                                                return const Text('User not found');
                                              }
                                            },
                                          ),
                                        ),
                                        Card(
                                          child: ListTile(
                                            title: const Text('Merk auto'),
                                            subtitle:
                                                Text("${car.merk} ${car.type}"),
                                          ),
                                        ),
                                        Card(
                                          child: ListTile(
                                            title: const Text('Kleur auto'),
                                            subtitle: Text(car.kleur),
                                          ),
                                        ),
                                        //add button to reserve the marker and center the button

                                        Center(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              TextEditingController
                                                  timeController =
                                                  TextEditingController();
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title:
                                                        const Text('Tijd verlengen'),
                                                    content: const Text(
                                                        'Tot hoe laat wilt u de parkeerplaats verlengen?'),
                                                    actions: <Widget>[
                                                      TextFormField(
                                                        controller:
                                                            timeController,
                                                        decoration:
                                                            InputDecoration(
                                                          labelText:
                                                              'Selecteer de tijd',
                                                          suffixIcon:
                                                              IconButton(
                                                            icon: const Icon(
                                                                Icons.timer),
                                                            onPressed: () {
                                                              DatePicker
                                                                  .showTimePicker(
                                                                context,
                                                                showSecondsColumn:
                                                                    false,
                                                                onConfirm:
                                                                    (time) {
                                                                  selectedTime =
                                                                      time;
                                                                  timeController
                                                                      .text = DateFormat
                                                                          .Hm()
                                                                      .format(
                                                                          time); // Use DateFormat to format the time
                                                                },
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                      Row(children: [
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                          },
                                                          child: const Text(
                                                              'annuleren'),
                                                        ),
                                                        //time picker

                                                        TextButton(
                                                          onPressed: () async {
                                                            //if logedin user is null show a dialog that they need to login

                                                            // Update the marker in the database
                                                            FirebaseFirestore
                                                                .instance
                                                                .collection(
                                                                    'markers')
                                                                .doc(doc.id)
                                                                .update({
                                                              'time': selectedTime
                                                                  .toString(),
                                                            });
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                            Navigator.of(
                                                                    context)
                                                                .pop();

                                                            if (!mounted) {
                                                              return; // Check if the widget is still mounted before updating the state
                                                            }
                                                            if (mounted) {
                                                              // Check if the widget is still mounted before updating the state
                                                              // Reload the page
                                                              //wait 2 seconds to make sure the database is updated
                                                              Future.delayed(
                                                                  const Duration(
                                                                      seconds:
                                                                          2),
                                                                  () {
                                                                setState(() {
                                                                  getMarkers();
                                                                });
                                                                // Any other necessary refresh logic
                                                              });
                                                            }
                                                          },
                                                          child:
                                                              const Text('Ja'),
                                                        )
                                                      ]),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                            child: const Text('tijd verlengen'),
                                          ),
                                        ),
                                      ],
                                    );
                                  } else if (snapshot.hasError) {
                                    return Text('Error: ${snapshot.error}');
                                  } else {
                                    return const LinearProgressIndicator();
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
                      } else if (doc['reserved'] == await getUserId()) {
                        showDialog(
                          context: this.context,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Card(
                                          child: ListTile(
                                            title: const Text('In gebruik tot'),
                                            subtitle: Text(
                                                doc['time'].substring(0, 16)),
                                          ),
                                        ),
                                        Card(
                                          child:
                                              FutureBuilder<DocumentSnapshot>(
                                            future: FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(doc['user'])
                                                .get(),
                                            builder: (BuildContext context,
                                                AsyncSnapshot<DocumentSnapshot>
                                                    userSnapshot) {
                                              if (userSnapshot
                                                      .connectionState ==
                                                  ConnectionState.waiting) {
                                                return const CircularProgressIndicator();
                                              } else if (userSnapshot.hasData) {
                                                String username = userSnapshot
                                                    .data!['username'];
                                                int thumbsUp = userSnapshot
                                                    .data!['thumbsUp'];
                                                int thumbsDown = userSnapshot
                                                    .data!['thumbsDown'];
                                                return ListTile(
                                                  title:
                                                      const Text('In gebruik door'),
                                                  subtitle: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(username),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.thumb_up),
                                                          Text(thumbsUp
                                                              .toString()),
                                                          const Text(" - "),
                                                          const Icon(
                                                              Icons.thumb_down),
                                                          Text(thumbsDown
                                                              .toString()),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              } else if (userSnapshot
                                                  .hasError) {
                                                return Text(
                                                    'Error: ${userSnapshot.error}');
                                              } else {
                                                return const Text('User not found');
                                              }
                                            },
                                          ),
                                        ),
                                        Card(
                                          child: ListTile(
                                            title: const Text('Merk auto'),
                                            subtitle:
                                                Text("${car.merk} ${car.type}"),
                                          ),
                                        ),
                                        Card(
                                          child: ListTile(
                                            title: const Text('Kleur auto'),
                                            subtitle: Text(car.kleur),
                                          ),
                                        ),
                                        //add button to cancel the reservation and center the button
                                        Center(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text(
                                                        'cancel reservation'),
                                                    content: const Text(
                                                        'Weet u zeker dat u deze reservatie wilt cancelen?'),
                                                    actions: <Widget>[
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop();
                                                        },
                                                        child:
                                                            const Text('Nee'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () async {
                                                          //if logedin user is null show a dialog that they need to login

                                                          // Update the marker in the database
                                                          FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                  'markers')
                                                              .doc(doc.id)
                                                              .update({
                                                            'status': 'in_use',
                                                            'reserved': '',
                                                          });
                                                          Navigator.of(context)
                                                              .pop();
                                                          Navigator.of(context)
                                                              .pop();

                                                          if (!mounted) {
                                                            return; // Check if the widget is still mounted before updating the state
                                                          }
                                                          if (mounted) {
                                                            // Check if the widget is still mounted before updating the state
                                                            // Reload the page
                                                            //wait 2 seconds to make sure the database is updated
                                                            Future.delayed(
                                                                const Duration(
                                                                    seconds: 2),
                                                                () {
                                                              setState(() {
                                                                getMarkers();
                                                              });
                                                              // Any other necessary refresh logic
                                                            });
                                                          }
                                                        },
                                                        child: const Text('Ja'),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                            child:
                                                const Text('Reserveering cancelen'),
                                          ),
                                        ),
                                      ],
                                    );
                                  } else if (snapshot.hasError) {
                                    return Text('Error: ${snapshot.error}');
                                  } else {
                                    return const LinearProgressIndicator();
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
                        //tell user the parking is reserved
                        showDialog(
                          context: this.context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Parkeerplaats'),
                              content: const Text(
                                  'Deze parkeerplaats is al gereserveerd'),
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
                      }
                    } else {
                      //tell user to login first
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Parkeerplaats'),
                            content: const Text(
                                'Log in voor je een parkeerplaats kan selecteren'),
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
                    }
                  },
                  child: Icon(
                    doc['status'] == 'reserved'
                        ? Icons.location_on
                        : doc['status'] == 'in_use'
                            ? Icons.location_on
                            : Icons.location_off,
                    color: doc['status'] == 'in_use'
                        ? Colors.blue
                        : doc['status'] == 'reserved'
                            ? Colors.red
                            : doc['status'] == 'reserved'
                                ? Colors.red
                                : Colors.grey,
                  ),
                ),
              ),
            );
          }
        });
      });
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

  final Set<Marker> _markers = {};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocationData?>(
        future: _currentLocation(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
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
                        child: const Icon(Icons.add),
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
                                builder: (context) => const ProfilePage()),
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
