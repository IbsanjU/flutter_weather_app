// main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_key.dart';
import 'weather.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.blueGrey[900],
      ),
      home: WeatherApp(),
    );
  }
}

class WeatherApp extends StatefulWidget {
  @override
  _WeatherAppState createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  String city = '';
  Weather? weather;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _handleLocationPermission().then((gotPermission) => {if (gotPermission) getCurrentLocationWeather()});
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled. Please enable the services')));
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }
    return true;
  }

  Future<void> getCurrentLocationWeather() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      await getWeatherByCoordinates(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        errorMessage = "Couldn't get current location. Please enter a city.";
      });
    }
  }

  Future<void> getWeatherByCoordinates(double lat, double lon) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        weather = Weather.fromJson(json);
        city = weather!.cityName;
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      errorMessage = 'Failed to get weather data. Please try again.';
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> getWeather() async {
    if (city.isNotEmpty) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      try {
        final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric');
        final response = await http.get(url);

        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          weather = Weather.fromJson(json);
        } else if (response.statusCode == 404) {
          throw Exception('City not found. Please check the spelling.');
        } else {
          throw Exception('Failed to load weather data. Status code: ${response.statusCode}');
        }
      } catch (e) {
        setState(() {
          errorMessage = e.toString();
        });
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        errorMessage = 'Please enter a city name.';
      });
    }
  }

  Future<List<String>> getSuggestions(String query) async {
    if (query.length < 3) return [];

    final url = Uri.parse('https://api.openweathermap.org/geo/1.0/direct?q=$query&limit=5&appid=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((city) => "${city['name']}, ${city['country']}").toList();
    } else {
      throw Exception('Failed to load suggestions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IbsanjU - Weather App'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }
                return getSuggestions(textEditingValue.text);
              },
              onSelected: (String selection) {
                setState(() {
                  city = selection.split(',')[0];
                });
                getWeather();
              },
              fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  onChanged: (value) => city = value,
                  decoration: InputDecoration(
                    hintText: 'Enter City Name',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        getWeather();
                        onFieldSubmitted();
                      },
                    ),
                  ),
                  onSubmitted: (_) {
                    getWeather();
                    onFieldSubmitted();
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const CircularProgressIndicator()
            else if (errorMessage != null)
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              )
            else if (weather != null)
              buildWeather(weather!)
            else
              const Text('Enter a city to get weather information'),
            const Expanded(child: Text("")),
            const LinkWidget(url: "https://blog.ibsanju.com", text: "Visist Blog"),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget buildWeather(Weather weather) => Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                weather.cityName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    getWeatherIcon(weather.description),
                    size: 50,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${weather.temperature.toStringAsFixed(1)} °C',
                    style: const TextStyle(fontSize: 40),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                weather.description,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  WeatherInfo(
                    icon: Icons.water_drop,
                    label: 'Humidity',
                    value: '${weather.humidity}%',
                  ),
                  WeatherInfo(
                    icon: Icons.wind_power,
                    label: 'Wind Speed',
                    value: '${weather.windSpeed} m/s',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinkWidget(
                url: 'https://openweathermap.org/city/${weather.id}',
                text: 'View more details on OpenWeatherMap',
              ),
            ],
          ),
        ),
      );

  IconData getWeatherIcon(String description) {
    description = description.toLowerCase();
    if (description.contains('clear')) return Icons.wb_sunny;
    if (description.contains('cloud')) return Icons.cloud;
    if (description.contains('rain')) return Icons.beach_access;
    if (description.contains('snow')) return Icons.ac_unit;
    return Icons.wb_cloudy;
  }
}

class WeatherInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const WeatherInfo({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon),
        const SizedBox(height: 8),
        Text(label),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class LinkWidget extends StatelessWidget {
  final String url;
  final String text;

  const LinkWidget({Key? key, required this.url, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade700],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchURL(url),
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.open_in_new, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _launchURL(String url) async {
  final Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    throw 'Could not launch $url';
  }
}
