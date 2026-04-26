import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

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

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const busanSeomyeon = NLatLng(35.1579, 129.0597);
    final safeAreaPadding = MediaQuery.paddingOf(context);

    return Scaffold(
      body: NaverMap(
        options: NaverMapViewOptions(
          contentPadding: safeAreaPadding,
          initialCameraPosition: NCameraPosition(
            target: busanSeomyeon,
            zoom: 14,
          ),
        ),
        onMapReady: (controller) {
          final marker = NMarker(
            id: "seomyeon",
            position: busanSeomyeon,
            caption: NOverlayCaption(text: "부산 서면"),
          );
          controller.addOverlay(marker);
          print("naver map is ready!");
        },
      ),
    );
  }
}
