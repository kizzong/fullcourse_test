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
  String? selectedSource; // null = 전체, "michelin" = 미슐랭만

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  // 필터링된 식당 목록
  List<Map<String, dynamic>> get filteredRestaurants {
    if (selectedSource == null) {
      print('🔍 필터: 전체 (${restaurants.length}개)');
      return restaurants; // 전체 보기
    }
    final filtered = restaurants.where((restaurant) {
      final source = restaurant['source']?.toString() ?? '';
      return source.contains(selectedSource!);
    }).toList();
    print('🔍 필터: "$selectedSource" (${filtered.length}개)');
    return filtered;
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
          '  - ${restaurant['name']} (source: "${restaurant['source']}")',
        );
      }

      // source 값 통계
      final sourceCount = <String, int>{};
      for (var restaurant in restaurants) {
        final source = restaurant['source']?.toString() ?? 'null';
        sourceCount[source] = (sourceCount[source] ?? 0) + 1;
      }
      print('📊 Source 통계:');
      sourceCount.forEach((source, count) {
        print('  - "$source": $count개');
      });

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

    final restaurantsToShow = filteredRestaurants;

    print('📍 마커 추가 시작...');
    for (var restaurant in restaurantsToShow) {
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
    print('📍 총 ${restaurantsToShow.length}개 마커 추가 완료!');
  }

  // 마커 새로고침 (필터 변경 시)
  Future<void> _refreshMarkers() async {
    if (mapController == null) return;

    // 기존 마커 모두 제거
    await mapController!.clearOverlays();

    // 필터링된 마커 다시 추가
    _addMarkers();
  }

  // 식당 로고 위젯 리스트 생성
  List<Widget> _getRestaurantLogos(Map<String, dynamic> restaurant) {
    List<Widget> logos = [];
    final source = restaurant['source']?.toString() ?? '';
    final michelinGrade = restaurant['michelin_grade']?.toString();

    // 미슐랭 로고 (스타 또는 빕구르망)
    if (source.contains('michelin') && michelinGrade != null) {
      if (michelinGrade == 'bib_gourmand') {
        logos.add(ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            'assets/images/bib_gourmand_logo.png',
            width: 32,
            height: 32,
          ),
        ));
      } else if (michelinGrade.startsWith('star_')) {
        logos.add(ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            'assets/images/michelin_logo.png',
            width: 32,
            height: 32,
          ),
        ));
      }
    }

    // 부산의 맛 로고
    if (source.contains('busan_mat')) {
      logos.add(ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          'assets/images/busan_mat_logo.png',
          width: 32,
          height: 32,
        ),
      ));
    }

    return logos;
  }

  // 식당 정보 다이얼로그 표시
  void _showRestaurantInfo(Map<String, dynamic> restaurant) {
    final logos = _getRestaurantLogos(restaurant);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    restaurant['name'],
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                if (logos.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  ...logos.map((logo) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: logo,
                      )),
                ],
              ],
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
                icon: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    'assets/images/naver_map_logo.png',
                    width: 24,
                    height: 24,
                  ),
                ),
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
          // 상단 필터 버튼
          Positioned(
            top: safeAreaPadding.top + 10,
            left: 10,
            right: 10,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterButton(
                    label: '전체',
                    isSelected: selectedSource == null,
                    onPressed: () {
                      setState(() {
                        selectedSource = null;
                      });
                      _refreshMarkers();
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterButton(
                    label: '미슐랭',
                    iconPath: 'assets/images/michelin_logo.png',
                    isSelected: selectedSource == 'michelin',
                    onPressed: () {
                      setState(() {
                        selectedSource = 'michelin';
                      });
                      _refreshMarkers();
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterButton(
                    label: '부산의 맛',
                    iconPath: 'assets/images/busan_mat_logo.png',
                    isSelected: selectedSource == 'busan_mat',
                    onPressed: () {
                      setState(() {
                        selectedSource = 'busan_mat';
                      });
                      _refreshMarkers();
                    },
                  ),
                ],
              ),
            ),
          ),
          if (isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  // 필터 버튼 위젯
  Widget _buildFilterButton({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
    String? iconPath,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.green : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                iconPath,
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
