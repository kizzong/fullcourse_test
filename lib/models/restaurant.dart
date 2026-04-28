class Restaurant {
  final String id;
  final String name;
  final String category;
  final String? description;
  final String address;
  final double latitude;
  final double longitude;
  final String? naverPlaceName;
  final String? source;
  final String? michelinGrade;

  Restaurant({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.naverPlaceName,
    this.source,
    this.michelinGrade,
  });

  // Supabase 데이터를 Restaurant 객체로 변환
  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String?,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      naverPlaceName: json['naver_place_name'] as String?,
      source: json['source'] as String?,
      michelinGrade: json['michelin_grade'] as String?,
    );
  }
}
