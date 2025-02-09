import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:project_drone/Constant/weather.dart';

class WeatherController extends GetxController {
  var weather = Weather(
    cityname: "N/A",
    icon: "",
    temp: 0.0,
    humidity: 0,
    windspeed: 0.0,
    condition: "",
  ).obs;

  @override
  void onInit() {
    super.onInit();
    // Get the current location first
    _getCurrentLocation();
  }

  // Function to get the current location
  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return;
      }

      // Check if the app has permission to access the location
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return;
        }
      }

      // Get the current position (latitude and longitude)
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Fetch weather data with the current location
      fetchWeatherData(position.latitude, position.longitude);
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  // Function to fetch weather data from the API
  Future<void> fetchWeatherData(double latitude, double longitude) async {
    try {
      var uri = Uri.parse(
          "http://api.weatherapi.com/v1/current.json?key=afa5323058974cbb9cf151657230504&q=$latitude,$longitude&aqi=no");
      var res = await http.get(uri);

      if (res.statusCode == 200) {
        Weather fetchedWeather = Weather.fromjson(jsonDecode(res.body));
        weather.value = fetchedWeather; // Update the observable weather data
      } else {
        print('Failed to fetch weather data');
      }
    } catch (e) {
      print('Error fetching weather data: $e');
    }
  }
}
