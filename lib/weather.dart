class Weather {
  final int id;
  final double temperature;
  final String description;
  final int humidity;
  final double windSpeed;
  final String cityName;

  Weather({
    required this.id,
    required this.temperature,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.cityName,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      id: json['id'],
      temperature: json['main']['temp'].toDouble(),
      description: json['weather'][0]['description'],
      humidity: json['main']['humidity'],
      windSpeed: json['wind']['speed'].toDouble(),
      cityName: json['name'],
    );
  }
}
