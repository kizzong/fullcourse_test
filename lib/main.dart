import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 네이버 지도 SDK 초기화
  await FlutterNaverMap().init(
    clientId: '8ohtiju5l7',
    onAuthFailed: (ex) {
      switch (ex) {
        case NQuotaExceededException(:final message):
          print("사용량 초과 (message: $message)");
          break;
        case NUnauthorizedClientException() ||
            NClientUnspecifiedException() ||
            NAnotherAuthFailedException():
          print("인증 실패: $ex");
          break;
      }
    },
  );

  // Supabase 초기화
  await Supabase.initialize(
    url: 'https://lvdapdjtfzbihaxcyqdm.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx2ZGFwZGp0ZnpiaWhheGN5cWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyMTEzNzYsImV4cCI6MjA5Mjc4NzM3Nn0.lVRXsZVZ_RkR0QQ9g3TJbRFD5JKx-ScpQoF9IKt-QiU',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // ← 이게 빠져있었어요!
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> restaurants = [];
  bool isLoading = true;
  NaverMapController? mapController;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  // Supabase에서 식당 데이터 불러오기
  Future<void> _loadRestaurants() async {
    try {
      print('📡 Supabase에서 데이터 불러오는 중...');
      final data = await supabase.from('restaurants').select();
      setState(() {
        restaurants = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
      print('✅ 식당 데이터 로드 완료: ${restaurants.length}개');
      for (var restaurant in restaurants) {
        print(
          '  - ${restaurant['name']} (${restaurant['latitude']}, ${restaurant['longitude']})',
        );
      }

      // 데이터 로드 후 마커 추가
      _addMarkers();
    } catch (e) {
      print('❌ 데이터 로드 실패: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // 지도에 마커 추가
  void _addMarkers() {
    if (mapController == null) {
      print('⚠️ 지도 컨트롤러가 아직 준비되지 않았습니다.');
      return;
    }

    if (restaurants.isEmpty) {
      print('⚠️ 식당 데이터가 없습니다.');
      return;
    }

    print('📍 마커 추가 시작...');
    for (var restaurant in restaurants) {
      try {
        final marker = NMarker(
          id: restaurant['id'],
          position: NLatLng(
            restaurant['latitude'] as double,
            restaurant['longitude'] as double,
          ),
          caption: NOverlayCaption(text: restaurant['name']),
          // 마커 크기 조정 (기본보다 60% 작게)
          size: const NSize(22, 31),
        );

        // 마커 클릭 이벤트
        marker.setOnTapListener((overlay) {
          _showRestaurantInfo(restaurant);
        });

        mapController!.addOverlay(marker);
        print('  ✅ ${restaurant['name']} 마커 추가 완료');
      } catch (e) {
        print('  ❌ ${restaurant['name']} 마커 추가 실패: $e');
      }
    }
    print('📍 총 ${restaurants.length}개 마커 추가 완료!');
  }

  // 식당 정보 다이얼로그 표시
  void _showRestaurantInfo(Map<String, dynamic> restaurant) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              restaurant['name'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              restaurant['category'],
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (restaurant['description'] != null)
              Text(
                restaurant['description'],
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 8),
            Text(
              restaurant['address'],
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _openNaverMap(restaurant);
                },
                icon: const Icon(Icons.map),
                label: const Text('네이버 지도에서 보기'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 네이버 지도 앱/웹으로 연결
  Future<void> _openNaverMap(Map<String, dynamic> restaurant) async {
    final lat = restaurant['latitude'];
    final lng = restaurant['longitude'];
    final name = restaurant['name'];

    // 네이버 지도 URL Scheme
    final naverMapUrl =
        'nmap://place?lat=$lat&lng=$lng&name=$name&appname=com.example.test_full';

    // 웹 URL (앱이 없을 때 대체)
    final webUrl = 'https://map.naver.com/v5/search/$name';

    try {
      final Uri uri = Uri.parse(naverMapUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // 앱이 없으면 웹으로
        await launchUrl(
          Uri.parse(webUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      print('네이버 지도 열기 실패: $e');
      // 웹으로 시도
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    const busanSeomyeon = NLatLng(35.1579, 129.0597);
    final safeAreaPadding = MediaQuery.paddingOf(context);

    return Scaffold(
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              contentPadding: safeAreaPadding,
              initialCameraPosition: NCameraPosition(
                target: busanSeomyeon,
                zoom: 14,
              ),
            ),
            onMapReady: (controller) {
              print("🗺️ 네이버 지도 준비 완료!");
              mapController = controller;
              _addMarkers();
            },
          ),
          if (isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
