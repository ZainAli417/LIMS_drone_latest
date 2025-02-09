import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:location/location.dart' as gps; // Prefixed location
import 'package:geolocator/geolocator.dart' as geo; // For GPS updates
import 'package:path/path.dart';

import 'package:project_drone/Screens/Fetch_Input.dart';
import 'package:project_drone/Screens/LoginScreen.dart';
import 'package:project_drone/shared_state.dart';
import 'package:provider/provider.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../Constant/ISSAASProvider.dart';
import '../Constant/controller_weather.dart';
import 'coustom.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

class MyHomePage extends StatefulWidget {
  final String deviceId;
  const MyHomePage({super.key, required this.deviceId});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late GoogleMapController mapController;
  bool showMap = false;
  bool showPolls = false;
  LatLng userLocation = const LatLng(0, 0);
  final _location = Geolocator();
  double _latitude = 0.0;
  double _longitude = 0.0;

  void _getUserLocation() async {
    Position currentLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.bestForNavigation);
    setState(() {
      userLocation =
          LatLng(currentLocation.latitude, currentLocation.longitude);
      _latitude = currentLocation.latitude;
      _longitude = currentLocation.longitude;
      showPolls = true;
    });
    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(userLocation, 14.0),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _getUserLocation();
  }

  final WeatherController weatherController = Get.put(WeatherController());
  final videourl = "https://www.youtube.com/watch?v=WhAfZhFxHTs";
  //late YoutubePlayerController _controller;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String area = '0.00';
  String totalDistance = '0.00';
  String remainingDistance = '0.00';
  String duration = '0.00';
  String temperature = "10 C";
  String weatherDescription = "NA";
  String waterLevel = "80 %";
  String city = "N/A";
  String cityName = "N/A";
  List<Map<String, dynamic>> _devices = [];
  bool isManual = false; // Add this at the top of your widget
  Map<String, dynamic>? _farmerData;
  bool _isSolarOn = true;
  bool _groundMode = false;
  RxDouble moistureValue = 0.0.obs; // Now an RxDouble to store double values

  @override
  void initState() {
    super.initState();
    listenToMoisture();
    _getPositionAndWeather();
    _fetchData();
    getPosition();
    _fetchDevices();
    if (widget.deviceId.contains('UGV')) {
      setState(() {
        _groundMode = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload the images before rendering
  }

  Future<void> _fetchDevices() async {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final User? user = _auth.currentUser;

    // Ensure the user is logged in
    if (user != null) {
      try {
        // Fetch farmer's document from Firestore
        final DocumentSnapshot<Map<String, dynamic>> farmerDoc =
            await FirebaseFirestore.instance
                .collection('Farmer')
                .doc(user.uid) // Use user.uid to fetch the document
                .get();

        // Check if document exists
        if (farmerDoc.exists && farmerDoc.data() != null) {
          setState(() {
            _farmerData = farmerDoc.data(); // Store farmer's data
            _devices = List<Map<String, dynamic>>.from(
                _farmerData?['Purchased_Devices'] ?? []);
          });
        }
      } catch (e) {
        print('Error fetching devices: $e');
      }
    } else {
      print('No user is currently logged in.');
    }
  }

  Future<void> _getPositionAndWeather() async {
    try {
      Position position = await getPosition();
      await weatherController.fetchWeatherData(
          position.latitude, position.longitude);
    } catch (e) {
      print('Error fetching location or weather data: $e');
    }
  }

  Future<Position> getPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Stream<String> getHumidityStream() {
    DatabaseReference ref =
        FirebaseDatabase.instance.ref('sensor_data/soil_moisture');
    return ref.onValue.map((event) {
      return event.snapshot.value.toString(); // Convert value to String
    });
  }

  void listenToMoisture() {
    getHumidityStream().listen((moisture) {
      // Convert string to double
      double moistureDouble =
          double.tryParse(moisture) ?? 0.0; // Fallback to 0.0 if parsing fails
      moistureValue.value = moistureDouble; // Assign to moistureValue as double
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          backgroundColor: Colors.indigo[800],
          toolbarHeight: 160, // Custom height for the AppBar
          flexibleSpace: Padding(
            padding: const EdgeInsets.fromLTRB(
                10, 50, 10, 0), // Padding to control spacing
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // First Row: Logo, Title, Notification Icon, Three Dots Icon
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white, // Set the background color to white
                    borderRadius: BorderRadius.circular(
                        15), // Make the background rounded (capsule effect)
                    boxShadow: const [
                      BoxShadow(
                        color:
                            Colors.black12, // Optional shadow for better look
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              Colors.white, // Set the background color to white
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(1),
                          child: ClipOval(
                            child: Image.asset(
                              'images/logo.png',
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "LIMS",
                            style: TextStyle(
                              color: Colors
                                  .black, // Changed text color to black to be visible on white background
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                          ),
                          Text(
                            " Robo",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 24,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Sign out',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                              const SizedBox(
                                  width:
                                      2), // Reduced spacing between icon and text

                              IconButton(
                                icon: const Icon(
                                  Icons.logout_outlined,
                                  color: Colors.black,
                                  size: 25,
                                ),
                                onPressed: () async {
                                  context.read<ISSAASProvider>().setIsSaas(
                                      false); // Set ISSAAS state to true

                                  try {
                                    await FirebaseAuth.instance.signOut();
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              LoginScreen()), // Adjust the navigation to your Login page
                                    );
                                  } catch (e) {
                                    // Handle any errors that may occur during sign out
                                    print('Error signing out: $e');
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                // Second Row: UGV Connected Widget, Rawalpindi Text, Location Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Weather Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 5, 15, 5),
                      child: Obx(() {
                        return Row(
                          children: [
                            Text(
                              weatherController.weather.value.cityname.isEmpty
                                  ? "Loading..."
                                  : weatherController.weather.value.cityname,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.location_on_outlined,
                                color: Colors.white),
                            const SizedBox(width: 10),
                          ],
                        );
                      }),
                    ),

                    _devices.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(10, 5, 15, 5),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(5, 1, 0, 0),
                              width: 170,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.indigo[800],
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(5)),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors
                                      .white, // Set the background color to white
                                  borderRadius: BorderRadius.circular(
                                      10), // Rounded corners
                                ),
                                child: Row(
                                  children: [
                                    widget.deviceId.contains('UAV')
                                        ? const CustomUAVIcon() // Load CustomUAVIcon if device ID contains 'uav' (case-insensitive)
                                        : const CustomUGVIcon(), // Load CustomUGVIcon otherwise
                                    const SizedBox(width: 1),
                                    Center(
                                      child: Text(
                                        "${widget.deviceId} Connected ",
                                        style: TextStyle(
                                          color: Colors.indigo[
                                              800], // Text color set to indigo
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          fontFamily:
                                              GoogleFonts.poppins().fontFamily,
                                        ),
                                      ),
                                    ),
                                    const GreenBlinkingDot(), // Custom green blinking dot
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(10, 5, 15, 5),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(5, 1, 0, 0),
                              width: 145,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.indigo[800],
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(5)),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors
                                      .white, // Set the background color to white
                                  borderRadius: BorderRadius.circular(
                                      10), // Rounded corners
                                ),
                                child: Row(
                                  children: [
                                    Image.asset(
                                      'images/mobile.png', // Path to your mobile image
                                      height: 30,
                                      width: 30,
                                    ),
                                    const SizedBox(width: 8),
                                    Center(
                                      child: Text(
                                        "SaaS Version",
                                        style: TextStyle(
                                          color: Colors.indigo[
                                              800], // Text color set to indigo
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          fontFamily:
                                              GoogleFonts.poppins().fontFamily,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ), // Return an empty widget if not purchased
                  ],
                ),
              ],
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(3, 10, 1, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 5),
                  height: context.watch<ISSAASProvider>().isSaas ? 795 : 500,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                  child: Column(
                    // Enclose everything in a Column

                    children: [
                      Row(
                        // First Row

                        children: [
                          SvgPicture.asset(
                            'images/sunny.svg', // Path to your SVG file
                            height: 20, // Optional: Set the height as needed
                            width: 20, // Optional: Set the width as needed
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            "Weather Stats",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15), // Spacing between rows

                      Row(
                        // Second Row (Warning message)

                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          const Icon(Icons.warning,
                              color: Colors.red, size: 20),
                          Expanded(
                            child: Text(
                              "Don't Drive UGV when wind speed is above 50Mph",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15), // Spacing between rows

                      /*  SizedBox(
                        height: 125, // Set the custom height here
                        child: GridView.count(
                          shrinkWrap: true, // Add this property
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1,
                          children: [
                            Obx(() {
                              return WeatherCard(
                                iconPath: 'images/windspeed.png', // Path to your custom icon
                                label: 'Wind Speed',
                                value: '${weatherController.weather.value.windspeed.toStringAsFixed(1)} m/s',
                                cardColor: Colors.teal,
                                textColor: Colors.white,
                                iconColor: Colors.white, // Set icon color to white
                              );
                            }),
                            StreamBuilder<String>(
                              stream: getHumidityStream(), // Fetch humidity from Firebase
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return WeatherCard(
                                    iconPath: 'images/humidity.png', // Path to your custom icon
                                    label: 'Moisture',
                                    value: 'N/A',
                                    cardColor: Colors.blue,
                                    textColor: Colors.white,
                                    iconColor: Colors.white, // Set icon color to white
                                  );
                                }
                                if (snapshot.hasError) {
                                  return WeatherCard(
                                    iconPath: 'images/humidity.png', // Path to your custom icon
                                    label: 'Water Level',
                                    value: 'Error',
                                    cardColor: Colors.red,
                                    textColor: Colors.white,
                                    iconColor: Colors.white, // Set icon color to white
                                  );
                                }
                                return WeatherCard(
                                  iconPath: 'images/humidity.png', // Path to your custom icon
                                  label: 'Water Level',
                                  value: '${snapshot.data}%', // Display the humidity value
                                  cardColor: Colors.blue,
                                  textColor: Colors.white,
                                  iconColor: Colors.white, // Set icon color to white
                                );
                              },
                            ),
                            Obx(() {
                              return WeatherCard(
                                iconPath: 'images/temp.png', // Path to your custom icon
                                label: 'Temperature',
                                value: '${weatherController.weather.value.temp.toStringAsFixed(1)} C',
                                cardColor: Colors.purple,
                                textColor: Colors.white,
                                iconColor: Colors.white, // Set icon color to white
                              );
                            }),
                          ],
                        ),
                      ),*/
                      SizedBox(
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedSwitcher(
                                duration: const Duration(seconds: 5),
                                child: GoogleMap(
                                  onMapCreated: _onMapCreated,
                                  initialCameraPosition: CameraPosition(
                                    target: userLocation,
                                    zoom: 5.0,
                                  ),
                                  myLocationEnabled: true,
                                  myLocationButtonEnabled: true,
                                  zoomGesturesEnabled: true,
                                  mapType: MapType.hybrid,
                                  scrollGesturesEnabled:
                                      false, // Disable scrolling gestures
                                  rotateGesturesEnabled:
                                      true, // Optionally, you can allow rotation gestures
                                  tiltGesturesEnabled:
                                      true, // Optionally, you c
                                )),
                            if (showPolls)
                              if (_latitude != 0.0 && _longitude != 0.0)
                                Positioned(
                                  left: _latitude +
                                      45, // X position based on user's current longitude
                                  top: _longitude -
                                      60, // Y position above user's current position (container will be above)
                                  child: Column(
                                    children: [
                                      // Container holding the information (Temperature, Humidity, Wind Speed)
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border:
                                              Border.all(color: Colors.green),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          boxShadow: const [
                                            BoxShadow(
                                                color: Colors.greenAccent,
                                                blurRadius: 4)
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Temperature
                                            Obx(
                                              () => Row(
                                                children: [
                                                  Container(
                                                    width: 15,
                                                    height: 15,
                                                    decoration:
                                                        const BoxDecoration(
                                                      image: DecorationImage(
                                                        image: AssetImage(
                                                            'images/temp.png'),
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${weatherController.weather.value.temp.toStringAsFixed(1)}°C',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Moisture
                                            Obx(() => Row(
                                                  children: [
                                                    Container(
                                                      width: 15,
                                                      height: 15,
                                                      decoration:
                                                          const BoxDecoration(
                                                        image: DecorationImage(
                                                          image: AssetImage(
                                                              'images/humidity.png'),
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      '${moistureValue.value}',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ],
                                                )),
                                            // Wind Speed
                                            const SizedBox(width: 8),

                                            Obx(
                                              () => Row(
                                                children: [
                                                  Container(
                                                    width: 15,
                                                    height: 15,
                                                    decoration:
                                                        const BoxDecoration(
                                                      image: DecorationImage(
                                                        image: AssetImage(
                                                            'images/windspeed.png'),
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${weatherController.weather.value.windspeed.toStringAsFixed(1)} m/s',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // The stick (vertical line) below the container, from the user's current position
                                      Container(
                                        height: 50, // Height of the "stick"
                                        width: 4, // Width of the stick
                                        color:
                                            Colors.black, // Color of the stick
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      if (!context.watch<ISSAASProvider>().isSaas)
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(5, 10, 5, 5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Image.asset(
                                    'images/mode.jpeg', // Path to your SVG file
                                    height: 25,
                                    width: 25,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Control Mode",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
// Second GridView for Control Mode Cards
                      if (!context.watch<ISSAASProvider>().isSaas)
                        Row(
                          children: [
                            SizedBox(
                              height: 130, // Set the custom height
                              width: 180, // Set the custom width
                              child: GestureDetector(
                                onTap: () {
                                  isManual = false; // Autonomous mode

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Fetch_Input(
                                          //controller: _controller,
                                          isManualControl: isManual,
                                          groundMode: _groundMode),
                                    ),
                                  );
                                },
                                child: Card(
                                  margin: const EdgeInsets.fromLTRB(1, 1, 1, 1),
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  color: Colors.white,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'images/auto.png', // Replace with your image path
                                        height: 90,
                                        width: 140,
                                      ),
                                      Text(
                                        'Autonomous',
                                        style: TextStyle(
                                          color: Colors.indigo[800],
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          fontFamily:
                                              GoogleFonts.poppins().fontFamily,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 140, // Set the custom height
                              width: 180, // Set the custom width
                              child: GestureDetector(
                                onTap: () {
                                  isManual = true; // Manual mode
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Fetch_Input(
                                          // controller: _controller,
                                          isManualControl: isManual,
                                          groundMode: _groundMode),
                                    ),
                                  );
                                },
                                child: Card(
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  color: const Color(0xFFFFFFFF),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: Image.asset(
                                          'images/manual.png', // Replace with your image path
                                          height: 100,
                                          width: 150,
                                        ),
                                      ),
                                      Text(
                                        'Manual',
                                        style: TextStyle(
                                          color: Colors.indigo[800],
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          fontFamily:
                                              GoogleFonts.poppins().fontFamily,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (context.watch<ISSAASProvider>().isSaas)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(5, 10, 5, 5),
                          child: Column(
                            children: [
                              Image.asset(
                                'images/saas.png', // Path to your image
                                height: 250,
                                width: 450,
                              ),
                              const SizedBox(
                                  height:
                                      10), // Add some space between the image and the button
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo[800],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Start Spraying",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontFamily:
                                            GoogleFonts.poppins().fontFamily,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white,
                                    ), // Replace with your desired icon
                                  ],
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const Fetch_Input(
                                        // controller: _controller,
                                        isManualControl: false,
                                        groundMode: false,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Image.asset(
                      'images/field.png', // Path to your SVG file
                      height: 35, // Optional: Set the height as needed
                      width: 35, // Optional: Set the width as needed
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Text(
                      "Today Farm Stats",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      height: 250,
                      width: 230,
                      child: _buildPieChart(
                        weatherController.weather.value.temp,
                        weatherController.weather.value.windspeed,
                        moistureValue.value,
                      ),
                    ),
                    _buildLegend(),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.solar_power,
                              color: Colors.black,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Solar Status",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                              ),
                            ),
                            const SizedBox(width: 50),
                            ToggleSwitch(
                              activeBgColor: const [Colors.indigo],
                              initialLabelIndex: _isSolarOn ? 0 : 1,
                              totalSwitches: 2,
                              labels: const ['Yes', 'No'],
                              onToggle: (index) {
                                setState(() {
                                  _isSolarOn = index == 0;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _isSolarOn
                            ? Image.asset(
                                'images/solar_day.png',
                                width: 200,
                                height: 200,
                              ) // Replace with your image path
                            : Image.asset(
                                'images/solar_night.png',
                                width: 200,
                                height: 200,
                              ), // Replace with your image path
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _fetchData() {
    _dbRef.child('Area').onValue.listen((event) {
      final double fetchedArea =
          double.tryParse(event.snapshot.value.toString()) ?? 0.0;
      setState(() {
        area = fetchedArea.toStringAsFixed(2);
      });
    });

    _dbRef.child('totalDistance').onValue.listen((event) {
      final double fetchedTotalDistance =
          double.tryParse(event.snapshot.value.toString()) ?? 0.0;
      setState(() {
        totalDistance = fetchedTotalDistance.toStringAsFixed(2);
      });
    });

    _dbRef.child('remainingDistance').onValue.listen((event) {
      final double fetchedRemainingDistance =
          double.tryParse(event.snapshot.value.toString()) ?? 0.0;
      setState(() {
        remainingDistance = fetchedRemainingDistance.toStringAsFixed(2);
      });
    });

    _dbRef.child('TimeDuration').onValue.listen((event) {
      final double fetchedDuration =
          double.tryParse(event.snapshot.value.toString()) ?? 0.0;
      setState(() {
        duration = fetchedDuration.toStringAsFixed(2);
      });
    });
  }
}

Widget _buildPieChart(double temp, double windspeed, double moisture) {
  return PieChart(
    PieChartData(
      sections: [
        PieChartSectionData(
          color: Colors.blue,
          value: temp,
          title: '${temp.toStringAsFixed(1)}°C',
          radius: 60,
          titleStyle: GoogleFonts.poppins(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        PieChartSectionData(
          color: Colors.green,
          value: moisture,
          title: '${moisture.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: GoogleFonts.poppins(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        PieChartSectionData(
          color: Colors.amber,
          value: windspeed,
          title: '${windspeed.toStringAsFixed(1)} m/s',
          radius: 60,
          titleStyle: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
      sectionsSpace: 2,
      centerSpaceRadius: 40,
    ),
  );
}

Widget _buildLegend() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 20,
            height: 20,
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(
            'Temperature (°C)',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Container(
            width: 20,
            height: 20,
            color: Colors.green,
          ),
          const SizedBox(width: 8),
          Text(
            'Moisture (%)',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Container(
            width: 20,
            height: 20,
            color: Colors.amber,
          ),
          const SizedBox(width: 5),
          Text(
            'Wind Speed (m/s)',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ],
  );
}

class CustomUGVIcon extends StatelessWidget {
  const CustomUGVIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, // Updated to 40x40 size
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(width: 2, color: Colors.white),
      ),

      child: Image.asset(
        width: 35,
        height: 35,
        'images/ugv_active.png', // Path to the PNG image
        fit: BoxFit.cover, // Ensures the image covers the circle
      ),
    );
  }
}

class CustomUAVIcon extends StatelessWidget {
  const CustomUAVIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, // Updated to 40x40 size
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(width: 2, color: Colors.white),
      ),

      child: Image.asset(
        width: 35,
        height: 35,
        'images/uav.png', // Path to the PNG image
        fit: BoxFit.cover, // Ensures the image covers the circle
      ),
    );
  }
}

class GreenBlinkingDot extends StatefulWidget {
  const GreenBlinkingDot({super.key});

  @override
  _GreenBlinkingDotState createState() => _GreenBlinkingDotState();
}

class _GreenBlinkingDotState extends State<GreenBlinkingDot>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation; // Change to Animation<Color?>

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();
    _colorAnimation = ColorTween(
      begin: Colors.lightGreenAccent,
      end: Colors.green[800],
    ).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _colorAnimation.value ??
                Colors.green[800], // Handle nullable color
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
