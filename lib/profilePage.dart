import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'storage.dart' as st;
import 'car.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final String _username = st.loggedInUser ?? "Gebruiker";
  List<Car> _cars = [];
  Future<List<Car>>? _carsFuture;

  @override
  void initState() {
    super.initState();
    _carsFuture = getCars();
  }

  Future<List<Car>> getCars() async {
    final user = await st.getLoggedInUser();
    final carsSnapshot = await user.docs.first.reference.collection('cars').get();
    //for each document in the collection print the data
    carsSnapshot.docs.forEach((doc) {
      _cars.add(Car(doc['merk'], doc['kleur'], doc.id, doc['type']));
    });
    return _cars;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profiel Pagina'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              st.loggedInUser = null;
              Navigator.pop(context);
            },
          ),],

      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey[300]!,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                size: 70,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(height: 30),
          Text(
            _username,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 30),
          Text(
            "Jouw auto's",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: _carsFuture == null ? CircularProgressIndicator() : FutureBuilder<List<Car>>(
              future: _carsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  _cars = snapshot.data!;
                  return ListView.builder(
                    itemCount: _cars.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Card(
                        child: ListTile(
                          title: Text("${_cars[index].merk} - ${_cars[index].type}"),
                          subtitle: Text(_cars[index].kleur),
                          trailing: IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () {
                              // Show a confirmation dialog and delete the car if confirmed
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text("Verwijder auto"),
                                  content: Text("Weet je zeker dat je deze auto wilt verwijderen?"),
                                  actions: [
                                    TextButton(
                                      child: Text("Annuleren"),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                    TextButton(
                                      child: Text("Verwijderen"),
                                      onPressed: () {
                                        // Delete the car and update the list
                                        st.deleteCarForUser(_cars[index]);
                                        setState(() {
                                          _cars.removeAt(index);
                                        });
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );

                } else if (snapshot.hasError) {
                  return Text("Error: ${snapshot.error}");
                } else {
                  return CircularProgressIndicator();
                }
              },
            ),
          ),
          SizedBox(height: 10),
          Container(
            width: 200,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.lightBlueAccent],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.5),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                // Show the car form dialog
                showDialog(
                  context: context,
                  builder: (context) => CarFormDialog(),
                );
              },
              style: ElevatedButton.styleFrom(
                primary: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    'Auto toevoegen',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 50),
        ],
      ),
    );
  }
}

class CarFormDialog extends StatefulWidget {
  const CarFormDialog({Key? key}) : super(key: key);

  @override
  _CarFormDialogState createState() => _CarFormDialogState();
}

class _CarFormDialogState extends State<CarFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _merkController = TextEditingController();
  final _kleurController = TextEditingController();
  final _typeController = TextEditingController();

  @override
  void dispose() {
    _merkController.dispose();
    _kleurController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Auto toevoegen',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _merkController,
                decoration: InputDecoration(
                  labelText: 'Merk',
                  labelStyle: TextStyle(color: Colors.grey[800]),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Geef een merk in aub';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _kleurController,
                decoration: InputDecoration(
                  labelText: 'Kleur',
                  labelStyle: TextStyle(color: Colors.grey[800]),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Geef een kleur in';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _typeController,
                decoration: InputDecoration(
                  labelText: 'Type Auto',
                  labelStyle: TextStyle(color: Colors.grey[800]),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Geef een type in';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      primary: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Annuleren',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Add the car to the list
                        st.addCarForUser(_merkController.text, _kleurController.text, _typeController.text);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Auto toegevoegd')),
                        );
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      primary: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Toevoegen',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
