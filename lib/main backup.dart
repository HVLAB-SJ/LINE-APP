import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:speech_to_text/speech_to_text.dart' as stt;

// 앱 버전 및 캐시 관리
class AppVersion {
  static const String version = '1.0.1';
  static const String buildNumber = '2';
  static String get buildTime =>
      DateTime.now().millisecondsSinceEpoch.toString();
  static String get cacheKey => '${version}_${buildTime}';

  // 카카오톡 인앱 브라우저 감지
  static bool get isKakaoTalk {
    if (kIsWeb) {
      return html.window.navigator.userAgent.contains('KAKAOTALK') ?? false;
    }
    return false;
  }

  // 캐시 무효화
  static void clearCache() {
    if (kIsWeb) {
      // 로컬 스토리지 캐시 무효화
      html.window.localStorage.clear();
      html.window.sessionStorage.clear();

      // 페이지 새로고침 시 캐시 무시
      final currentUrl = html.window.location.href;
      final uri = Uri.parse(currentUrl);
      final newParams = Map<String, String>.from(uri.queryParameters);
      newParams['_v'] = cacheKey;
      newParams['_t'] = DateTime.now().millisecondsSinceEpoch.toString();

      final newUri = uri.replace(queryParameters: newParams);
      html.window.history.replaceState({}, '', newUri.toString());
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 카카오톡 인앱 브라우저에서 캐시 무효화
  if (AppVersion.isKakaoTalk) {
    AppVersion.clearCache();
    print('카카오톡 인앱 브라우저 감지 - 캐시 무효화 실행');
  }

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCQ1_7hbvODByDihzdPe0bAg8r7zLRPMeo",
      authDomain: "hv-line.firebaseapp.com",
      databaseURL: "https://hv-line-default-rtdb.firebaseio.com",
      projectId: "hv-line",
      storageBucket: "hv-line.firebasestorage.app",
      messagingSenderId: "651342907657",
      appId: "1:651342907657:web:2ce01d847b0bef45752bd8",
    ),
  );

  runApp(const LineDrawerApp());
}

class LineDrawerApp extends StatelessWidget {
  const LineDrawerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HV LAB Drawer v${AppVersion.version}',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117), // Cursor 배경색
        cardColor: const Color(0xFF161B22),
        dividerColor: const Color(0xFF30363D),
        primaryColor: const Color(0xFF238636),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF238636),
          secondary: Color(0xFF1F6FEB),
          surface: Color(0xFF161B22),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFFE6EDF3),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF238636),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFFE6EDF3),
        ),
      ),
      home: const LineDrawerScreen(),
    );
  }
}

class Line {
  Offset start;
  Offset end;
  String? openingType;
  bool isDiagonal;
  Map<String, dynamic>? connectedPoints;

  Line({
    required this.start,
    required this.end,
    this.openingType,
    this.isDiagonal = false,
    this.connectedPoints,
  });

  Line copy() {
    return Line(
      start: start,
      end: end,
      openingType: openingType,
      isDiagonal: isDiagonal,
      connectedPoints:
          connectedPoints != null ? Map.from(connectedPoints!) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startX': start.dx,
      'startY': start.dy,
      'endX': end.dx,
      'endY': end.dy,
      'openingType': openingType,
      'isDiagonal': isDiagonal,
      'connectedPoints': connectedPoints,
    };
  }

  static Line fromJson(Map<dynamic, dynamic> json) {
    return Line(
      start: Offset(
        (json['startX'] as num).toDouble(),
        (json['startY'] as num).toDouble(),
      ),
      end: Offset(
        (json['endX'] as num).toDouble(),
        (json['endY'] as num).toDouble(),
      ),
      openingType: json['openingType'] as String?,
      isDiagonal: json['isDiagonal'] as bool? ?? false,
      connectedPoints: json['connectedPoints'] as Map<String, dynamic>?,
    );
  }
}

class Circle {
  Offset center;
  double radius;

  Circle({
    required this.center,
    required this.radius,
  });

  Circle copy() {
    return Circle(
      center: center,
      radius: radius,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'centerX': center.dx,
      'centerY': center.dy,
      'radius': radius,
    };
  }

  static Circle fromJson(Map<dynamic, dynamic> json) {
    return Circle(
      center: Offset(
        (json['centerX'] as num).toDouble(),
        (json['centerY'] as num).toDouble(),
      ),
      radius: (json['radius'] as num).toDouble(),
    );
  }
}

class LineDrawerScreen extends StatefulWidget {
  const LineDrawerScreen({Key? key}) : super(key: key);

  @override
  State<LineDrawerScreen> createState() => _LineDrawerScreenState();
}

class _LineDrawerScreenState extends State<LineDrawerScreen> {
  List<Line> lines = [];
  List<Circle> circles = [];
  List<Map<String, dynamic>> linesHistory = [];
  List<Map<String, dynamic>> circlesHistory = [];
  Offset currentPoint = const Offset(0, 0);
  double viewScale = 0.3;
  Offset viewOffset = const Offset(500, 500);
  int selectedLineIndex = -1;
  int selectedCircleIndex = -1;
  // 점 간 드래그 선 그리기 변수
  bool isPointDragging = false;
  Offset? pointDragStart;
  Offset? pointDragEnd;
  bool circleMode = false;
  bool diagonalMode = false; // 대각선(점과 점 연결) 모드
  Offset? circleCenter;
  String? pendingOpeningType;
  String? arrowDirection;

  // Firebase
  late DatabaseReference _linesRef;
  late DatabaseReference _circlesRef;
  late DatabaseReference _currentPointRef;
  late DatabaseReference _metadataRef;
  StreamSubscription? _linesSubscription;
  StreamSubscription? _circlesSubscription;
  StreamSubscription? _currentPointSubscription;
  StreamSubscription? _metadataSubscription;
  bool _isUpdating = false;

  // 세션 ID (각 기기를 구분하기 위함)
  final String sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  // 타임스탬프 기반 동기화
  int _lastUpdateTimestamp = 0;
  String _lastUpdateDevice = '';
  bool _isLocalUpdate = false;

  // 팬/줌 관련 변수
  Offset? panStartOffset;
  double? zoomStartScale;
  Offset? dragStartPos;

  // 마우스 호버 관련 변수
  Offset? hoveredPoint;
  Offset? mousePosition;
  int? hoveredLineIndex;

  // 터치 이벤트 관련 변수
  Offset? _lastTapPosition;
  DateTime? _lastTapTime;
  bool _isScaling = false; // 스케일 제스처 중인지 추적

  // 인라인 입력 관련 변수
  bool showInlineInput = false;
  String inlineDirection = "";
  TextEditingController inlineController = TextEditingController();
  FocusNode inlineFocus = FocusNode();
  bool isProcessingInput = false;

  // 전체화면 관련 변수
  bool isFullscreen = false;
  bool _userRequestedFullscreen = false; // 사용자가 직접 전체화면을 요청했는지 추적
  bool _isRecovering = false; // 전체화면 복구 중인지 추적

  // 초기 데이터 로딩 상태 추적
  bool _linesLoaded = false;
  bool _circlesLoaded = false;
  bool _currentPointLoaded = false;
  bool _initialViewFitExecuted = false;

  // 선 팝업 관련 변수
  bool showLinePopup = false;
  Offset? linePopupPosition;
  int? selectedLineForPopup;

  // 레이아웃 모드 관리
  String layoutMode = 'mobile'; // 'tablet', 'mobile', 'desktop' (기본값: mobile)

  // 모바일 기기 감지
  bool get isMobile {
    return layoutMode == 'mobile';
  }

  // 태블릿 모드 감지 (자동 감지 제거)
  bool get isTablet {
    // 수동 태블릿 모드만 지원
    return layoutMode == 'tablet';
  }

  // 데스크톱 모드 감지
  bool get isDesktop {
    return layoutMode == 'desktop';
  }

  final FocusNode _focusNode = FocusNode();

  // 음성 인식 관련 변수
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;
  String _lastWords = '';
  String _recognizedText = '';
  bool _speechAvailable = false;

  // 웹 전용 음성 인식 변수
  html.SpeechRecognition? _webSpeechRecognition;
  bool _webSpeechAvailable = false;

  // Safari 전용 음성 인식 변수
  js.JsObject? _safariSpeechRecognition;

  // 마지막 방향 저장
  String? lastDirection;

  // 음성 인식 처리 중복 방지 (강화)
  bool _isSpeechProcessing = false;
  DateTime? _lastSpeechProcessTime;
  String? _lastProcessedText; // 마지막 처리된 텍스트
  int _speechProcessCount = 0; // 처리 횟수 카운터
  Set<String> _processedTexts = {}; // 처리된 텍스트 집합 (중복 방지)
  DateTime? _lastLineDrawTime; // 마지막 선 그리기 시간
  bool _isVoiceProcessing = false; // 음성 처리 중 상태 (UI용)

  // 음성 인식 토글 모드 관련 변수
  // 자동 음성 모드 변수들 제거 - 성능 최적화를 위해 단순한 음성 인식 모드로 변경

  // 화면 이동 및 줌 관련 변수
  bool _isPanning = false;
  Offset? _lastPanPosition;
  double _initialScale = 1.0;
  int _touchCount = 0;

  @override
  void initState() {
    super.initState();

    // Firebase 초기화
    _linesRef = FirebaseDatabase.instance.ref('drawing/lines');
    _circlesRef = FirebaseDatabase.instance.ref('drawing/circles');
    _currentPointRef = FirebaseDatabase.instance.ref('drawing/currentPoint');
    _metadataRef = FirebaseDatabase.instance.ref('drawing/metadata');

    // 실시간 동기화 설정
    _setupRealtimeSync();

    // 전체화면 리스너 설정
    _setupFullscreenListener();

    // 기기 감지 디버깅 정보 출력
    _printDeviceInfo();

    // 음성 인식 초기화
    _initSpeech();

    // 앱 시작 시 포커스 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      // 뷰 맞춤은 Firebase 데이터 로딩 완료 후 _checkInitialDataLoaded에서 실행
    });
  }

  void _printDeviceInfo() {
    if (kIsWeb) {
      final userAgent = html.window.navigator.userAgent;
      final platform = html.window.navigator.platform;
      final maxTouchPoints = html.window.navigator.maxTouchPoints;
      final screenWidth = html.window.screen?.width;
      final screenHeight = html.window.screen?.height;

      // 상세 감지 정보
      final userAgentLower = userAgent.toLowerCase();
      final platformLower = platform?.toLowerCase() ?? '';

      // 아이패드 자동 감지 및 설정
      final isIPad = userAgentLower.contains('ipad') ||
          (userAgentLower.contains('macintosh') && maxTouchPoints! > 0) ||
          platformLower.contains('ipad');

      if (isIPad && layoutMode == 'mobile') {
        print('아이패드 감지됨 - 자동으로 태블릿 모드로 전환');
        layoutMode = 'tablet';
      }

      print('=== 기기 감지 정보 ===');
      print('User Agent: $userAgent');
      print('Platform: $platform');
      print('Max Touch Points: $maxTouchPoints');
      print('Screen Size: ${screenWidth}x$screenHeight');
      print('');
      print('=== 감지 조건 ===');
      print('contains iphone: ${userAgentLower.contains('iphone')}');
      print('contains ipad: ${userAgentLower.contains('ipad')}');
      print('contains android: ${userAgentLower.contains('android')}');
      print('contains mobile: ${userAgentLower.contains('mobile')}');
      print('contains macintosh: ${userAgentLower.contains('macintosh')}');
      print('platform contains ipad: ${platformLower.contains('ipad')}');
      print('iPad detected: $isIPad');
      print('');
      print('=== 최종 결과 ===');
      print('Layout Mode: ${layoutMode ?? "자동"}');
      print('isMobile: $isMobile');
      print('isTablet: $isTablet');
      print('isDesktop: $isDesktop');
      print('==================');
    }
  }

  void _setupRealtimeSync() {
    // 메타데이터 동기화 (타임스탬프 기반)
    _metadataSubscription = _metadataRef.onValue.listen((event) {
      if (_isLocalUpdate) {
        print('로컬 업데이트 중 - 메타데이터 동기화 무시');
        return;
      }

      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final timestamp = data['lastUpdateTimestamp'] as int? ?? 0;
        final device = data['lastUpdateDevice'] as String? ?? '';

        print(
            '메타데이터 수신 - 타임스탬프: $timestamp, 기기: $device, 현재: $_lastUpdateTimestamp');

        // 더 최신 데이터가 있으면 전체 데이터 다시 로드
        if (timestamp > _lastUpdateTimestamp && device != sessionId) {
          print('더 최신 데이터 감지 - 전체 데이터 동기화 시작');
          _lastUpdateTimestamp = timestamp;
          _lastUpdateDevice = device;
          _loadCompleteDataFromFirebase();
        }
      }
    });

    // 선들 동기화 (초기 로딩용)
    _linesSubscription = _linesRef.onValue.listen((event) {
      if (_isUpdating || _isLocalUpdate) {
        print('업데이트 중 - 선 동기화 무시');
        return;
      }

      final data = event.snapshot.value;
      setState(() {
        final newLines = <Line>[];
        if (data != null && data is List) {
          newLines.addAll(data
              .where((item) => item != null)
              .map((item) => Line.fromJson(item as Map<dynamic, dynamic>))
              .toList());
        }

        lines = newLines;
        print('선 데이터 로딩 - ${lines.length}개');

        // 선 데이터 로딩 완료 표시
        if (!_linesLoaded) {
          _linesLoaded = true;
          _checkInitialDataLoaded();
        }
      });
    });

    // 원들 동기화 (초기 로딩용)
    _circlesSubscription = _circlesRef.onValue.listen((event) {
      if (_isUpdating || _isLocalUpdate) {
        print('업데이트 중 - 원 동기화 무시');
        return;
      }

      final data = event.snapshot.value;
      setState(() {
        final newCircles = <Circle>[];
        if (data != null && data is List) {
          newCircles.addAll(data
              .where((item) => item != null)
              .map((item) => Circle.fromJson(item as Map<dynamic, dynamic>))
              .toList());
        }

        circles = newCircles;
        print('원 데이터 로딩 - ${circles.length}개');

        // 원 데이터 로딩 완료 표시
        if (!_circlesLoaded) {
          _circlesLoaded = true;
          _checkInitialDataLoaded();
        }
      });
    });

    // 현재 점 동기화 (초기 로딩용)
    _currentPointSubscription = _currentPointRef.onValue.listen((event) {
      if (_isUpdating || _isLocalUpdate) return;

      final data = event.snapshot.value;
      setState(() {
        if (data != null && data is Map) {
          currentPoint = Offset(
            (data['x'] as num).toDouble(),
            (data['y'] as num).toDouble(),
          );
        } else {
          currentPoint = const Offset(0, 0); // 데이터가 없으면 원점
        }

        // 현재 점 데이터 로딩 완료 표시
        if (!_currentPointLoaded) {
          _currentPointLoaded = true;
          _checkInitialDataLoaded();
        }
      });
    });
  }

  void _checkInitialDataLoaded() {
    // 모든 초기 데이터가 로딩되고 아직 뷰 맞춤을 실행하지 않았다면
    if (_linesLoaded &&
        _circlesLoaded &&
        _currentPointLoaded &&
        !_initialViewFitExecuted) {
      _initialViewFitExecuted = true;

      print('초기 데이터 로딩 완료 - 뷰 맞춤 자동 실행');
      print('현재 기기 모드 - isMobile: $isMobile, isTablet: $isTablet');

      // 약간의 지연 후 뷰 맞춤 실행 (UI 렌더링 완료 대기)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            // 모바일/태블릿에서는 항상 currentPoint를 화면 중심에 맞춤
            if (isMobile || isTablet) {
              print('모바일/태블릿 모드 - currentPoint 중심 맞춤 실행');
              centerCurrentPoint();
            } else {
              // 데스크톱에서는 기존 방식 사용
              fitViewToDrawing();
            }
          }
        });
      });
    }
  }

  void _updateFirebase() async {
    if (_isUpdating) {
      print('Firebase 업데이트 중 - 중복 호출 무시');
      return;
    }

    _isUpdating = true;
    _isLocalUpdate = true;

    try {
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

      // 로컬 데이터를 Firebase 형식으로 변환
      final localLinesJson = lines.map((line) => line.toJson()).toList();
      final localCirclesJson =
          circles.map((circle) => circle.toJson()).toList();

      // 모든 데이터를 한 번에 업데이트 (원자적 업데이트)
      final updates = <String, dynamic>{};
      updates['drawing/lines'] = localLinesJson;
      updates['drawing/circles'] = localCirclesJson;
      updates['drawing/currentPoint'] = {
        'x': currentPoint.dx,
        'y': currentPoint.dy,
        'timestamp': currentTimestamp,
      };
      updates['drawing/metadata'] = {
        'lastUpdateTimestamp': currentTimestamp,
        'lastUpdateDevice': sessionId,
        'deviceInfo': {
          'sessionId': sessionId,
          'platform': kIsWeb ? 'web' : 'mobile',
          'layoutMode': layoutMode,
          'timestamp': currentTimestamp,
        }
      };

      // 타임스탬프 업데이트
      _lastUpdateTimestamp = currentTimestamp;
      _lastUpdateDevice = sessionId;

      // Firebase 업데이트 실행
      await FirebaseDatabase.instance.ref().update(updates);

      print(
          'Firebase 업데이트 완료 - 선: ${localLinesJson.length}, 원: ${localCirclesJson.length}');
      print('타임스탬프: $currentTimestamp, 기기: $sessionId');
    } catch (e) {
      print('Firebase 업데이트 오류: $e');
    } finally {
      _isUpdating = false;
      // 약간의 지연 후 로컬 업데이트 플래그 해제
      Future.delayed(const Duration(milliseconds: 500), () {
        _isLocalUpdate = false;
      });
    }
  }

  // Firebase에서 완전한 데이터 로드 (타임스탬프 기반 동기화)
  Future<void> _loadCompleteDataFromFirebase() async {
    if (_isUpdating) return;

    _isUpdating = true;

    try {
      print('Firebase에서 완전한 데이터 로드 시작...');

      // 모든 데이터를 병렬로 가져오기
      final futures = await Future.wait([
        _linesRef.get(),
        _circlesRef.get(),
        _currentPointRef.get(),
      ]);

      final linesSnapshot = futures[0];
      final circlesSnapshot = futures[1];
      final currentPointSnapshot = futures[2];

      setState(() {
        // 선 데이터 로드
        final newLines = <Line>[];
        if (linesSnapshot.exists && linesSnapshot.value != null) {
          final data = linesSnapshot.value as List;
          newLines.addAll(data
              .where((item) => item != null)
              .map((item) => Line.fromJson(item as Map<dynamic, dynamic>))
              .toList());
        }
        lines = newLines;

        // 원 데이터 로드
        final newCircles = <Circle>[];
        if (circlesSnapshot.exists && circlesSnapshot.value != null) {
          final data = circlesSnapshot.value as List;
          newCircles.addAll(data
              .where((item) => item != null)
              .map((item) => Circle.fromJson(item as Map<dynamic, dynamic>))
              .toList());
        }
        circles = newCircles;

        // 현재 점 로드
        if (currentPointSnapshot.exists && currentPointSnapshot.value != null) {
          final data = currentPointSnapshot.value as Map;
          currentPoint = Offset(
            (data['x'] as num).toDouble(),
            (data['y'] as num).toDouble(),
          );
        }

        print('완전한 데이터 로드 완료 - 선: ${lines.length}, 원: ${circles.length}');
      });
    } catch (e) {
      print('완전한 데이터 로드 오류: $e');
    } finally {
      _isUpdating = false;
    }
  }

  // 음성 인식 초기화
  Future<void> _initSpeech() async {
    print('음성 인식 초기화 시작...');

    if (kIsWeb) {
      // 웹에서는 네이티브 Web Speech API 사용
      await _initWebSpeech();
    } else {
      // 모바일에서는 speech_to_text 패키지 사용
      await _initMobileSpeech();
    }
  }

  // 웹 전용 음성 인식 초기화
  Future<void> _initWebSpeech() async {
    print('웹 음성 인식 초기화 시작...');
    try {
      // Web Speech API 지원 확인
      final userAgent = html.window.navigator.userAgent;
      print('사용자 에이전트: $userAgent');

      // Safari, Chrome, Edge 등 지원 브라우저 확인
      if (userAgent.contains('Chrome') ||
          userAgent.contains('Edge') ||
          userAgent.contains('Safari')) {
        print('Web Speech API 지원 브라우저 감지');

        try {
          // 먼저 표준 SpeechRecognition 시도
          _webSpeechRecognition = html.SpeechRecognition();
          print('SpeechRecognition 객체 생성 성공');
        } catch (e) {
          print('SpeechRecognition 객체 생성 실패: $e');

          // Safari 브라우저에서 webkit 접두사 시도
          if (userAgent.contains('Safari') && !userAgent.contains('Chrome')) {
            print('Safari 브라우저 감지 - webkit 접두사 시도');

            try {
              // JavaScript를 통해 webkitSpeechRecognition 확인
              final webkitSupported =
                  js.context.hasProperty('webkitSpeechRecognition');
              print('webkitSpeechRecognition 지원: $webkitSupported');

              if (webkitSupported) {
                // webkitSpeechRecognition 사용을 위한 특별 처리
                _webSpeechAvailable = true;
                _speechAvailable = true;

                // Safari 초기화 성공 메시지 제거 (팝업 없이 조용히 처리)

                // Safari 전용 초기화 완료
                return;
              } else {
                throw Exception('Safari에서 webkitSpeechRecognition을 찾을 수 없습니다.');
              }
            } catch (e3) {
              print('Safari webkit 처리 실패: $e3');
              _webSpeechAvailable = false;
              _speechAvailable = false;

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Safari에서는 음성 인식 지원이 제한됩니다. Chrome 또는 Edge 사용을 권장합니다.'),
                    duration: Duration(seconds: 5),
                    backgroundColor: Color(0xFFCE9178),
                  ),
                );
              }
              return;
            }
          }

          throw Exception('이 브라우저는 음성 인식을 지원하지 않습니다.');
        }

        if (_webSpeechRecognition != null) {
          print('SpeechRecognition 객체 생성 성공');

          // 음성 인식 설정 (감도 향상)
          _webSpeechRecognition!.lang = 'ko-KR';
          _webSpeechRecognition!.continuous = true;
          _webSpeechRecognition!.interimResults = true;
          _webSpeechRecognition!.maxAlternatives = 3; // 대안 결과 증가

          // 감도 향상을 위한 추가 설정
          js.context.callMethod('eval', [
            '''
            if (window.webkitSpeechRecognition) {
              window.webkitSpeechRecognition.prototype.constructor.prototype.grammars = null;
              window.webkitSpeechRecognition.prototype.constructor.prototype.serviceURI = null;
            }
            
            // 음성 인식 감도 향상 설정
            if (window.speechSynthesis && window.speechSynthesis.getVoices) {
              // 음성 합성 볼륨을 통한 마이크 감도 간접 조정
              window.speechSynthesis.volume = 1.0;
            }
          '''
          ]);

          // 이벤트 리스너 설정
          _webSpeechRecognition!.onResult.listen((event) {
            print('웹 음성 인식 결과 수신: ${event.results}');
            if (event.results!.isNotEmpty) {
              final result = event.results!.last;
              // SpeechRecognitionResult의 첫 번째 alternative 접근
              final length = result.length;
              if (length != null && length > 0) {
                final alternative = result.item(0);
                final transcript = alternative.transcript;
                print('인식된 텍스트: $transcript');

                setState(() {
                  _recognizedText = transcript ?? '';
                  _lastWords = transcript ?? '';
                });

                // 최종 결과만 처리하여 중복 방지
                if (result.isFinal == true) {
                  print('최종 결과 처리');
                  _processRecognizedText(_recognizedText);
                  // 연속 모드이므로 음성 인식을 중지하지 않음
                  print('웹 연속 모드 - 음성 인식 계속 유지');
                } else if (!_isSpeechProcessing &&
                    _recognizedText.length > 3 &&
                    _recognizedText.contains(RegExp(r'\d'))) {
                  // 중간 결과 빠른 처리 (처리 중이 아닐 때만) - 길이 임계값 증가
                  print('중간 결과 빠른 처리: $_recognizedText');
                  _processRecognizedTextFast(_recognizedText);
                }
              }
            }
          });

          _webSpeechRecognition!.onError.listen((event) {
            print('웹 음성 인식 오류: ${event.error}');
            setState(() {
              _isListening = false;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('음성 인식 오류: ${event.error}'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: const Color(0xFFCE9178),
                ),
              );
            }
          });

          _webSpeechRecognition!.onEnd.listen((event) {
            print('웹 음성 인식 종료');
            // 연속 모드를 위해 자동으로 다시 시작
            if (_isListening && mounted) {
              print('웹 연속 모드 - 음성 인식 자동 재시작');
              Future.delayed(const Duration(milliseconds: 100), () {
                if (_isListening && mounted && _webSpeechRecognition != null) {
                  try {
                    _webSpeechRecognition!.start();
                  } catch (e) {
                    print('웹 음성 인식 재시작 실패: $e');
                    setState(() {
                      _isListening = false;
                    });
                  }
                }
              });
            } else {
              setState(() {
                _isListening = false;
              });
            }
          });

          _webSpeechAvailable = true;
          _speechAvailable = true;
          print('웹 음성 인식 초기화 완료!');

          // 초기화 성공 메시지 제거 (팝업 없이 조용히 처리)
        }
      } else {
        print('Web Speech API를 지원하지 않는 브라우저');
        _webSpeechAvailable = false;
        _speechAvailable = false;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '이 브라우저는 음성 인식을 지원하지 않습니다. Chrome, Edge, 또는 Safari를 사용해주세요.'),
              duration: Duration(seconds: 4),
              backgroundColor: Color(0xFFCE9178),
            ),
          );
        }
      }
    } catch (e) {
      print('웹 음성 인식 초기화 오류: $e');
      _webSpeechAvailable = false;
      _speechAvailable = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('음성 인식 초기화 실패: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFFCE9178),
          ),
        );
      }
    }
  }

  // 모바일 전용 음성 인식 초기화
  Future<void> _initMobileSpeech() async {
    print('모바일 음성 인식 초기화 시작...');
    try {
      _speech = stt.SpeechToText();
      print('SpeechToText 객체 생성 완료');

      _speechEnabled = await _speech.initialize(
        onStatus: (val) {
          print('음성 인식 상태 변경: $val');
          if (val == 'done' || val == 'notListening') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (val) {
          print('음성 인식 오류 발생: $val');
          setState(() {
            _isListening = false;
          });
        },
        debugLogging: true, // 디버깅 로그 활성화
      );

      _speechAvailable = _speechEnabled;
      print('모바일 음성 인식 초기화 완료 - 사용 가능: $_speechAvailable');

      if (!_speechAvailable) {
        print('경고: 음성 인식을 사용할 수 없습니다. 권한을 확인해주세요.');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('음성 인식을 사용하려면 마이크 권한을 허용해주세요.'),
              duration: Duration(seconds: 3),
              backgroundColor: Color(0xFFCE9178),
            ),
          );
        }
      }
    } catch (e) {
      print('모바일 음성 인식 초기화 중 오류: $e');
      _speechAvailable = false;
      _speechEnabled = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('음성 인식 초기화 실패: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFFCE9178),
          ),
        );
      }
    }
  }

  // 음성 인식 시작
  void _startListening() async {
    print('음성 인식 시작 버튼 클릭됨');
    print(
        '현재 상태 - _speechEnabled: $_speechEnabled, _speechAvailable: $_speechAvailable');

    // 음성 인식 시작 시 처리 플래그 및 카운터 리셋
    _isSpeechProcessing = false;
    _speechProcessCount = 0;
    _lastProcessedText = null;
    _processedTexts.clear(); // 처리된 텍스트 집합 초기화
    _lastLineDrawTime = null;

    if (!_speechAvailable) {
      print('음성 인식을 사용할 수 없음 - 재초기화 시도');
      await _initSpeech();

      if (!_speechAvailable) {
        print('재초기화 후에도 음성 인식 사용 불가');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('음성 인식을 사용할 수 없습니다. 브라우저 설정을 확인해주세요.'),
              duration: Duration(seconds: 3),
              backgroundColor: Color(0xFFCE9178),
            ),
          );
        }
        return;
      }
    }

    if (kIsWeb) {
      await _startWebListening();
    } else {
      await _startMobileListening();
    }
  }

  // 웹 전용 음성 인식 시작
  Future<void> _startWebListening() async {
    print('웹 음성 인식 시작 중...');

    try {
      // 마이크 권한 및 감도 설정
      try {
        final mediaStream =
            await html.window.navigator.mediaDevices?.getUserMedia({
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': false, // 노이즈 억제 끄기로 감도 향상
            'autoGainControl': true,
            'sampleRate': 44100,
            'channelCount': 1,
          },
        });
        print('마이크 권한 허용됨 (감도 향상 설정)');

        if (mediaStream != null) {
          mediaStream.getTracks().forEach((track) => track.stop());
        }
      } catch (e) {
        print('고급 마이크 설정 실패, 기본 설정으로 진행: $e');
      }

      final userAgent = html.window.navigator.userAgent;

      // Safari에서는 webkit 접두사 사용
      if (userAgent.contains('Safari') && !userAgent.contains('Chrome')) {
        print('Safari에서 webkit 음성 인식 시작');
        await _startSafariListening();
      } else if (_webSpeechRecognition != null && _webSpeechAvailable) {
        print('표준 웹 음성 인식 시작');
        _webSpeechRecognition!.start();

        setState(() {
          _isListening = true;
          _recognizedText = '';
          _lastWords = '';
        });

        print('웹 음성 인식 시작됨 - 상태: $_isListening');

        // 음성 인식 시작 메시지 제거 (팝업 없이 조용히 처리)
      } else {
        print('웹 음성 인식 객체가 없음');
        throw Exception('웹 음성 인식을 사용할 수 없습니다.');
      }
    } catch (e) {
      print('웹 음성 인식 시작 중 오류: $e');
      setState(() {
        _isListening = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('음성 인식 시작 실패: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFFCE9178),
          ),
        );
      }
    }
  }

  // Safari 전용 음성 인식 시작
  Future<void> _startSafariListening() async {
    print('Safari webkit 음성 인식 시작');

    try {
      // JavaScript 코드를 직접 실행하여 음성 인식 처리
      js.context.callMethod('eval', [
        '''
        window.safariSpeechRecognition = new webkitSpeechRecognition();
        window.safariSpeechRecognition.lang = 'ko-KR';
        window.safariSpeechRecognition.continuous = true;
        window.safariSpeechRecognition.interimResults = true;
        window.safariSpeechRecognition.maxAlternatives = 3; // 대안 결과 증가
        
        // 감도 향상을 위한 추가 설정
        try {
          window.safariSpeechRecognition.grammars = null;
          window.safariSpeechRecognition.serviceURI = null;
          
          // Safari에서 음성 인식 감도 향상
          if (window.speechSynthesis && window.speechSynthesis.getVoices) {
            window.speechSynthesis.volume = 1.0;
          }
          
          // 추가 Safari 최적화
          window.safariSpeechRecognition.sensitivity = 0.7; // 감도 설정 (0.0 ~ 1.0)
        } catch(e) {
          console.log('Safari 추가 설정 실패:', e);
        }
        
        console.log('Safari 음성 인식 설정 완료');
        
        window.safariSpeechRecognition.onresult = function(event) {
          console.log('Safari 음성 인식 결과:', event);
          
          var results = event.results;
          var lastResult = results[results.length - 1];
          var transcript = lastResult[0].transcript;
          var isFinal = lastResult.isFinal;
          
          console.log('Safari 인식된 텍스트:', transcript);
          console.log('Safari 최종 결과:', isFinal);
          
          // Dart로 결과 전달
          window.dartSafariSpeechResult(transcript, isFinal);
        };
        
        window.safariSpeechRecognition.onerror = function(event) {
          console.log('Safari 음성 인식 오류:', event.error);
          window.dartSafariSpeechError(event.error);
        };
        
        window.safariSpeechRecognition.onend = function(event) {
          console.log('Safari 음성 인식 종료');
          window.dartSafariSpeechEnd();
        };
        
        window.safariSpeechRecognition.onstart = function(event) {
          console.log('Safari 음성 인식 시작');
          window.dartSafariSpeechStart();
        };
        
        window.safariSpeechRecognition.onspeechstart = function(event) {
          console.log('Safari 음성 감지 시작');
        };
        
        window.safariSpeechRecognition.onaudiostart = function(event) {
          console.log('Safari 오디오 입력 시작');
        };
      '''
      ]);

      // Dart 콜백 함수들 등록
      js.context['dartSafariSpeechResult'] =
          js.allowInterop((String transcript, bool isFinal) {
        print('Dart 콜백 - Safari 음성 결과: $transcript, 최종: $isFinal');

        setState(() {
          _recognizedText = transcript;
          _lastWords = transcript;
        });

        // 최종 결과만 처리하여 중복 방지
        if (isFinal) {
          print('Safari 최종 결과 처리 시작');
          _processRecognizedText(transcript);
          // 연속 모드이므로 음성 인식을 중지하지 않음
          print('Safari 연속 모드 - 음성 인식 계속 유지');
        } else if (!_isSpeechProcessing &&
            transcript.length > 3 &&
            transcript.contains(RegExp(r'\d'))) {
          // 중간 결과 빠른 처리 (처리 중이 아닐 때만) - 길이 임계값 증가
          print('Safari 중간 결과 빠른 처리: $transcript');
          _processRecognizedTextFast(transcript);
        } else {
          // 짧은 중간 결과는 UI 업데이트만
          print('Safari 중간 결과: $transcript (UI 업데이트만)');
        }
      });

      js.context['dartSafariSpeechError'] = js.allowInterop((String error) {
        print('Dart 콜백 - Safari 음성 오류: $error');
        setState(() {
          _isListening = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('음성 인식 오류: $error'),
              duration: const Duration(seconds: 3),
              backgroundColor: const Color(0xFFCE9178),
            ),
          );
        }
      });

      js.context['dartSafariSpeechEnd'] = js.allowInterop(() {
        print('Dart 콜백 - Safari 음성 인식 종료');
        // 연속 모드를 위해 자동으로 다시 시작
        if (_isListening && mounted) {
          print('Safari 연속 모드 - 음성 인식 자동 재시작');
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_isListening && mounted) {
              try {
                js.context.callMethod('eval', [
                  'window.safariSpeechRecognition && window.safariSpeechRecognition.start();'
                ]);
              } catch (e) {
                print('Safari 음성 인식 재시작 실패: $e');
                setState(() {
                  _isListening = false;
                });
              }
            }
          });
        } else {
          setState(() {
            _isListening = false;
          });
        }
      });

      js.context['dartSafariSpeechStart'] = js.allowInterop(() {
        print('Dart 콜백 - Safari 음성 인식 시작');
        setState(() {
          _isListening = true;
          _recognizedText = '';
          _lastWords = '';
        });
      });

      // 음성 인식 시작
      js.context
          .callMethod('eval', ['window.safariSpeechRecognition.start();']);

      print('Safari 음성 인식 시작 요청 완료');

      // Safari 음성 인식 시작 메시지 제거 (팝업 없이 조용히 처리)
    } catch (e) {
      print('Safari 음성 인식 시작 실패: $e');
      setState(() {
        _isListening = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Safari 음성 인식 시작 실패: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFFCE9178),
          ),
        );
      }
    }
  }

  // 모바일 전용 음성 인식 시작
  Future<void> _startMobileListening() async {
    print('모바일 음성 인식 시작 중...');

    try {
      print('음성 인식 listen() 호출 시작...');
      await _speech.listen(
        onResult: (val) {
          print('음성 인식 결과 콜백 호출됨: ${val.recognizedWords}');
          setState(() {
            _lastWords = val.recognizedWords;
            _recognizedText = val.recognizedWords;
            print('음성 인식 결과 업데이트: $_recognizedText');

            // 최종 결과만 처리하여 중복 방지
            if (val.finalResult) {
              print('최종 결과 처리 시작');
              _processRecognizedText(_recognizedText);
              // 연속 모드를 위해 잠시 후 다시 시작
              print('모바일 연속 모드 - 음성 인식 재시작 예약');
              Future.delayed(const Duration(milliseconds: 100), () {
                if (_isListening && mounted) {
                  _startMobileListening();
                }
              });
            } else if (!_isSpeechProcessing &&
                _recognizedText.length > 3 &&
                _recognizedText.contains(RegExp(r'\d'))) {
              // 중간 결과 빠른 처리 (처리 중이 아닐 때만) - 길이 임계값 증가
              print('모바일 중간 결과 빠른 처리: $_recognizedText');
              _processRecognizedTextFast(_recognizedText);
            }
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(milliseconds: 1500), // 감도 향상을 위해 1.5초로 단축
        partialResults: true,
        localeId: 'ko_KR', // 한국어 설정
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation, // 감도 향상을 위해 dictation 모드 사용
        onSoundLevelChange: (level) {
          // 음성 레벨 모니터링으로 감도 확인
          print('음성 레벨: $level');
        },
      );

      print('음성 인식 listen() 호출 완료 - 상태를 listening으로 변경');
      setState(() {
        _isListening = true;
      });
    } catch (e) {
      print('모바일 음성 인식 시작 중 오류: $e');
      setState(() {
        _isListening = false;
      });
    }
  }

  // 음성 인식 중지
  void _stopListening() async {
    print('음성 인식 중지 버튼 클릭됨');

    try {
      if (kIsWeb) {
        final userAgent = html.window.navigator.userAgent;

        // Safari에서는 webkit 객체 사용
        if (userAgent.contains('Safari') && !userAgent.contains('Chrome')) {
          print('Safari 음성 인식 중지');
          try {
            js.context.callMethod('eval', [
              'window.safariSpeechRecognition && window.safariSpeechRecognition.stop();'
            ]);
          } catch (e) {
            print('Safari 음성 인식 중지 실패: $e');
          }
        } else if (_webSpeechRecognition != null) {
          print('웹 음성 인식 중지');
          _webSpeechRecognition!.stop();
        }
      } else {
        print('모바일 음성 인식 중지');
        await _speech.stop();
      }

      setState(() {
        _isListening = false;
      });

      print('음성 인식 중지됨');
    } catch (e) {
      print('음성 인식 중지 중 오류: $e');
      setState(() {
        _isListening = false;
      });
    }
  }

  // 빠른 음성 처리 (중간 결과용) - 강화된 중복 방지
  void _processRecognizedTextFast(String text) {
    print('빠른 음성 텍스트 처리: $text');

    // 기본 중복 방지
    if (_isSpeechProcessing) {
      print('음성 처리 중 - 빠른 처리 무시');
      return;
    }

    final now = DateTime.now();
    final trimmedText = text.trim();

    // 이미 처리된 텍스트인지 확인
    if (_processedTexts.contains(trimmedText)) {
      print('이미 처리된 텍스트 - 무시: $trimmedText');
      return;
    }

    // 최근 선 그리기 후 너무 빠른 호출 방지 (1초 이내)
    if (_lastLineDrawTime != null &&
        now.difference(_lastLineDrawTime!).inMilliseconds < 500) {
      print(
          '최근 선 그리기 후 500ms 이내 - 빠른 처리 무시 (${now.difference(_lastLineDrawTime!).inMilliseconds}ms)');
      return;
    }

    // 시간 간격 기반 분리 처리 (성능 최적화: 1500ms → 800ms)
    final speechGapThreshold = 800; // 반응 속도 개선을 위해 단축
    bool isNewSpeechSession = false;

    if (_lastSpeechProcessTime == null ||
        now.difference(_lastSpeechProcessTime!).inMilliseconds >=
            speechGapThreshold) {
      isNewSpeechSession = true;
      print(
          '새로운 음성 세션 시작 (${_lastSpeechProcessTime == null ? '처음' : '${now.difference(_lastSpeechProcessTime!).inMilliseconds}ms 경과'})');
      // 새 세션 시작 시 처리된 텍스트 집합 초기화
      _processedTexts.clear();
    }

    // 새로운 세션이 아니고 동일한 텍스트면 무시
    if (!isNewSpeechSession && _lastProcessedText == trimmedText) {
      print('동일 세션 내 동일한 텍스트 중복 처리 방지: $text');
      return;
    }

    // 새로운 세션이 아니고 너무 빠른 호출이면 무시 (성능 최적화: 800ms → 400ms)
    if (!isNewSpeechSession &&
        _lastSpeechProcessTime != null &&
        now.difference(_lastSpeechProcessTime!).inMilliseconds < 400) {
      print(
          '동일 세션 내 빠른 처리 400ms 이내 중복 호출 무시 (${now.difference(_lastSpeechProcessTime!).inMilliseconds}ms)');
      return;
    }

    // 텍스트 길이 검증 (감도 향상을 위해 최소 길이 줄임)
    if (trimmedText.length < 1 || trimmedText.length > 30) {
      print('텍스트 길이 부적절 - 무시: ${trimmedText.length}');
      return;
    }

    // 빠른 숫자 검증 - 숫자가 포함되어 있는지 먼저 확인
    if (!RegExp(r'\d').hasMatch(trimmedText) &&
        !RegExp(r'[일이삼사오육칠팔구십백천만영공하나둘셋넷다섯여섯일곱여덟아홉열스무서른마흔쉰예순일흔여든아흔]')
            .hasMatch(trimmedText)) {
      print('숫자 관련 텍스트가 없음 - 빠른 무시: $trimmedText');
      return;
    }

    // 한국어 숫자 단어를 숫자로 변환
    String convertedText = _convertKoreanNumbersToDigits(trimmedText);
    print('빠른 처리 - 변환된 텍스트: $convertedText');

    // 숫자 추출
    RegExp numberRegex = RegExp(r'\b(\d+(?:\.\d+)?)\b');
    final matches = numberRegex.allMatches(convertedText);

    if (matches.isNotEmpty) {
      // 유효한 숫자만 선택 (1-10000 범위)
      double? bestNumber;
      for (final match in matches) {
        final numberStr = match.group(1);
        final number = double.tryParse(numberStr ?? '');
        if (number != null && number >= 1 && number <= 10000) {
          if (bestNumber == null || number > bestNumber) {
            bestNumber = number;
          }
        }
      }

      if (bestNumber != null) {
        print('빠른 처리 - 추출된 숫자: $bestNumber (새로운 세션: $isNewSpeechSession)');

        setState(() {
          _isSpeechProcessing = true;
          _isVoiceProcessing = true; // UI 로딩 상태 활성화
        });

        _lastProcessedText = trimmedText;
        _lastSpeechProcessTime = now;
        _lastLineDrawTime = now; // 선 그리기 시간 기록

        // 처리된 텍스트를 집합에 추가 (메모리 최적화: 최대 10개까지만 유지)
        _processedTexts.add(trimmedText);
        if (_processedTexts.length > 10) {
          _processedTexts.clear();
          _processedTexts.add(trimmedText);
        }

        // 선택된 선이 있다면 해당 선의 길이를 변경
        if (selectedLineIndex >= 0 && selectedLineIndex < lines.length) {
          print(
              '빠른 처리 - 선택된 선 길이 변경: 인덱스 $selectedLineIndex, 새 길이 $bestNumber');
          _resizeSelectedLine(bestNumber);
        } else {
          print('빠른 처리 - 유효한 숫자로 선 그리기');
          if (lastDirection != null) {
            print('빠른 처리 - 마지막 방향($lastDirection)으로 선 그리기');
            drawLineWithDistance(lastDirection!, bestNumber);
          } else {
            print('빠른 처리 - 위쪽 방향으로 선 그리기');
            drawLineWithDistance('Up', bestNumber);
          }
        }

        // 성공 메시지 제거 (팝업 없이 조용히 처리)

        // 자동 음성 모드 제거 - 사용자가 직접 음성 인식을 제어하도록 변경

        // 즉시 처리 가능한 경우 지연 시간 더 단축 (300ms → 200ms)
        Future.delayed(const Duration(milliseconds: 200), () {
          setState(() {
            _isSpeechProcessing = false;
            _isVoiceProcessing = false; // UI 로딩 상태 비활성화
          });
        });
      }
    }
  }

  // 인식된 텍스트에서 숫자 추출 및 처리 - 강화된 중복 방지
  void _processRecognizedText(String text) {
    print('음성 텍스트 처리: $text');

    // 중복 처리 방지 (플래그 기반)
    if (_isSpeechProcessing) {
      print('음성 처리 중 - 중복 호출 무시');
      return;
    }

    final now = DateTime.now();
    final trimmedText = text.trim();

    // 텍스트 길이 검증 (감도 향상)
    if (trimmedText.isEmpty || trimmedText.length > 40) {
      print('텍스트 길이 부적절 - 무시: ${trimmedText.length}');
      return;
    }

    // 이미 처리된 텍스트인지 확인
    if (_processedTexts.contains(trimmedText)) {
      print('이미 처리된 텍스트 - 무시: $trimmedText');
      return;
    }

    // 최근 선 그리기 후 너무 빠른 호출 방지 (성능 최적화: 1000ms → 500ms)
    if (_lastLineDrawTime != null &&
        now.difference(_lastLineDrawTime!).inMilliseconds < 500) {
      print(
          '최근 선 그리기 후 500ms 이내 - 일반 처리 무시 (${now.difference(_lastLineDrawTime!).inMilliseconds}ms)');
      return;
    }

    // 시간 간격 기반 분리 처리 (성능 최적화: 1500ms → 800ms)
    final speechGapThreshold = 800; // 반응 속도 개선을 위해 단축
    bool isNewSpeechSession = false;

    if (_lastSpeechProcessTime == null ||
        now.difference(_lastSpeechProcessTime!).inMilliseconds >=
            speechGapThreshold) {
      isNewSpeechSession = true;
      print(
          '새로운 음성 세션 시작 (${_lastSpeechProcessTime == null ? '처음' : '${now.difference(_lastSpeechProcessTime!).inMilliseconds}ms 경과'})');
      // 새 세션 시작 시 처리된 텍스트 집합 초기화
      _processedTexts.clear();
    }

    // 새로운 세션이 아니고 동일한 텍스트면 무시
    if (!isNewSpeechSession && _lastProcessedText == trimmedText) {
      print('동일 세션 내 동일한 텍스트 중복 처리 방지: $trimmedText');
      return;
    }

    // 새로운 세션이 아니고 너무 빠른 호출이면 무시 (성능 최적화: 1000ms → 500ms)
    if (!isNewSpeechSession &&
        _lastSpeechProcessTime != null &&
        now.difference(_lastSpeechProcessTime!).inMilliseconds < 500) {
      print(
          '동일 세션 내 음성 처리 500ms 이내 중복 호출 무시 (${now.difference(_lastSpeechProcessTime!).inMilliseconds}ms)');
      return;
    }

    setState(() {
      _isSpeechProcessing = true;
      _isVoiceProcessing = true; // UI 로딩 상태 활성화
    });

    _lastSpeechProcessTime = now;
    _lastProcessedText = trimmedText;
    _lastLineDrawTime = now; // 선 그리기 시간 기록

    // 처리된 텍스트를 집합에 추가 (메모리 최적화: 최대 10개까지만 유지)
    _processedTexts.add(trimmedText);
    if (_processedTexts.length > 10) {
      _processedTexts.clear();
      _processedTexts.add(trimmedText);
    }

    // 한국어 숫자 단어를 숫자로 변환
    final processedText = _convertKoreanNumbersToDigits(trimmedText);
    print('변환된 텍스트: $processedText');

    // 숫자 추출 (개선된 버전 - 더 정확한 패턴)
    final numberRegex = RegExp(r'\b(\d+(?:\.\d+)?)\b');
    final matches = numberRegex.allMatches(processedText);

    if (matches.isNotEmpty) {
      // 유효한 숫자만 선택 (1-10000 범위)
      double? bestNumber;
      for (final match in matches) {
        final numberStr = match.group(1);
        final number = double.tryParse(numberStr ?? '');
        if (number != null && number >= 1 && number <= 10000) {
          // 가장 적절한 숫자 선택 (10-500 범위 우선, 그 다음 1-10000)
          if (bestNumber == null) {
            bestNumber = number;
          } else if (number >= 10 &&
              number <= 500 &&
              (bestNumber < 10 || bestNumber > 500)) {
            bestNumber = number;
          } else if (number >= 10 &&
              number <= 500 &&
              bestNumber >= 10 &&
              bestNumber <= 500) {
            bestNumber = number > bestNumber ? number : bestNumber;
          }
        }
      }

      if (bestNumber != null) {
        print('추출된 숫자: $bestNumber');

        // 선택된 선이 있다면 해당 선의 길이를 변경
        if (selectedLineIndex >= 0 && selectedLineIndex < lines.length) {
          print('선택된 선 길이 변경: 인덱스 $selectedLineIndex, 새 길이 $bestNumber');
          _resizeSelectedLine(bestNumber);
        }
        // 현재 인라인 입력이 활성화되어 있다면 해당 입력 필드에 숫자 입력
        else if (showInlineInput) {
          print('인라인 입력 활성화 상태 - 숫자 입력 및 선 그리기');
          setState(() {
            inlineController.text = bestNumber.toString();
            inlineController.selection = TextSelection.fromPosition(
              TextPosition(offset: inlineController.text.length),
            );
          });

          // 자동으로 선 그리기 실행
          WidgetsBinding.instance.addPostFrameCallback((_) {
            confirmInlineInput();
          });
        } else {
          // 인라인 입력이 비활성화되어 있다면 자동으로 마지막 방향으로 선 그리기
          print('인라인 입력 비활성화 상태 - 자동으로 마지막 방향으로 선 그리기');

          // 마지막 방향이 있다면 해당 방향으로 선 그리기
          if (lastDirection != null) {
            print('마지막 방향: $lastDirection 으로 $bestNumber 픽셀 선 그리기');

            // 마지막 방향으로 선 그리기
            drawLineWithDistance(lastDirection!, bestNumber);

            // 성공 메시지 제거 (팝업 없이 조용히 처리)
          } else {
            // 마지막 방향이 없다면 위쪽으로 기본 설정
            print('마지막 방향이 없음 - 위쪽으로 기본 설정하여 선 그리기');
            drawLineWithDistance('Up', bestNumber);

            // 성공 메시지 제거 (팝업 없이 조용히 처리)
          }
        }
      }
    } else {
      print('텍스트에서 유효한 숫자를 찾을 수 없음');
      // 에러 메시지는 너무 자주 나오지 않도록 제한
      if (_speechProcessCount % 3 == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('1-10000 사이의 숫자를 명확히 말해주세요.'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFFCE9178),
          ),
        );
      }
    }

    _speechProcessCount++;

    // 자동 음성 모드 제거 - 사용자가 직접 음성 인식을 제어하도록 변경

    // 처리 완료 후 플래그 리셋 (성능 최적화: 1000ms → 300ms)
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _isSpeechProcessing = false;
        _isVoiceProcessing = false; // UI 로딩 상태 비활성화
      });
      print('음성 처리 완료 - 플래그 리셋');
    });
  }

  // 한국어 숫자 단어를 숫자로 변환 (개선된 버전)
  String _convertKoreanNumbersToDigits(String text) {
    print('원본 텍스트: $text');

    // 텍스트를 소문자로 변환하고 불필요한 문자 제거
    String processedText = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w가-힣]'), '') // 특수문자 제거
        .replaceAll(' ', '');
    print('전처리된 텍스트: $processedText');

    // 복합 숫자 먼저 처리 (긴 단어부터 - 순서 중요)
    final complexNumbers = {
      // 1000 이상 (천 단위 추가)
      '구천구백구십구': '9999', '구천구백구십': '9990', '구천구백': '9900',
      '구천팔백구십': '9890', '구천팔백': '9800', '구천칠백': '9700',
      '구천육백': '9600', '구천오백': '9500', '구천사백': '9400',
      '구천삼백': '9300', '구천이백': '9200', '구천일백': '9100', '구천': '9000',

      '팔천구백구십구': '8999', '팔천구백구십': '8990', '팔천구백': '8900',
      '팔천팔백': '8800', '팔천칠백': '8700', '팔천육백': '8600',
      '팔천오백': '8500', '팔천사백': '8400', '팔천삼백': '8300',
      '팔천이백': '8200', '팔천일백': '8100', '팔천': '8000',

      '칠천구백': '7900', '칠천팔백': '7800', '칠천칠백': '7700',
      '칠천육백': '7600', '칠천오백': '7500', '칠천사백': '7400',
      '칠천삼백': '7300', '칠천이백': '7200', '칠천일백': '7100', '칠천': '7000',

      '육천구백': '6900', '육천팔백': '6800', '육천칠백': '6700',
      '육천육백': '6600', '육천오백': '6500', '육천사백': '6400',
      '육천삼백': '6300', '육천이백': '6200', '육천일백': '6100', '육천': '6000',

      '오천구백': '5900', '오천팔백': '5800', '오천칠백': '5700',
      '오천육백': '5600', '오천오백': '5500', '오천사백': '5400',
      '오천삼백': '5300', '오천이백': '5200', '오천일백': '5100', '오천': '5000',

      '사천구백': '4900', '사천팔백': '4800', '사천칠백': '4700',
      '사천육백': '4600', '사천오백': '4500', '사천사백': '4400',
      '사천삼백': '4300', '사천이백': '4200', '사천일백': '4100', '사천': '4000',

      '삼천구백': '3900', '삼천팔백': '3800', '삼천칠백': '3700',
      '삼천육백': '3600', '삼천오백': '3500', '삼천사백': '3400',
      '삼천삼백': '3300', '삼천이백': '3200', '삼천일백': '3100', '삼천': '3000',

      '이천구백': '2900', '이천팔백': '2800', '이천칠백': '2700',
      '이천육백': '2600', '이천오백': '2500', '이천사백': '2400',
      '이천삼백': '2300', '이천이백': '2200', '이천일백': '2100', '이천': '2000',

      '일천구백구십구': '1999', '일천구백구십': '1990', '일천구백': '1900',
      '일천팔백구십': '1890', '일천팔백': '1800', '일천칠백': '1700',
      '일천육백': '1600', '일천오백': '1500', '일천사백': '1400',
      '일천삼백': '1300', '일천이백': '1200', '일천일백': '1100', '일천': '1000',

      // 천 단위 (간단한 형태)
      '천구백구십구': '1999', '천구백구십': '1990', '천구백': '1900',
      '천팔백구십': '1890', '천팔백': '1800', '천칠백': '1700',
      '천육백': '1600', '천오백': '1500', '천사백': '1400',
      '천삼백': '1300', '천이백': '1200', '천일백': '1100', '천': '1000',

      // 100 이상 (기존)
      '구백구십구': '999', '구백구십': '990', '구백': '900',
      '팔백구십': '890', '팔백': '800',
      '칠백구십': '790', '칠백': '700',
      '육백구십': '690', '육백': '600',
      '오백구십': '590', '오백': '500',
      '사백구십': '490', '사백': '400',
      '삼백구십': '390', '삼백': '300',
      '이백구십': '290', '이백': '200',
      '일백구십': '190', '일백': '100',
      '백구십': '190', '백': '100',

      // 90-99
      '아흔아홉': '99', '아흔여덟': '98', '아흔일곱': '97', '아흔여섯': '96',
      '아흔다섯': '95', '아흔넷': '94', '아흔셋': '93', '아흔둘': '92',
      '아흔하나': '91', '아흔': '90',

      // 80-89
      '여든아홉': '89', '여든여덟': '88', '여든일곱': '87', '여든여섯': '86',
      '여든다섯': '85', '여든넷': '84', '여든셋': '83', '여든둘': '82',
      '여든하나': '81', '여든': '80',

      // 70-79
      '일흔아홉': '79', '일흔여덟': '78', '일흔일곱': '77', '일흔여섯': '76',
      '일흔다섯': '75', '일흔넷': '74', '일흔셋': '73', '일흔둘': '72',
      '일흔하나': '71', '일흔': '70',

      // 60-69
      '예순아홉': '69', '예순여덟': '68', '예순일곱': '67', '예순여섯': '66',
      '예순다섯': '65', '예순넷': '64', '예순셋': '63', '예순둘': '62',
      '예순하나': '61', '예순': '60',

      // 50-59
      '쉰아홉': '59', '쉰여덟': '58', '쉰일곱': '57', '쉰여섯': '56',
      '쉰다섯': '55', '쉰넷': '54', '쉰셋': '53', '쉰둘': '52',
      '쉰하나': '51', '쉰': '50',

      // 40-49
      '마흔아홉': '49', '마흔여덟': '48', '마흔일곱': '47', '마흔여섯': '46',
      '마흔다섯': '45', '마흔넷': '44', '마흔셋': '43', '마흔둘': '42',
      '마흔하나': '41', '마흔': '40',

      // 30-39
      '서른아홉': '39', '서른여덟': '38', '서른일곱': '37', '서른여섯': '36',
      '서른다섯': '35', '서른넷': '34', '서른셋': '33', '서른둘': '32',
      '서른하나': '31', '서른': '30',

      // 20-29
      '스무아홉': '29', '스무여덟': '28', '스무일곱': '27', '스무여섯': '26',
      '스무다섯': '25', '스무넷': '24', '스무셋': '23', '스무둘': '22',
      '스무하나': '21', '스무': '20',

      // 10-19 (한자어)
      '십구': '19', '십팔': '18', '십칠': '17', '십육': '16', '십오': '15',
      '십사': '14', '십삼': '13', '십이': '12', '십일': '11', '십': '10',

      // 기타 단위
      '열': '10',
    };

    // 복합 숫자 변환 (긴 것부터)
    final sortedComplexNumbers = complexNumbers.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in sortedComplexNumbers) {
      processedText = processedText.replaceAll(entry.key, entry.value);
    }

    // 기본 숫자 변환
    final basicNumbers = {
      // 한국어 숫자 (고유어)
      '아홉': '9', '여덟': '8', '일곱': '7', '여섯': '6', '다섯': '5',
      '넷': '4', '셋': '3', '둘': '2', '하나': '1', '영': '0',

      // 한국어 숫자 (한자어)
      '구': '9', '팔': '8', '칠': '7', '육': '6', '오': '5',
      '사': '4', '삼': '3', '이': '2', '일': '1', '공': '0',

      // 자주 잘못 인식되는 변형들
      '나인': '9', '에이트': '8', '세븐': '7', '식스': '6', '파이브': '5',
      '포': '4', '쓰리': '3', '투': '2', '원': '1', '제로': '0',

      // 발음 변형
      '구우': '9', '팔팔': '8', '칠칠': '7', '육육': '6', '오오': '5',
      '네': '4', '세': '3', '두': '2', '한': '1', '빵': '0',
    };

    // 기본 숫자 변환
    basicNumbers.forEach((korean, digit) {
      processedText = processedText.replaceAll(korean, digit);
    });

    // 잘못 인식될 수 있는 단어들 처리 (더 정확하게)
    final corrections = {
      // 음성 인식 오류 보정
      '쉬': '6', '치': '7', '파': '8', '가': '9',
      '시': '10', '씨': '3', '피': '5', '티': '2',
      '지': '2', '비': '3', '디': '2', '키': '7',
      '리': '2', '미': '3', '니': '2', '히': '7',
    };

    corrections.forEach((wrong, correct) {
      // 단어 경계에서만 변환 (부분 문자열 오변환 방지)
      processedText =
          processedText.replaceAll(RegExp(r'\b' + wrong + r'\b'), correct);
    });

    print('최종 변환된 텍스트: $processedText');
    return processedText;
  }

  @override
  void dispose() {
    _linesSubscription?.cancel();
    _circlesSubscription?.cancel();
    _currentPointSubscription?.cancel();
    _metadataSubscription?.cancel();
    _focusNode.dispose();
    inlineController.dispose();
    inlineFocus.dispose();
    super.dispose();
  }

  void saveState() {
    linesHistory.add({
      'lines': lines.map((line) => line.copy()).toList(),
      'circles': circles.map((circle) => circle.copy()).toList(),
      'currentPoint': currentPoint,
    });

    if (linesHistory.length > 20) {
      linesHistory.removeAt(0);
    }
  }

  void undo() {
    if (linesHistory.isEmpty) return;

    final lastState = linesHistory.removeLast();
    setState(() {
      lines = (lastState['lines'] as List<Line>)
          .map((line) => line.copy())
          .toList();
      circles = (lastState['circles'] as List<Circle>)
          .map((circle) => circle.copy())
          .toList();
      currentPoint = lastState['currentPoint'] as Offset;
    });
    _updateFirebase();
  }

  void reset() {
    if (lines.isEmpty &&
        circles.isEmpty &&
        viewScale == 0.3 &&
        viewOffset == const Offset(500, 500)) return;

    // 확인 팝업 표시
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          title: const Text(
            '초기화 확인',
            style: TextStyle(
              color: Color(0xFFE6EDF3),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            '모든 그림을 삭제하고 초기화하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
            style: TextStyle(
              color: Color(0xFFE6EDF3),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 팝업 닫기
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF9CDCFE),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // 팝업 닫기
                // 실제 초기화 실행
                _performReset();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCE9178),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                '초기화',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _performReset() {
    saveState();
    setState(() {
      lines.clear();
      circles.clear();
      currentPoint = const Offset(0, 0);
      selectedLineIndex = -1;
      selectedCircleIndex = -1;
      circleMode = false;
      circleCenter = null;
      viewScale = 0.3;
      viewOffset = const Offset(500, 500);
    });
    _updateFirebase();

    // 초기화 후 뷰 맞춤 자동 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMobile || isTablet) {
        print('모바일/태블릿 초기화 후 - currentPoint 중심 맞춤');
        centerCurrentPoint();
      } else {
        fitViewToDrawing();
      }
    });
  }

  void onDirectionKey(String direction) {
    // 이미 처리 중이면 무시
    if (isProcessingInput) {
      print('onDirectionKey: 이미 처리 중 - 무시');
      return;
    }

    print('onDirectionKey 호출됨: $direction');
    print(
        '현재 상태 - showInlineInput: $showInlineInput, inlineController.text: "${inlineController.text}"');

    // 자동 음성 모드 제거 - 화살표 버튼 누를 때마다 음성 인식 시작하지 않음
    // 성능 향상을 위해 사용자가 명시적으로 음성 버튼을 누를 때만 음성 인식 시작

    setState(() {
      arrowDirection = direction;
      inlineDirection = direction;
      lastDirection = direction; // 방향키 클릭 시 마지막 방향 설정

      // 이미 인라인 입력이 표시 중이고 텍스트가 있다면 바로 실행
      if (showInlineInput && inlineController.text.isNotEmpty) {
        print('인라인 입력이 있음 - 즉시 실행');
        // 즉시 선 그리기 실행
        WidgetsBinding.instance.addPostFrameCallback((_) {
          confirmInlineInput();
        });
      } else {
        print('방향키 설정 완료 - 숫자 입력 대기 중');
        // 방향키만 설정하고 숫자입력창은 표시하지 않음
        // 숫자를 입력할 때 숫자입력창이 나타나도록 함
        showInlineInput = false;
        isProcessingInput = false;
      }
    });

    // 방향키 버튼 클릭 후 포커스 복원
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('메인 포커스 복원');
      _focusNode.requestFocus();
    });
  }

  void drawLineWithDistance(String direction, double distance) {
    print('drawLineWithDistance 호출됨 - 방향: $direction, 거리: $distance');
    print('drawLineWithDistance - isProcessingInput: $isProcessingInput');

    // 이미 confirmInlineInput에서 isProcessingInput이 true로 설정되었으므로
    // 여기서는 추가로 설정하지 않음
    if (!isProcessingInput) {
      print('처리 중 상태가 아님 - 예상치 못한 호출');
      isProcessingInput = true;
    }

    Offset newPoint;
    switch (direction) {
      case 'Up':
        newPoint = Offset(currentPoint.dx, currentPoint.dy + distance);
        break;
      case 'Down':
        newPoint = Offset(currentPoint.dx, currentPoint.dy - distance);
        break;
      case 'Left':
        newPoint = Offset(currentPoint.dx - distance, currentPoint.dy);
        break;
      case 'Right':
        newPoint = Offset(currentPoint.dx + distance, currentPoint.dy);
        break;
      default:
        print('잘못된 방향: $direction');
        isProcessingInput = false;
        return;
    }

    print('새로운 점 계산됨: $newPoint (시작점: $currentPoint)');

    saveState();

    setState(() {
      lines.add(Line(
        start: currentPoint,
        end: newPoint,
        openingType: pendingOpeningType,
      ));
      currentPoint = newPoint;
      pendingOpeningType = null;
      lastDirection = direction; // 마지막 방향 저장
      isProcessingInput = false;
    });

    print('선 추가됨 - 총 선 개수: ${lines.length}');

    _updateFirebase();

    // 모바일/태블릿에서는 새 선이 화면에 보이도록 뷰 조정
    if (isMobile || isTablet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            // currentPoint가 화면에 보이는지 확인하고 필요시 조정
            final currentScreen = _modelToScreen(currentPoint);
            final screenSize = MediaQuery.of(context).size;

            // 화면 경계에서 50px 여백
            const margin = 50.0;
            final needsAdjustment = currentScreen.dx < margin ||
                currentScreen.dx > screenSize.width - margin ||
                currentScreen.dy < margin ||
                currentScreen.dy > screenSize.height - 200 - margin;

            if (needsAdjustment) {
              print('모바일/태블릿: currentPoint가 화면 밖 - 뷰 조정');
              centerCurrentPoint();
            }
          }
        });
      });
    }
  }

  void confirmInlineInput() {
    print('confirmInlineInput 호출됨 - isProcessingInput: $isProcessingInput');

    if (isProcessingInput) {
      print('이미 처리 중 - 중복 호출 방지로 종료');
      return;
    }

    // 즉시 처리 중 상태로 설정하여 중복 호출 방지
    isProcessingInput = true;

    String inputText = inlineController.text.trim();
    print('입력된 텍스트: "$inputText"');

    if (inputText.isEmpty) {
      print('입력 텍스트가 비어있음');
      setState(() {
        showInlineInput = false;
        isProcessingInput = false;
        arrowDirection = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
      return;
    }

    // 간단한 수식 계산 처리
    double? distance;
    if (inputText.contains('+')) {
      final parts = inputText.split('+');
      if (parts.length == 2) {
        final num1 = double.tryParse(parts[0].trim());
        final num2 = double.tryParse(parts[1].trim());
        if (num1 != null && num2 != null) {
          distance = num1 + num2;
        }
      }
    } else if (inputText.contains('-') && inputText.lastIndexOf('-') > 0) {
      final lastIndex = inputText.lastIndexOf('-');
      final num1 = double.tryParse(inputText.substring(0, lastIndex).trim());
      final num2 = double.tryParse(inputText.substring(lastIndex + 1).trim());
      if (num1 != null && num2 != null) {
        distance = num1 - num2;
      }
    } else {
      distance = double.tryParse(inputText);
    }

    print('계산된 거리: $distance');

    if (distance == null || distance <= 0) {
      print('잘못된 거리값: $inputText');
      setState(() {
        showInlineInput = false;
        isProcessingInput = false;
        arrowDirection = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
      return;
    }

    print(
        '현재 상태 - selectedLineIndex: $selectedLineIndex, arrowDirection: $arrowDirection');
    print('inlineDirection: "$inlineDirection"');

    // 원 모드에서 지름 입력
    if (circleMode && circleCenter != null) {
      print('원 생성 모드: 중심점 $circleCenter, 지름 $distance');
      saveState();

      final radius = distance / 2; // 지름을 반지름으로 변환
      circles.add(Circle(
        center: circleCenter!,
        radius: radius,
      ));

      setState(() {
        showInlineInput = false;
        isProcessingInput = false;
        circleMode = false;
        circleCenter = null;
        arrowDirection = null;
        inlineDirection = "";
      });

      _updateFirebase();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
      return;
    }

    if (selectedLineIndex >= 0 && arrowDirection == null) {
      print('선 길이 수정 모드: $selectedLineIndex to length $distance');
      saveState();
      modifyLineLength(selectedLineIndex, distance);
      setState(() {
        showInlineInput = false;
        isProcessingInput = false;
        arrowDirection = null;
        selectedLineIndex = -1; // 수정 후 선택 해제
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
      return;
    }

    // 선 그리기 - inlineDirection이 비어있으면 arrowDirection 사용
    String direction = inlineDirection.isNotEmpty
        ? inlineDirection
        : (arrowDirection ?? 'Right');
    print('선 그리기 시작 - 방향: $direction, 거리: $distance');
    print('현재 점: $currentPoint');

    // isProcessingInput을 여기서 설정하지 않고 drawLineWithDistance에서 처리하도록 함
    drawLineWithDistance(direction, distance);

    setState(() {
      showInlineInput = false;
      arrowDirection = null;
      inlineDirection = "";
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void cancelInlineInput() {
    setState(() {
      showInlineInput = false;
      arrowDirection = null;
      inlineDirection = "";
      isProcessingInput = false;
      inlineController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void onNumberPadKey(String key) {
    if (!showInlineInput && key != 'Del' && key != 'Ent') {
      // 인라인 입력 모드로 전환
      setState(() {
        showInlineInput = true;
        inlineController.text = '';

        if (selectedLineIndex >= 0) {
          // 선택된 선이 있으면 길이 수정 모드
          // 방향키 설정은 그대로 유지
        } else if (arrowDirection != null || inlineDirection.isNotEmpty) {
          // 방향키가 설정되어 있으면 해당 방향으로 새 선 그리기 모드
          print('방향키 설정됨 - 새 선 그리기 모드: $arrowDirection / $inlineDirection');
        } else if (lines.isNotEmpty) {
          // 방향키가 없고 선이 존재하면 마지막 선 수정 모드
          selectedLineIndex = lines.length - 1; // 마지막 선 선택
          arrowDirection = null;
          inlineDirection = "";
        } else {
          // 새 선 그리기 모드 - 기본 방향 설정
          inlineDirection = 'Right';
          arrowDirection = 'Right';
        }
      });
    }

    if (key == 'Del') {
      if (showInlineInput && inlineController.text.isNotEmpty) {
        // 숫자 입력 중이면 백스페이스 기능 (마지막 문자 삭제)
        setState(() {
          final currentText = inlineController.text;
          if (currentText.isNotEmpty) {
            inlineController.text =
                currentText.substring(0, currentText.length - 1);
            inlineController.selection = TextSelection.fromPosition(
              TextPosition(offset: inlineController.text.length),
            );
          }
        });
      } else {
        // 숫자 입력 중이 아니면 선/원 삭제
        if (selectedLineIndex >= 0) {
          // 선택된 선이 있으면 해당 선 삭제
          deleteSelectedLine();
        } else if (selectedCircleIndex >= 0) {
          // 선택된 원이 있으면 해당 원 삭제
          deleteSelectedCircle();
        } else if (lines.isNotEmpty) {
          // 선택된 것이 없고 선이 존재하면 마지막 선 삭제
          print('Del 버튼: 마지막 선 삭제');
          deleteLastLine();
        }
        // 선택된 것도 없고 선도 없으면 아무 동작 안함
      }
    } else if (key == 'Ent') {
      print('Enter 키 눌림 - showInlineInput: $showInlineInput');
      if (showInlineInput) {
        print('인라인 입력 확인 호출');
        confirmInlineInput();
      } else {
        print('인라인 입력 모드로 전환');
        // 인라인 입력이 없는 상태에서 Enter를 누르면 기본 동작
        setState(() {
          showInlineInput = true;
          inlineController.text = '';
          if (inlineDirection.isEmpty && arrowDirection == null) {
            inlineDirection = 'Right';
            arrowDirection = 'Right';
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          inlineFocus.requestFocus();
        });
      }
    } else if (key == '+' ||
        key == '-' ||
        key == '00' ||
        RegExp(r'^[0-9]$').hasMatch(key)) {
      if (showInlineInput) {
        setState(() {
          inlineController.text += key;
        });
        inlineController.selection = TextSelection.fromPosition(
          TextPosition(offset: inlineController.text.length),
        );
      }
    }

    // 포커스 유지
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (showInlineInput) {
        inlineFocus.requestFocus();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  void modifyLineLength(int index, double newLength) {
    if (index < 0 || index >= lines.length) return;

    final line = lines[index];
    final dx = line.end.dx - line.start.dx;
    final dy = line.end.dy - line.start.dy;
    final oldLen = math.sqrt(dx * dx + dy * dy);

    if (oldLen == 0) return;

    final unitX = dx / oldLen;
    final unitY = dy / oldLen;

    final newEnd = Offset(
      line.start.dx + newLength * unitX,
      line.start.dy + newLength * unitY,
    );

    setState(() {
      if (line.isDiagonal) {
        line.end = newEnd;
      } else {
        final oldEnd = line.end;
        final shift = Offset(
          newEnd.dx - line.end.dx,
          newEnd.dy - line.end.dy,
        );

        line.end = newEnd;

        void moveConnectedElements(
            Offset oldPoint, Offset newPoint, Set<int> visitedLines) {
          final pointShift = Offset(
            newPoint.dx - oldPoint.dx,
            newPoint.dy - oldPoint.dy,
          );

          for (int i = 0; i < lines.length; i++) {
            if (visitedLines.contains(i)) continue;

            final currentLine = lines[i];

            if (currentLine.isDiagonal) {
              if (currentLine.connectedPoints != null) {
                final startInfo =
                    currentLine.connectedPoints!['start'] as List<int>;
                final endInfo =
                    currentLine.connectedPoints!['end'] as List<int>;

                if ((currentLine.start.dx - oldPoint.dx).abs() < 0.01 &&
                    (currentLine.start.dy - oldPoint.dy).abs() < 0.01) {
                  currentLine.start = newPoint;
                }

                if ((currentLine.end.dx - oldPoint.dx).abs() < 0.01 &&
                    (currentLine.end.dy - oldPoint.dy).abs() < 0.01) {
                  currentLine.end = newPoint;
                }
              }
            } else {
              if ((currentLine.start.dx - oldPoint.dx).abs() < 0.01 &&
                  (currentLine.start.dy - oldPoint.dy).abs() < 0.01) {
                visitedLines.add(i);

                currentLine.start = newPoint;
                final newEndPoint = Offset(
                  currentLine.end.dx + pointShift.dx,
                  currentLine.end.dy + pointShift.dy,
                );
                final oldEndPoint = currentLine.end;
                currentLine.end = newEndPoint;

                moveConnectedElements(oldEndPoint, newEndPoint, visitedLines);
              }
            }
          }

          if ((currentPoint.dx - oldPoint.dx).abs() < 0.01 &&
              (currentPoint.dy - oldPoint.dy).abs() < 0.01) {
            currentPoint = newPoint;
          }
        }

        final visitedLines = <int>{index};
        moveConnectedElements(oldEnd, newEnd, visitedLines);
      }
    });

    _updateFirebase();
  }

  void deleteLastLine() {
    if (lines.isEmpty) {
      print('deleteLastLine: 삭제할 선이 없음');
      return;
    }

    final lastIndex = lines.length - 1;
    print('deleteLastLine: 마지막 선 삭제 시작 - 인덱스: $lastIndex');

    saveState();

    setState(() {
      try {
        final lastLine = lines[lastIndex];
        final isDiagonal = lastLine.isDiagonal;

        print('deleteLastLine: 삭제할 선 - isDiagonal: $isDiagonal');

        // 현재 점 업데이트 (대각선이 아닌 경우에만)
        if (!isDiagonal && lastIndex > 0) {
          currentPoint = lastLine.start;
          print('deleteLastLine: 현재 점 업데이트 - $currentPoint');
        } else if (!isDiagonal && lastIndex == 0) {
          // 첫 번째 선을 삭제하는 경우 원점으로 복귀
          currentPoint = const Offset(0, 0);
          print('deleteLastLine: 첫 번째 선 삭제 - 원점으로 복귀');
        }

        // 선 삭제
        lines.removeAt(lastIndex);
        print('deleteLastLine: 선 삭제 완료 - 남은 선 개수: ${lines.length}');

        // 대각선 연결 정보 업데이트
        for (final line in lines) {
          if (line.isDiagonal && line.connectedPoints != null) {
            final startInfo = line.connectedPoints!['start'] as List<int>;
            final endInfo = line.connectedPoints!['end'] as List<int>;

            // 삭제된 선을 참조하는 경우 -1로 설정
            if (startInfo[0] == lastIndex) {
              startInfo[0] = -1;
            } else if (startInfo[0] > lastIndex) {
              startInfo[0]--;
            }

            if (endInfo[0] == lastIndex) {
              endInfo[0] = -1;
            } else if (endInfo[0] > lastIndex) {
              endInfo[0]--;
            }
          }
        }

        // 선택 상태 초기화
        selectedLineIndex = -1;
        selectedCircleIndex = -1;
      } catch (e) {
        print('deleteLastLine: 오류 발생 - $e');
        // 오류 발생 시 안전하게 상태 초기화
        selectedLineIndex = -1;
        selectedCircleIndex = -1;
      }
    });

    _updateFirebase();
    print('deleteLastLine: 완료');
  }

  void deleteSelectedLine() {
    if (selectedLineIndex < 0 || selectedLineIndex >= lines.length) {
      print(
          'deleteSelectedLine: 잘못된 인덱스 - selectedLineIndex: $selectedLineIndex, lines.length: ${lines.length}');
      return;
    }

    print('deleteSelectedLine: 선 삭제 시작 - 인덱스: $selectedLineIndex');

    saveState();

    setState(() {
      try {
        final selectedLine = lines[selectedLineIndex];
        final isDiagonal = selectedLine.isDiagonal;

        print('deleteSelectedLine: 삭제할 선 - isDiagonal: $isDiagonal');

        // 현재 점 업데이트 (대각선이 아닌 경우에만)
        if (!isDiagonal && selectedLineIndex > 0) {
          currentPoint = selectedLine.start;
          print('deleteSelectedLine: 현재 점 업데이트 - $currentPoint');
        }

        // 선 삭제
        lines.removeAt(selectedLineIndex);
        print('deleteSelectedLine: 선 삭제 완료 - 남은 선 개수: ${lines.length}');

        // 대각선 연결 정보 업데이트
        for (final line in lines) {
          if (line.isDiagonal && line.connectedPoints != null) {
            final startInfo = line.connectedPoints!['start'] as List<int>;
            final endInfo = line.connectedPoints!['end'] as List<int>;

            // 삭제된 선을 참조하는 경우 -1로 설정
            if (startInfo[0] == selectedLineIndex) {
              startInfo[0] = -1;
            } else if (startInfo[0] > selectedLineIndex) {
              startInfo[0]--;
            }

            if (endInfo[0] == selectedLineIndex) {
              endInfo[0] = -1;
            } else if (endInfo[0] > selectedLineIndex) {
              endInfo[0]--;
            }
          }
        }

        // 모든 상태 초기화
        selectedLineIndex = -1;
        selectedCircleIndex = -1;
        showLinePopup = false;
        selectedLineForPopup = null;
        linePopupPosition = null;
        showInlineInput = false;
        arrowDirection = null;
        inlineDirection = "";
        isProcessingInput = false;

        print('deleteSelectedLine: 상태 초기화 완료');
      } catch (e) {
        print('deleteSelectedLine: 오류 발생 - $e');
        // 오류 발생 시 안전한 상태로 복원
        selectedLineIndex = -1;
        selectedCircleIndex = -1;
        showLinePopup = false;
        selectedLineForPopup = null;
        linePopupPosition = null;
        showInlineInput = false;
        arrowDirection = null;
        inlineDirection = "";
        isProcessingInput = false;
      }
    });

    // Firebase 업데이트는 setState 완료 후 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFirebase();
      print('deleteSelectedLine: Firebase 업데이트 완료');
    });
  }

  void deleteSelectedCircle() {
    if (selectedCircleIndex < 0 || selectedCircleIndex >= circles.length) {
      print(
          'deleteSelectedCircle: 잘못된 인덱스 - selectedCircleIndex: $selectedCircleIndex, circles.length: ${circles.length}');
      return;
    }

    print('deleteSelectedCircle: 원 삭제 시작 - 인덱스: $selectedCircleIndex');

    saveState();

    setState(() {
      try {
        // 원 삭제
        circles.removeAt(selectedCircleIndex);
        print('deleteSelectedCircle: 원 삭제 완료 - 남은 원 개수: ${circles.length}');

        // 모든 상태 초기화
        selectedCircleIndex = -1;
        selectedLineIndex = -1;
        showLinePopup = false;
        selectedLineForPopup = null;
        linePopupPosition = null;
        showInlineInput = false;
        arrowDirection = null;
        inlineDirection = "";
        isProcessingInput = false;

        print('deleteSelectedCircle: 상태 초기화 완료');
      } catch (e) {
        print('deleteSelectedCircle: 오류 발생 - $e');
        // 오류 발생 시 안전한 상태로 복원
        selectedCircleIndex = -1;
        selectedLineIndex = -1;
        showLinePopup = false;
        selectedLineForPopup = null;
        linePopupPosition = null;
        showInlineInput = false;
        arrowDirection = null;
        inlineDirection = "";
        isProcessingInput = false;
      }
    });

    // Firebase 업데이트는 setState 완료 후 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFirebase();
      print('deleteSelectedCircle: Firebase 업데이트 완료');
    });
  }

  String _getStatusText() {
    if (_isVoiceProcessing) {
      return '음성 처리 중...';
    }

    if (_isListening) {
      return '음성 인식 중... 숫자를 말해주세요';
    }

    if (_recognizedText.isNotEmpty && !_isListening) {
      return '인식된 음성: "$_recognizedText"';
    }

    if (circleMode) {
      return circleCenter == null
          ? '원 모드: 중심점을 클릭하세요'
          : '원 모드: 지름을 입력하세요 (음성 입력 가능)';
    }

    if (showInlineInput) {
      final directionText =
          inlineDirection.isEmpty ? "" : " ($inlineDirection)";
      final speechText = _isListening && _recognizedText.isNotEmpty
          ? '\n인식중: "$_recognizedText"'
          : '';
      return '숫자 입력 후 Enter$directionText (음성 입력 가능)$speechText';
    }

    if (isPointDragging) {
      return '점에서 점으로 선 그리는 중... (다른 점에서 놓으면 완료)';
    }

    if (selectedLineIndex >= 0) {
      return '선 ${selectedLineIndex + 1}/${lines.length} 선택됨 (숫자 입력으로 길이 수정)';
    }

    if (pendingOpeningType == 'window') {
      return '창문 모드: 방향키를 눌러주세요';
    }

    final speechText = _isListening && _recognizedText.isNotEmpty
        ? '\n인식중: "$_recognizedText"'
        : '';

    if (diagonalMode) {
      return '점연결 모드: 점을 터치한 채로 드래그해서 선을 그리세요$speechText';
    } else {
      return '일반 모드: 방향키를 눌러 선을 그리세요$speechText';
    }
  }

  void _handleTap(Offset position) {
    print('_handleTap 호출됨 - 위치: $position');
    print('현재 모드 - circleMode: $circleMode, isPointDragging: $isPointDragging');

    // 점 드래그 중이면 탭 무시
    if (isPointDragging) {
      print('점 드래그 중 - 탭 무시');
      return;
    }

    // 원 모드 처리
    if (circleMode) {
      print('원 모드로 이동');
      if (showInlineInput) {
        cancelInlineInput();
      }
      _handleCircleClick(position);
      return; // 원 모드에서는 다른 처리 없이 즉시 종료
    }

    // 일반 모드 처리
    if (showInlineInput) {
      cancelInlineInput();
    }

    final endpointInfo = hoveredPoint != null
        ? {'point': hoveredPoint}
        : _findEndpointNear(position);

    if (endpointInfo != null) {
      setState(() {
        currentPoint = endpointInfo['point'] as Offset;
      });
      _updateFirebase();
      return;
    }

    final lineIndex = _findLineNear(position);
    final circleIndex = _findCircleNear(position);

    if (lineIndex != null) {
      // 선의 중앙 위치 계산
      final line = lines[lineIndex];
      final lineCenterX = (line.start.dx + line.end.dx) / 2;
      final lineCenterY = (line.start.dy + line.end.dy) / 2;
      final lineCenterScreen = _modelToScreen(Offset(lineCenterX, lineCenterY));

      setState(() {
        selectedLineIndex = lineIndex;
        selectedCircleIndex = -1; // 원 선택 해제
        // 팝업 관련 코드 제거 - 단순히 선택만 함
      });
    } else if (circleIndex != null) {
      // 원 선택
      setState(() {
        selectedCircleIndex = circleIndex;
        selectedLineIndex = -1; // 선 선택 해제
      });
    } else {
      setState(() {
        selectedLineIndex = -1;
        selectedCircleIndex = -1;
      });
    }
  }

  void _handleCircleClick(Offset position) {
    print('원 클릭: $position');

    if (circleCenter == null) {
      // 가장 가까운 끝점 찾기
      Offset? closestPoint = hoveredPoint;

      if (closestPoint == null) {
        double minDist = double.infinity;

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];

          final startScreen = _modelToScreen(line.start);
          final dist1 = (position - startScreen).distance;
          if (dist1 < minDist && dist1 < 50) {
            minDist = dist1;
            closestPoint = line.start;
          }

          final endScreen = _modelToScreen(line.end);
          final dist2 = (position - endScreen).distance;
          if (dist2 < minDist && dist2 < 50) {
            minDist = dist2;
            closestPoint = line.end;
          }
        }
      }

      // 끝점을 찾았으면 그 점을 중심으로, 없으면 클릭 지점을 중심으로
      final centerPoint = closestPoint ?? _screenToModel(position);

      // 첫 번째 클릭: 중심점 설정
      setState(() {
        circleCenter = centerPoint;
      });
      print('원 중심점 설정: $circleCenter');

      // 지름 입력 모드로 전환
      setState(() {
        showInlineInput = true;
        inlineController.clear();
        arrowDirection = null;
        inlineDirection = "";
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        inlineFocus.requestFocus();
      });
    }
  }

  // 점 간 드래그 선 그리기 함수들
  void _handlePointDragStart(DragStartDetails details) {
    print('=== 점 드래그 시작 ===');
    print(
        '아이패드 웹 - 현재 상태: _isScaling=$_isScaling, _touchCount=$_touchCount, isTablet=$isTablet, diagonalMode=$diagonalMode');

    // 원 모드 중이면 무시 (인라인 입력 중에는 화면 이동 허용)
    if (circleMode) {
      print('원 모드 중 - 점 드래그 무시');
      return;
    }

    // 대각선 모드가 아니거나 인라인 입력 중이면 화면 이동만 허용
    if (!diagonalMode || showInlineInput) {
      print('대각선 모드가 아니거나 인라인 입력 중 - 점 드래그 비활성화, 화면 이동만 허용');
      // 대각선 모드가 아니거나 인라인 입력 중일 때는 화면 이동만 허용
      final position = details.localPosition;
      setState(() {
        _isPanning = true;
        _lastPanPosition = position;
        isPointDragging = false;
      });
      print(
          '화면 이동 시작: $position (대각선 모드: $diagonalMode, 인라인 입력: $showInlineInput)');
      return;
    }

    // 아이패드 웹에서 멀티터치 중이면 무시
    if (isTablet && _touchCount > 1) {
      print('아이패드 웹 - 멀티터치 중이므로 점 드래그 무시');
      return;
    }

    final position = details.localPosition;
    final startPoint = _findNearestEndpoint(position);

    // 점 근처에서 시작한 경우에만 점 드래그 시작
    if (startPoint != null) {
      setState(() {
        isPointDragging = true;
        pointDragStart = startPoint;
        pointDragEnd = startPoint;
        _isPanning = false; // 점 드래그 중에는 화면 이동 비활성화
        _isScaling = false; // 점 드래그 중에는 스케일 제스처 비활성화

        // 다른 선택 상태 초기화
        selectedLineIndex = -1;
        selectedCircleIndex = -1;
        hoveredPoint = null;
        hoveredLineIndex = null;
      });

      // 햅틱 피드백
      HapticFeedback.selectionClick();
      print('점 드래그 시작: $startPoint');
    } else {
      // 끝점이 아닌 곳을 터치하면 화면 이동 시작 (모든 플랫폼)
      setState(() {
        _isPanning = true;
        _lastPanPosition = position;
        isPointDragging = false;
      });
      print('화면 이동 시작: $position (아이패드 웹: $isTablet)');
    }
  }

  void _handlePointDragUpdate(DragUpdateDetails details) {
    final position = details.localPosition;

    if (isPointDragging && pointDragStart != null) {
      // 점 드래그 처리
      final nearestPoint = _findNearestEndpoint(position);

      setState(() {
        if (nearestPoint != null) {
          // 가까운 점이 있으면 스냅
          pointDragEnd = nearestPoint;
        } else {
          // 없으면 현재 위치
          pointDragEnd = _screenToModel(position);
        }
      });
    } else if (_isPanning && _lastPanPosition != null) {
      // 화면 이동 처리
      final delta = position - _lastPanPosition!;
      setState(() {
        viewOffset = viewOffset + delta;
        _lastPanPosition = position;
      });
      print('화면 이동: $delta, 새 viewOffset: $viewOffset');
    }
  }

  void _handlePointDragEnd(DragEndDetails details) {
    print('=== 드래그 종료 ===');

    if (isPointDragging && pointDragStart != null && pointDragEnd != null) {
      print('점 드래그 종료 처리');

      // 시작점과 끝점이 같으면 취소
      if (pointDragStart == pointDragEnd) {
        print('시작점과 끝점이 같음 - 점 드래그 취소');
        _cancelPointDrag();
        return;
      }

      // 최소 거리 체크
      final distance = (pointDragEnd! - pointDragStart!).distance;
      if (distance < 10.0) {
        print('거리가 너무 짧음 ($distance) - 점 드래그 취소');
        _cancelPointDrag();
        return;
      }

      // 일반 선 생성 (대각선도 가능)
      saveState();
      setState(() {
        lines.add(Line(
          start: pointDragStart!,
          end: pointDragEnd!,
          openingType: pendingOpeningType,
          isDiagonal: false, // 모든 선을 일반 선으로 처리
        ));

        // 현재 점을 끝점으로 이동
        currentPoint = pointDragEnd!;
        pendingOpeningType = null;
      });

      // 성공 햅틱 피드백
      HapticFeedback.lightImpact();
      print('점 드래그 선 생성 완료 - 길이: $distance');

      _updateFirebase();
      _resetPointDrag();
    } else if (_isPanning) {
      // 화면 이동 종료 처리
      print('화면 이동 종료');
      setState(() {
        _isPanning = false;
        _lastPanPosition = null;
      });
    } else {
      // 아무것도 하지 않고 있었다면 상태 초기화
      _cancelPointDrag();
    }
  }

  void _cancelPointDrag() {
    print('점 드래그 취소');
    _resetPointDrag();
  }

  void _resetPointDrag() {
    setState(() {
      isPointDragging = false;
      pointDragStart = null;
      pointDragEnd = null;
      _isScaling = false; // 점 드래그 종료 시 스케일 제스처 다시 활성화
    });
  }

  // 선택된 선의 길이를 변경하는 함수 (연결된 선들도 함께 이동)
  void _resizeSelectedLine(double newLength) {
    if (selectedLineIndex < 0 || selectedLineIndex >= lines.length) {
      print('유효하지 않은 선택된 선 인덱스: $selectedLineIndex');
      return;
    }

    final selectedLine = lines[selectedLineIndex];
    final currentLength = (selectedLine.end - selectedLine.start).distance;

    print('선택된 선 길이 변경: $currentLength -> $newLength');

    // 현재 방향 벡터 계산
    final direction = selectedLine.end - selectedLine.start;
    final normalizedDirection = direction / currentLength;

    // 새로운 끝점 계산
    final newEnd = selectedLine.start + (normalizedDirection * newLength);

    // 끝점 이동량 계산
    final endPointOffset = newEnd - selectedLine.end;

    print('끝점 이동량: $endPointOffset');

    saveState();

    setState(() {
      // 선택된 선 업데이트
      lines[selectedLineIndex] = Line(
        start: selectedLine.start,
        end: newEnd,
        openingType: selectedLine.openingType,
        isDiagonal: selectedLine.isDiagonal,
        connectedPoints: selectedLine.connectedPoints,
      );

      // 연결된 선들 찾기 및 이동 (끝점 기준)
      _moveConnectedLines(
          selectedLineIndex, selectedLine.end, newEnd, {selectedLineIndex});

      // 시작점과 연결된 선들도 확인 (시작점이 이동한 경우)
      if (selectedLine.start != lines[selectedLineIndex].start) {
        _moveConnectedLines(selectedLineIndex, selectedLine.start,
            lines[selectedLineIndex].start, {selectedLineIndex});
      }

      // 현재 점을 새로운 끝점으로 이동
      currentPoint = newEnd;
    });

    _updateFirebase();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('선택된 선의 길이를 ${newLength.toInt()}픽셀로 변경했습니다!'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF238636),
      ),
    );

    print('선택된 선 길이 변경 완료: ${selectedLine.start} -> $newEnd');
  }

  // 연결된 선들을 함께 이동시키는 함수 (무한 루프 방지)
  void _moveConnectedLines(int modifiedLineIndex, Offset oldPoint,
      Offset newPoint, Set<int> processedLines) {
    final offset = newPoint - oldPoint;

    print('연결된 선들 이동 시작 - 기준 선: $modifiedLineIndex, 이동량: $offset');

    // 이동량이 너무 작으면 처리하지 않음
    if (offset.distance < 0.1) {
      print('이동량이 너무 작음 - 처리 생략');
      return;
    }

    // 수정된 선의 점과 연결된 선들 찾기
    for (int i = 0; i < lines.length; i++) {
      if (i == modifiedLineIndex || processedLines.contains(i))
        continue; // 수정된 선과 이미 처리된 선은 제외

      final line = lines[i];
      bool needsUpdate = false;
      Offset? newStart;
      Offset? newEnd;

      // 대각선이 아닌 연결된 선들 처리
      if (!line.isDiagonal) {
        // 연결 조건 확인 (거리 기반, 5픽셀 이내)
        const connectionThreshold = 5.0;

        // 현재 선의 시작점이 수정된 점과 연결되어 있는지 확인
        if ((line.start - oldPoint).distance < connectionThreshold) {
          newStart = line.start + offset;
          newEnd = line.end + offset;
          needsUpdate = true;
          print('연결된 선 발견 (시작점 연결): 인덱스 $i, 전체 이동');
        }
        // 현재 선의 끝점이 수정된 점과 연결되어 있는지 확인
        else if ((line.end - oldPoint).distance < connectionThreshold) {
          newStart = line.start;
          newEnd = line.end + offset;
          needsUpdate = true;
          print('연결된 선 발견 (끝점 연결): 인덱스 $i, 끝점만 이동');
        }
      }

      // 대각선 연결 처리
      if (line.isDiagonal && line.connectedPoints != null) {
        final startInfo = line.connectedPoints!['start'] as List<int>;
        final endInfo = line.connectedPoints!['end'] as List<int>;

        // 수정된 선과 연결된 대각선인지 확인
        if (startInfo[0] == modifiedLineIndex ||
            endInfo[0] == modifiedLineIndex) {
          // 대각선의 연결점 업데이트
          if (startInfo[0] == modifiedLineIndex) {
            // 시작점이 수정된 선과 연결됨
            if (startInfo[1] == 0) {
              // 시작점과 연결
              newStart = newPoint;
              newEnd = line.end;
              needsUpdate = true;
              print('대각선 연결 업데이트 (시작점-시작점): 인덱스 $i');
            } else if (startInfo[1] == 1) {
              // 끝점과 연결
              newStart = newPoint;
              newEnd = line.end;
              needsUpdate = true;
              print('대각선 연결 업데이트 (시작점-끝점): 인덱스 $i');
            }
          }

          if (endInfo[0] == modifiedLineIndex) {
            // 끝점이 수정된 선과 연결됨
            if (endInfo[1] == 0) {
              // 시작점과 연결
              newStart = line.start;
              newEnd = newPoint;
              needsUpdate = true;
              print('대각선 연결 업데이트 (끝점-시작점): 인덱스 $i');
            } else if (endInfo[1] == 1) {
              // 끝점과 연결
              newStart = line.start;
              newEnd = newPoint;
              needsUpdate = true;
              print('대각선 연결 업데이트 (끝점-끝점): 인덱스 $i');
            }
          }
        }
      }

      // 선 업데이트
      if (needsUpdate && newStart != null && newEnd != null) {
        final oldLineStart = line.start;
        final oldLineEnd = line.end;

        lines[i] = Line(
          start: newStart,
          end: newEnd,
          openingType: line.openingType,
          isDiagonal: line.isDiagonal,
          connectedPoints: line.connectedPoints,
        );
        print('선 $i 업데이트 완료: $newStart -> $newEnd');

        // 처리된 선 목록에 추가
        processedLines.add(i);

        // 재귀적으로 연결된 선들 처리 (시작점과 끝점 모두 확인)
        if (oldLineStart != newStart) {
          _moveConnectedLines(i, oldLineStart, newStart, processedLines);
        }
        if (oldLineEnd != newEnd) {
          _moveConnectedLines(i, oldLineEnd, newEnd, processedLines);
        }
      }
    }

    print('연결된 선들 이동 완료');
  }

  // 가장 가까운 끝점 찾기
  Offset? _findNearestEndpoint(Offset screenPosition) {
    const tolerance = 50.0;
    double minDist = double.infinity;
    Offset? closestPoint;

    for (final line in lines) {
      final startScreen = _modelToScreen(line.start);
      final dist1 = (screenPosition - startScreen).distance;
      if (dist1 < tolerance && dist1 < minDist) {
        minDist = dist1;
        closestPoint = line.start;
      }

      final endScreen = _modelToScreen(line.end);
      final dist2 = (screenPosition - endScreen).distance;
      if (dist2 < tolerance && dist2 < minDist) {
        minDist = dist2;
        closestPoint = line.end;
      }
    }

    return closestPoint;
  }

  Map<String, dynamic>? _findEndpointNear(Offset position) {
    const tolerance = 20.0;
    double closestDist = double.infinity;
    Map<String, dynamic>? closestInfo;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      final startScreen = _modelToScreen(line.start);
      final dist1 = (position - startScreen).distance;
      if (dist1 <= tolerance && dist1 < closestDist) {
        closestDist = dist1;
        closestInfo = {
          'index': i,
          'type': 'start',
          'point': line.start,
        };
      }

      final endScreen = _modelToScreen(line.end);
      final dist2 = (position - endScreen).distance;
      if (dist2 <= tolerance && dist2 < closestDist) {
        closestDist = dist2;
        closestInfo = {
          'index': i,
          'type': 'end',
          'point': line.end,
        };
      }
    }

    return closestInfo;
  }

  int? _findLineNear(Offset position) {
    const tolerance = 12.0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final startScreen = _modelToScreen(line.start);
      final endScreen = _modelToScreen(line.end);

      final dist = _pointToLineDistance(position, startScreen, endScreen);
      if (dist <= tolerance) {
        return i;
      }
    }

    return null;
  }

  int? _findCircleNear(Offset position) {
    const tolerance = 15.0;

    for (int i = 0; i < circles.length; i++) {
      final circle = circles[i];
      final centerScreen = _modelToScreen(circle.center);
      final radiusScreen = circle.radius * viewScale;

      // 원의 둘레와의 거리 계산
      final distToCenter = (position - centerScreen).distance;
      final distToCircle = (distToCenter - radiusScreen).abs();

      if (distToCircle <= tolerance) {
        return i;
      }
    }

    return null;
  }

  double _pointToLineDistance(Offset p, Offset a, Offset b) {
    final lineLen = (b - a).distance;
    if (lineLen == 0) return (p - a).distance;

    final t = ((p - a).dx * (b - a).dx + (p - a).dy * (b - a).dy) /
        (lineLen * lineLen);
    final clampedT = t.clamp(0.0, 1.0);

    final projection = Offset(
      a.dx + clampedT * (b.dx - a.dx),
      a.dy + clampedT * (b.dy - a.dy),
    );

    return (p - projection).distance;
  }

  Offset _modelToScreen(Offset model) {
    return Offset(
      viewOffset.dx + model.dx * viewScale,
      viewOffset.dy - model.dy * viewScale,
    );
  }

  Offset _screenToModel(Offset screen) {
    return Offset(
      (screen.dx - viewOffset.dx) / viewScale,
      -(screen.dy - viewOffset.dy) / viewScale,
    );
  }

  Offset _getInlineInputPosition() {
    // 원 모드에서 중심점이 설정된 경우
    if (circleMode && circleCenter != null) {
      final centerScreen = _modelToScreen(circleCenter!);
      return Offset(
        centerScreen.dx + 20, // 중심점 우측으로 이동
        centerScreen.dy - 40, // 상단으로 이동
      );
    }

    if (selectedLineIndex >= 0 &&
        selectedLineIndex < lines.length &&
        arrowDirection == null) {
      final line = lines[selectedLineIndex];
      final startScreen = _modelToScreen(line.start);
      final endScreen = _modelToScreen(line.end);
      final midX = (startScreen.dx + endScreen.dx) / 2;
      final midY = (startScreen.dy + endScreen.dy) / 2;
      return Offset(midX - 30, midY - 60);
    }

    // 화살표가 표시되는 경우 화살표 우측 상단에 위치
    final currentScreen = _modelToScreen(currentPoint);
    if (arrowDirection != null) {
      return Offset(
        currentScreen.dx + 30, // 화살표 우측으로 이동
        currentScreen.dy - 30, // 상단으로 이동
      );
    }

    // 기본 위치 (현재 점 우측 상단)
    return Offset(
      currentScreen.dx + 10,
      currentScreen.dy - 40,
    );
  }

  Offset _getNumberPadPopupPosition() {
    // 화면 크기 가져오기
    final screenSize = MediaQuery.of(context).size;

    // 숫자키패드는 우하단에 위치 (margin 20px, 패드 크기 약 220px)
    // 숫자키패드 위쪽 중앙에 팝업 위치
    final numberPadCenterX =
        screenSize.width - 20 - 110; // 우측에서 20px margin + 패드 절반 크기
    final numberPadTopY =
        screenSize.height - 120 - 200; // 하단에서 120px margin + 패드 높이

    return Offset(numberPadCenterX, numberPadTopY - 20); // 패드 위쪽 20px
  }

  Future<void> saveToDXF() async {
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('저장할 선이 없습니다.'),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return;
    }

    try {
      final dxfContent = generateDXF();

      // 현재 날짜와 시간으로 파일명 생성
      final now = DateTime.now();
      final fileName =
          'drawing_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.dxf';

      // Blob 생성 및 다운로드
      final bytes = Uint8List.fromList(dxfContent.codeUnits);
      final blob = html.Blob([bytes], 'text/plain');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement()
        ..href = url
        ..download = fileName
        ..style.display = 'none';

      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();

      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('DXF 파일이 다운로드되었습니다: $fileName'),
          backgroundColor: const Color(0xFF0097A7),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('파일 저장 중 오류가 발생했습니다: $e'),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    }
  }

  String generateDXF() {
    final buffer = StringBuffer();

    if (lines.isEmpty) {
      return '';
    }

    // 모든 선의 경계 계산하여 원점 근처로 이동
    double minX = double.infinity;
    double minY = double.infinity;

    for (final line in lines) {
      minX = math.min(minX, math.min(line.start.dx, line.end.dx));
      minY = math.min(minY, math.min(line.start.dy, line.end.dy));
    }

    // 최소한의 DXF 헤더
    buffer.writeln('0');
    buffer.writeln('SECTION');
    buffer.writeln('2');
    buffer.writeln('HEADER');
    buffer.writeln('9');
    buffer.writeln('\$ACADVER');
    buffer.writeln('1');
    buffer.writeln('AC1009'); // AutoCAD R12 - 가장 호환성 높은 버전
    buffer.writeln('0');
    buffer.writeln('ENDSEC');

    // 최소한의 TABLES 섹션
    buffer.writeln('0');
    buffer.writeln('SECTION');
    buffer.writeln('2');
    buffer.writeln('TABLES');
    buffer.writeln('0');
    buffer.writeln('TABLE');
    buffer.writeln('2');
    buffer.writeln('LTYPE');
    buffer.writeln('70');
    buffer.writeln('1');
    buffer.writeln('0');
    buffer.writeln('LTYPE');
    buffer.writeln('2');
    buffer.writeln('CONTINUOUS');
    buffer.writeln('70');
    buffer.writeln('64');
    buffer.writeln('3');
    buffer.writeln('Solid line');
    buffer.writeln('72');
    buffer.writeln('65');
    buffer.writeln('73');
    buffer.writeln('0');
    buffer.writeln('40');
    buffer.writeln('0.0');
    buffer.writeln('0');
    buffer.writeln('ENDTAB');
    buffer.writeln('0');
    buffer.writeln('TABLE');
    buffer.writeln('2');
    buffer.writeln('LAYER');
    buffer.writeln('70');
    buffer.writeln('2'); // 2개의 레이어
    // 기본 레이어 (0)
    buffer.writeln('0');
    buffer.writeln('LAYER');
    buffer.writeln('2');
    buffer.writeln('0');
    buffer.writeln('70');
    buffer.writeln('0');
    buffer.writeln('62');
    buffer.writeln('7');
    buffer.writeln('6');
    buffer.writeln('CONTINUOUS');
    // WIN 레이어 (창문용)
    buffer.writeln('0');
    buffer.writeln('LAYER');
    buffer.writeln('2');
    buffer.writeln('WIN');
    buffer.writeln('70');
    buffer.writeln('0');
    buffer.writeln('62');
    buffer.writeln('5'); // 하늘색 (색상 코드 5)
    buffer.writeln('6');
    buffer.writeln('CONTINUOUS');
    buffer.writeln('0');
    buffer.writeln('ENDTAB');
    buffer.writeln('0');
    buffer.writeln('ENDSEC');

    // ENTITIES 섹션
    buffer.writeln('0');
    buffer.writeln('SECTION');
    buffer.writeln('2');
    buffer.writeln('ENTITIES');

    // 좌표 변환: 원점 근처로 이동 + 적절한 스케일
    const double scale = 0.1; // 10:1 축소 (더 작은 좌표값)

    for (final line in lines) {
      // 원점 근처로 이동 후 스케일 적용
      final startX = (line.start.dx - minX) * scale;
      final startY = (line.start.dy - minY) * scale;
      final endX = (line.end.dx - minX) * scale;
      final endY = (line.end.dy - minY) * scale;

      // 창문인지 일반 선인지에 따라 레이어 결정
      final layerName = line.openingType == 'window' ? 'WIN' : '0';

      // 선 그리기
      buffer.writeln('0');
      buffer.writeln('LINE');
      buffer.writeln('8');
      buffer.writeln(layerName); // 창문은 WIN 레이어, 일반 선은 기본 레이어
      buffer.writeln('10');
      buffer.writeln(startX.toStringAsFixed(2));
      buffer.writeln('20');
      buffer.writeln(startY.toStringAsFixed(2));
      buffer.writeln('30');
      buffer.writeln('0.0');
      buffer.writeln('11');
      buffer.writeln(endX.toStringAsFixed(2));
      buffer.writeln('21');
      buffer.writeln(endY.toStringAsFixed(2));
      buffer.writeln('31');
      buffer.writeln('0.0');

      // 창문인 경우 평행선 추가 (모두 WIN 레이어)
      if (line.openingType == 'window') {
        final angle = math.atan2(endY - startY, endX - startX);
        final offset = 20.0; // 픽셀 단위
        final nx = offset * math.sin(angle);
        final ny = -offset * math.cos(angle);

        // 첫 번째 평행선
        buffer.writeln('0');
        buffer.writeln('LINE');
        buffer.writeln('8');
        buffer.writeln('WIN'); // WIN 레이어 사용
        buffer.writeln('10');
        buffer.writeln((startX + nx).toStringAsFixed(2));
        buffer.writeln('20');
        buffer.writeln((startY + ny).toStringAsFixed(2));
        buffer.writeln('30');
        buffer.writeln('0.0');
        buffer.writeln('11');
        buffer.writeln((endX + nx).toStringAsFixed(2));
        buffer.writeln('21');
        buffer.writeln((endY + ny).toStringAsFixed(2));
        buffer.writeln('31');
        buffer.writeln('0.0');

        // 두 번째 평행선
        buffer.writeln('0');
        buffer.writeln('LINE');
        buffer.writeln('8');
        buffer.writeln('WIN'); // WIN 레이어 사용
        buffer.writeln('10');
        buffer.writeln((startX - nx).toStringAsFixed(2));
        buffer.writeln('20');
        buffer.writeln((startY - ny).toStringAsFixed(2));
        buffer.writeln('30');
        buffer.writeln('0.0');
        buffer.writeln('11');
        buffer.writeln((endX - nx).toStringAsFixed(2));
        buffer.writeln('21');
        buffer.writeln((endY - ny).toStringAsFixed(2));
        buffer.writeln('31');
        buffer.writeln('0.0');
      }
    }

    // 원들 출력
    for (final circle in circles) {
      final centerX = (circle.center.dx - minX) * scale;
      final centerY = (circle.center.dy - minY) * scale;
      final radius = circle.radius * scale;

      buffer.writeln('0');
      buffer.writeln('CIRCLE');
      buffer.writeln('8');
      buffer.writeln('0'); // 기본 레이어 사용
      buffer.writeln('10');
      buffer.writeln(centerX.toStringAsFixed(2));
      buffer.writeln('20');
      buffer.writeln(centerY.toStringAsFixed(2));
      buffer.writeln('30');
      buffer.writeln('0.0');
      buffer.writeln('40');
      buffer.writeln(radius.toStringAsFixed(2));
    }

    buffer.writeln('0');
    buffer.writeln('ENDSEC');
    buffer.writeln('0');
    buffer.writeln('EOF');

    return buffer.toString();
  }

  void toggleFullscreen() {
    try {
      if (isFullscreen) {
        // 사용자가 직접 전체화면 해제를 요청
        print('사용자 요청: 전체화면 해제');
        _userRequestedFullscreen = false;
        _exitFullscreen();

        // 전체화면 해제 피드백
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.fullscreen_exit, color: Color(0xFF9CDCFE), size: 16),
                SizedBox(width: 8),
                Text('전체화면 모드가 해제되었습니다.',
                    style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 13)),
              ],
            ),
            backgroundColor: const Color(0xFF161B22),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFF30363D)),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // 사용자가 직접 전체화면 진입을 요청
        print('사용자 요청: 전체화면 진입');
        _userRequestedFullscreen = true;
        _requestFullscreen();

        // 전체화면 진입 피드백
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && isFullscreen) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.fullscreen, color: Color(0xFF9CDCFE), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '전체화면 모드가 활성화되었습니다. ESC 키로 해제할 수 있습니다.',
                        style:
                            TextStyle(color: Color(0xFFE6EDF3), fontSize: 13),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF161B22),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF30363D)),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        });
      }
    } catch (e) {
      print('전체화면 토글 오류: $e');

      // 오류 피드백
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFCE9178), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '전체화면 모드 전환에 실패했습니다: $e',
                  style:
                      const TextStyle(color: Color(0xFFE6EDF3), fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF161B22),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _requestFullscreen() {
    try {
      // 다양한 전체화면 API 시도 (아이패드 호환성)
      final element = html.document.documentElement!;

      // 표준 Fullscreen API
      element.requestFullscreen();
      return;

      // 웹킷 (Safari/아이패드)
      final webkitElement = element as dynamic;
      if (webkitElement.webkitRequestFullscreen != null) {
        webkitElement.webkitRequestFullscreen();
        return;
      }

      // 모질라
      if (webkitElement.mozRequestFullScreen != null) {
        webkitElement.mozRequestFullScreen();
        return;
      }

      // MS Edge
      if (webkitElement.msRequestFullscreen != null) {
        webkitElement.msRequestFullscreen();
        return;
      }

      print('전체화면 API를 지원하지 않는 브라우저입니다.');

      // 아이패드에서 전체화면이 지원되지 않는 경우 시뮬레이션
      if (isMobile) {
        setState(() {
          isFullscreen = true;
        });
        _showFullscreenMessage();
      }
    } catch (e) {
      print('전체화면 요청 실패: $e');

      // 폴백: 모바일에서는 시뮬레이션
      if (isMobile) {
        setState(() {
          isFullscreen = true;
        });
        _showFullscreenMessage();
      }
    }
  }

  void _exitFullscreen() {
    try {
      // 표준 Fullscreen API
      html.document.exitFullscreen();
      return;

      // 웹킷 (Safari/아이패드)
      final doc = html.document as dynamic;
      if (doc.webkitExitFullscreen != null) {
        doc.webkitExitFullscreen();
        return;
      }

      // 모질라
      if (doc.mozCancelFullScreen != null) {
        doc.mozCancelFullScreen();
        return;
      }

      // MS Edge
      if (doc.msExitFullscreen != null) {
        doc.msExitFullscreen();
        return;
      }

      // 시뮬레이션 모드 해제
      if (isMobile) {
        setState(() {
          isFullscreen = false;
        });
      }
    } catch (e) {
      print('전체화면 해제 실패: $e');

      // 폴백
      if (isMobile) {
        setState(() {
          isFullscreen = false;
        });
      }
    }
  }

  void _showFullscreenMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.info_outline, color: Color(0xFF1F6FEB), size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '아이패드에서는 Safari 설정에서 "전체화면 모드"를 활성화해주세요.',
                style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF161B22),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _setupFullscreenListener() {
    // 표준 fullscreenchange 이벤트
    html.document.onFullscreenChange.listen((_) {
      _handleFullscreenChange();
    });

    // 웹킷 fullscreenchange 이벤트 (Safari/아이패드)
    html.document.addEventListener('webkitfullscreenchange', (event) {
      _handleFullscreenChange();
    });

    // 모질라 fullscreenchange 이벤트
    html.document.addEventListener('mozfullscreenchange', (event) {
      _handleFullscreenChange();
    });

    // MS Edge fullscreenchange 이벤트
    html.document.addEventListener('msfullscreenchange', (event) {
      _handleFullscreenChange();
    });
  }

  void _handleFullscreenChange() {
    final newFullscreenState = _isCurrentlyFullscreen();

    // 브라우저에서 직접 전체화면 진입 시 자동 인식
    if (!_userRequestedFullscreen && newFullscreenState) {
      print('브라우저에서 전체화면 진입 감지 - 자동 동기화');
      _userRequestedFullscreen = true;
    }

    // 사용자가 요청한 전체화면 모드에서 의도하지 않은 해제 방지
    if (_userRequestedFullscreen && !newFullscreenState && !_isRecovering) {
      print('전체화면 모드에서 의도하지 않은 해제 감지 - 복구 시도');
      _isRecovering = true;

      // 약간의 지연 후 다시 전체화면 요청 (모든 플랫폼)
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_userRequestedFullscreen && !_isCurrentlyFullscreen()) {
          try {
            _requestFullscreen();
          } catch (e) {
            print('전체화면 복구 실패: $e');
            // 복구 실패 시 사용자 요청 상태 초기화
            _userRequestedFullscreen = false;
          }
        }
        // 복구 시도 완료
        _isRecovering = false;
      });
    }

    // 사용자가 브라우저에서 직접 전체화면 해제 시 (ESC 키 등)
    // 복구 시도 중이 아닐 때만 사용자 의도로 판단
    if (_userRequestedFullscreen &&
        !newFullscreenState &&
        isFullscreen &&
        !_isRecovering) {
      print('사용자가 브라우저에서 전체화면 해제');
      _userRequestedFullscreen = false;
    }

    setState(() {
      isFullscreen = newFullscreenState;
    });
  }

  bool _isCurrentlyFullscreen() {
    // 다양한 fullscreen API 체크
    final doc = html.document as dynamic;

    return html.document.fullscreenElement != null ||
        doc.webkitFullscreenElement != null ||
        doc.mozFullScreenElement != null ||
        doc.msFullscreenElement != null;
  }

  void toggleLineToWindow(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= lines.length) return;

    saveState();

    setState(() {
      final line = lines[lineIndex];
      if (line.openingType == 'window') {
        // 창문에서 일반 벽으로 변경
        line.openingType = null;
      } else {
        // 일반 벽에서 창문으로 변경
        line.openingType = 'window';
      }

      // 팝업 닫기
      showLinePopup = false;
      selectedLineForPopup = null;
      linePopupPosition = null;
    });

    _updateFirebase();
  }

  void closeLinePopup() {
    setState(() {
      showLinePopup = false;
      selectedLineForPopup = null;
      linePopupPosition = null;
    });
  }

  void centerCurrentPoint() {
    print('centerCurrentPoint 호출됨 - currentPoint: $currentPoint');

    // 화면 크기 가져오기
    final context = this.context;
    final screenSize = MediaQuery.of(context).size;

    // 캔버스 영역 계산 (UI 제외)
    final canvasWidth = screenSize.width;
    final canvasHeight = screenSize.height - 200; // 상단/하단 UI 고려

    // 화면 중심 계산
    final screenCenterX = canvasWidth / 2;
    final screenCenterY = canvasHeight / 2;

    // currentPoint가 화면 중심에 오도록 viewOffset 계산
    final newOffsetX = screenCenterX - (currentPoint.dx * viewScale);
    final newOffsetY =
        screenCenterY + (currentPoint.dy * viewScale); // Y축 반전 고려

    setState(() {
      viewOffset = Offset(newOffsetX, newOffsetY);
    });

    print('현재 점을 화면 중심으로 이동 - 새로운 offset: ($newOffsetX, $newOffsetY)');
  }

  void fitViewToDrawing() {
    if (lines.isEmpty && circles.isEmpty) {
      // 선과 원이 모두 없으면 currentPoint를 화면 중심에 맞춤
      print('선/원이 없음 - currentPoint를 화면 중심으로 이동');
      centerCurrentPoint();
      return;
    }

    // 모든 선과 원의 경계 계산
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    // 선들의 경계
    for (final line in lines) {
      // 시작점 확인
      minX = math.min(minX, line.start.dx);
      maxX = math.max(maxX, line.start.dx);
      minY = math.min(minY, line.start.dy);
      maxY = math.max(maxY, line.start.dy);

      // 끝점 확인
      minX = math.min(minX, line.end.dx);
      maxX = math.max(maxX, line.end.dx);
      minY = math.min(minY, line.end.dy);
      maxY = math.max(maxY, line.end.dy);
    }

    // 원들의 경계
    for (final circle in circles) {
      minX = math.min(minX, circle.center.dx - circle.radius);
      maxX = math.max(maxX, circle.center.dx + circle.radius);
      minY = math.min(minY, circle.center.dy - circle.radius);
      maxY = math.max(maxY, circle.center.dy + circle.radius);
    }

    // 경계 박스 크기 계산
    final drawingWidth = maxX - minX;
    final drawingHeight = maxY - minY;
    final drawingCenterX = (minX + maxX) / 2;
    final drawingCenterY = (minY + maxY) / 2;

    print('Drawing bounds: ($minX, $minY) to ($maxX, $maxY)');
    print('Drawing size: ${drawingWidth} x ${drawingHeight}');
    print('Drawing center: ($drawingCenterX, $drawingCenterY)');

    // 화면 크기 가져오기 (대략적인 캔버스 영역)
    final context = this.context;
    final screenSize = MediaQuery.of(context).size;
    final canvasWidth = screenSize.width - 100; // 여백 고려
    final canvasHeight = screenSize.height - 300; // 상단/하단 UI 고려

    // 적절한 스케일 계산 (여백 20% 추가)
    double scaleX = canvasWidth / (drawingWidth * 1.4);
    double scaleY = canvasHeight / (drawingHeight * 1.4);
    double optimalScale = math.min(scaleX, scaleY);

    // 스케일 범위 제한
    optimalScale = optimalScale.clamp(0.05, 2.0);

    // 화면 중심 계산
    final screenCenterX = canvasWidth / 2;
    final screenCenterY = canvasHeight / 2;

    // 새로운 뷰 오프셋 계산
    final newOffsetX = screenCenterX - (drawingCenterX * optimalScale);
    final newOffsetY =
        screenCenterY + (drawingCenterY * optimalScale); // Y축 반전 고려

    setState(() {
      viewScale = optimalScale;
      viewOffset = Offset(newOffsetX, newOffsetY);
    });

    print('New scale: $optimalScale');
    print('New offset: ($newOffsetX, $newOffsetY)');
  }

  @override
  Widget build(BuildContext context) {
    // 웹에서 추가 뷰 맞춤 체크 (빌드 완료 후)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_linesLoaded &&
          _circlesLoaded &&
          _currentPointLoaded &&
          !_initialViewFitExecuted) {
        _checkInitialDataLoaded();
      }
    });

    return Scaffold(
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        includeSemantics: false,
        onKey: (RawKeyEvent event) {
          if (event is RawKeyDownEvent) {
            if (showInlineInput) {
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                cancelInlineInput();
                return;
              } else if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                confirmInlineInput();
                return;
              } else if (event.logicalKey == LogicalKeyboardKey.keyW) {
                final currentText = inlineController.text;
                setState(() {
                  pendingOpeningType =
                      pendingOpeningType == 'window' ? null : 'window';
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  inlineController.text = currentText;
                  inlineController.selection = TextSelection.fromPosition(
                    TextPosition(offset: currentText.length),
                  );
                });
                return;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                  event.logicalKey == LogicalKeyboardKey.arrowDown ||
                  event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                  event.logicalKey == LogicalKeyboardKey.arrowRight) {
                if (selectedLineIndex < 0 || arrowDirection != null) {
                  String newDirection = '';
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp)
                    newDirection = 'Up';
                  else if (event.logicalKey == LogicalKeyboardKey.arrowDown)
                    newDirection = 'Down';
                  else if (event.logicalKey == LogicalKeyboardKey.arrowLeft)
                    newDirection = 'Left';
                  else if (event.logicalKey == LogicalKeyboardKey.arrowRight)
                    newDirection = 'Right';

                  setState(() {
                    inlineDirection = newDirection;
                    arrowDirection = newDirection;
                  });

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    inlineFocus.requestFocus();
                    inlineController.selection = TextSelection.fromPosition(
                      TextPosition(offset: inlineController.text.length),
                    );
                  });
                }
                return;
              }
              return;
            }

            if (event.isControlPressed &&
                event.logicalKey == LogicalKeyboardKey.keyZ) {
              undo();
            } else if (event.logicalKey == LogicalKeyboardKey.delete ||
                event.logicalKey == LogicalKeyboardKey.backspace) {
              if (showInlineInput && inlineController.text.isNotEmpty) {
                // 숫자 입력 중이면 백스페이스 기능 (마지막 문자 삭제)
                setState(() {
                  final currentText = inlineController.text;
                  if (currentText.isNotEmpty) {
                    inlineController.text =
                        currentText.substring(0, currentText.length - 1);
                    inlineController.selection = TextSelection.fromPosition(
                      TextPosition(offset: inlineController.text.length),
                    );
                  }
                });
              } else if (selectedLineIndex >= 0 &&
                  selectedLineIndex < lines.length) {
                print('Delete 키 처리: 선택된 선 삭제 시작');
                deleteSelectedLine();
              } else if (lines.isNotEmpty) {
                print('Delete 키 처리: 마지막 선 삭제 시작');
                deleteLastLine();
              }
              // 되돌리기 기능 제거
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              onDirectionKey('Up');
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              onDirectionKey('Down');
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              onDirectionKey('Left');
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              onDirectionKey('Right');
            } else if (event.logicalKey == LogicalKeyboardKey.keyW) {
              setState(() {
                pendingOpeningType =
                    pendingOpeningType == 'window' ? null : 'window';
              });
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              if (showInlineInput) {
                cancelInlineInput();
              } else if (isFullscreen && _userRequestedFullscreen) {
                // 전체화면 모드에서 ESC 키로 전체화면 해제
                print('ESC 키로 전체화면 해제');
                toggleFullscreen();
              } else {
                setState(() {
                  pendingOpeningType = null;
                  selectedLineIndex = -1;
                  isPointDragging = false;
                  pointDragStart = null;
                  pointDragEnd = null;
                  circleMode = false;
                  circleCenter = null;
                  hoveredPoint = null;
                  hoveredLineIndex = null;
                });
              }
            } else if (event.logicalKey == LogicalKeyboardKey.equal &&
                (event.isControlPressed || event.isMetaPressed)) {
              setState(() {
                viewScale = (viewScale * 1.2).clamp(0.1, 5.0);
              });
            } else if (event.logicalKey == LogicalKeyboardKey.minus &&
                (event.isControlPressed || event.isMetaPressed)) {
              setState(() {
                viewScale = (viewScale * 0.8).clamp(0.1, 5.0);
              });
            } else if (event.logicalKey == LogicalKeyboardKey.digit0 &&
                (event.isControlPressed || event.isMetaPressed)) {
              fitViewToDrawing();
            } else if (event.logicalKey == LogicalKeyboardKey.tab) {
              if (lines.isEmpty) return;

              if (showInlineInput) {
                cancelInlineInput();
              }

              setState(() {
                selectedLineIndex = (selectedLineIndex + 1) % lines.length;
              });
            } else if (event.character != null &&
                int.tryParse(event.character!) != null &&
                !showInlineInput) {
              print('Number pressed: ${event.character}');

              // 방향키가 설정되어 있으면 새 선 그리기 모드
              if (arrowDirection != null || inlineDirection.isNotEmpty) {
                print('방향키 설정됨 - 새 선 그리기 모드');
                setState(() {
                  showInlineInput = true;
                  inlineController.text = event.character!;
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  inlineFocus.requestFocus();
                  inlineController.selection = TextSelection.fromPosition(
                    TextPosition(offset: inlineController.text.length),
                  );
                });
              }
              // 선택된 선이 있으면 해당 선 길이 수정 모드
              else if (selectedLineIndex >= 0) {
                print('선택된 선 길이 수정 모드');
                setState(() {
                  showInlineInput = true;
                  inlineController.text = event.character!;
                  final line = lines[selectedLineIndex];
                  final dx = line.end.dx - line.start.dx;
                  final dy = line.end.dy - line.start.dy;

                  if (dx.abs() > dy.abs()) {
                    inlineDirection = dx > 0 ? 'Right' : 'Left';
                  } else {
                    inlineDirection = dy > 0 ? 'Up' : 'Down';
                  }
                  arrowDirection = null;
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  inlineFocus.requestFocus();
                  inlineController.selection = TextSelection.fromPosition(
                    TextPosition(offset: inlineController.text.length),
                  );
                });
              }
              // 선택된 선이 없고 선이 존재하면 마지막 선 선택
              else if (lines.isNotEmpty) {
                selectedLineIndex = lines.length - 1;
                print('마지막 선 자동 선택: $selectedLineIndex');
                setState(() {
                  showInlineInput = true;
                  inlineController.text = event.character!;
                  final line = lines[selectedLineIndex];
                  final dx = line.end.dx - line.start.dx;
                  final dy = line.end.dy - line.start.dy;

                  if (dx.abs() > dy.abs()) {
                    inlineDirection = dx > 0 ? 'Right' : 'Left';
                  } else {
                    inlineDirection = dy > 0 ? 'Up' : 'Down';
                  }
                  arrowDirection = null;
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  inlineFocus.requestFocus();
                  inlineController.selection = TextSelection.fromPosition(
                    TextPosition(offset: inlineController.text.length),
                  );
                });
              }
            }
          }
        },
        child: Column(
          children: [
            // 상단 메뉴바 - Cursor 스타일
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF30363D),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 로고/타이틀 (모바일에서는 완전히 숨김)
                  if (!isMobile) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF569CD6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF569CD6).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.architecture,
                            color: Color(0xFF569CD6), // Cursor 파란색
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'HV LAB',
                            style: TextStyle(
                              color: Color(0xFF569CD6), // Cursor 파란색
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // 레이아웃 전환 버튼
                  _buildLayoutSwitchButton(),

                  const Spacer(),

                  // 동기화 상태
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A9955).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sync,
                          color: Color(0xFF6A9955), // Cursor 초록색
                          size: 14,
                        ),
                        // 모바일 모드에서는 텍스트 숨김
                        if (!isMobile) ...[
                          const SizedBox(width: 4),
                          const Text(
                            '동기화',
                            style: TextStyle(
                              color: Color(0xFF6A9955), // Cursor 초록색
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 모드 버튼들
                  _buildCursorButton(
                    icon: Icons.door_sliding_rounded,
                    label: '창문',
                    onPressed: () {
                      setState(() {
                        pendingOpeningType =
                            pendingOpeningType == 'window' ? null : 'window';
                      });
                    },
                    color: const Color(0xFF569CD6), // Cursor 파란색
                    isPrimary: pendingOpeningType == 'window',
                  ),

                  const SizedBox(width: 4),

                  // 대각선(점과 점 연결) 버튼
                  _buildCursorButton(
                    icon: Icons.connect_without_contact_rounded,
                    label: '점연결',
                    onPressed: () {
                      setState(() {
                        diagonalMode = !diagonalMode;
                        // 대각선 모드 전환 시 다른 모드들 비활성화
                        if (diagonalMode) {
                          circleMode = false;
                          circleCenter = null;
                        }
                        // 점 드래그 상태 초기화
                        isPointDragging = false;
                        pointDragStart = null;
                        pointDragEnd = null;
                        hoveredPoint = null;
                        hoveredLineIndex = null;
                      });
                    },
                    color: const Color(0xFFDCDCAA), // 연한 노란색
                    isPrimary: diagonalMode,
                  ),

                  const SizedBox(width: 4),

                  _buildCursorButton(
                    icon: Icons.circle_outlined,
                    label: '원',
                    onPressed: () {
                      setState(() {
                        circleMode = !circleMode;
                        circleCenter = null;
                        isPointDragging = false;
                        pointDragStart = null;
                        pointDragEnd = null;
                        hoveredPoint = null;
                        hoveredLineIndex = null;
                      });
                    },
                    color: const Color(0xFFFF7043), // 주황색
                    isPrimary: circleMode,
                  ),

                  const SizedBox(width: 8),

                  // 메인 액션 버튼들
                  _buildCursorButton(
                    icon: Icons.refresh_rounded,
                    label: '초기화',
                    onPressed: reset,
                    color: const Color(0xFF9CDCFE), // Cursor 연한 파란색
                  ),

                  const SizedBox(width: 6),

                  _buildCursorButton(
                    icon: Icons.center_focus_strong_rounded,
                    label: '뷰 맞춤',
                    onPressed: fitViewToDrawing,
                    color: const Color(0xFF569CD6), // Cursor 파란색
                  ),

                  const SizedBox(width: 6),

                  _buildCursorButton(
                    icon: Icons.undo_rounded,
                    label: '되돌리기',
                    onPressed: undo,
                    color: const Color(0xFFCE9178), // Cursor 주황색
                  ),

                  const SizedBox(width: 6),

                  _buildCursorButton(
                    icon: Icons.save_alt_rounded,
                    label: 'DXF 저장',
                    onPressed: saveToDXF,
                    color: const Color(0xFF6A9955), // Cursor 초록색
                    isPrimary: true,
                  ),

                  const SizedBox(width: 6),

                  // 음성 인식 버튼 (로딩 상태 포함)
                  _buildVoiceButton(),

                  const SizedBox(width: 8),

                  // 전체화면 버튼
                  _buildIconButton(
                    icon: isFullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    onPressed: toggleFullscreen,
                    color: const Color(0xFF9CDCFE), // Cursor 연한 파란색
                    tooltip: isFullscreen ? '전체화면 해제' : '전체화면',
                  ),
                ],
              ),
            ),

            // 캔버스 (전체 화면)
            Expanded(
              child: Stack(
                children: [
                  Listener(
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        setState(() {
                          final delta = pointerSignal.scrollDelta.dy;
                          final scaleFactor = delta > 0 ? 0.9 : 1.1;

                          final pointerPos = pointerSignal.localPosition;
                          final beforeScale = viewScale;
                          viewScale = (viewScale * scaleFactor).clamp(0.1, 5.0);

                          final scaleChange = viewScale / beforeScale;
                          viewOffset = Offset(
                            pointerPos.dx -
                                (pointerPos.dx - viewOffset.dx) * scaleChange,
                            pointerPos.dy -
                                (pointerPos.dy - viewOffset.dy) * scaleChange,
                          );
                        });
                      }
                    },
                    child: GestureDetector(
                      // 원 모드나 점 드래그 중에서는 스케일 제스처 비활성화 (인라인 입력 중에는 화면 이동 허용)
                      onScaleStart: (circleMode || isPointDragging)
                          ? null
                          : (details) {
                              print(
                                  'Scale start - 터치 포인트 수: ${details.pointerCount}');
                              setState(() {
                                _isScaling = true;
                                _isPanning = false; // 스케일 중에는 팬 비활성화
                                _touchCount = details.pointerCount;

                                // 아이패드 웹에서 한 손가락 제스처인 경우 점 드래그나 화면 이동 준비
                                if (details.pointerCount == 1 && isTablet) {
                                  print('아이패드 웹 - 한 손가락 제스처 시작');
                                  _isScaling = false; // 한 손가락은 스케일이 아님
                                }
                              });
                              panStartOffset = viewOffset;
                              zoomStartScale = viewScale;
                              _initialScale = viewScale;
                              dragStartPos = details.focalPoint;

                              // 아이패드 디버깅
                              print(
                                  '아이패드 제스처 시작 - 초기 스케일: ${_initialScale.toStringAsFixed(2)}, 터치 수: ${details.pointerCount}');
                              print('포컬 포인트: ${details.focalPoint}');
                            },
                      onScaleUpdate: (circleMode || isPointDragging)
                          ? null
                          : (details) {
                              setState(() {
                                // 아이패드 웹 제스처 개선 - 더 명확한 분리
                                final scaleThreshold =
                                    isTablet ? 0.03 : 0.05; // 아이패드에서 더 민감하게
                                final scaleDelta = (details.scale - 1.0).abs();
                                final pointerCount = details.pointerCount;

                                print(
                                    '제스처 업데이트: scale=${details.scale.toStringAsFixed(3)}, delta=${scaleDelta.toStringAsFixed(3)}, pointers=$pointerCount, isTablet=$isTablet');

                                if (pointerCount >= 2 &&
                                    scaleDelta > scaleThreshold) {
                                  // 두 손가락 핀치 줌 (명확한 두 손가락 제스처)
                                  final newScale =
                                      (_initialScale * details.scale)
                                          .clamp(0.05, 10.0);
                                  final scaleChange = newScale / viewScale;

                                  // 줌 중심점을 기준으로 스케일 조정
                                  final focalPoint = details.focalPoint;
                                  viewOffset = Offset(
                                    focalPoint.dx -
                                        (focalPoint.dx - viewOffset.dx) *
                                            scaleChange,
                                    focalPoint.dy -
                                        (focalPoint.dy - viewOffset.dy) *
                                            scaleChange,
                                  );

                                  viewScale = newScale;
                                  print(
                                      '아이패드 핀치 줌: ${viewScale.toStringAsFixed(2)}x, 스케일: ${details.scale.toStringAsFixed(2)}');
                                } else if (pointerCount == 1 &&
                                    scaleDelta <= scaleThreshold) {
                                  // 한 손가락 팬 (화면 이동)
                                  final deltaX =
                                      details.focalPoint.dx - dragStartPos!.dx;
                                  final deltaY =
                                      details.focalPoint.dy - dragStartPos!.dy;

                                  // 최소 이동 거리 체크 (너무 작은 움직임은 무시)
                                  final minMovement = isTablet ? 3.0 : 2.0;
                                  if (deltaX.abs() > minMovement ||
                                      deltaY.abs() > minMovement) {
                                    viewOffset = Offset(
                                      panStartOffset!.dx + deltaX,
                                      panStartOffset!.dy + deltaY,
                                    );
                                    print(
                                        '아이패드 화면 이동: ${viewOffset.dx.toStringAsFixed(1)}, ${viewOffset.dy.toStringAsFixed(1)}');
                                  }
                                } else if (pointerCount >= 2 &&
                                    scaleDelta <= scaleThreshold) {
                                  // 두 손가락이지만 스케일 변화가 없는 경우 - 두 손가락 팬
                                  final deltaX =
                                      details.focalPoint.dx - dragStartPos!.dx;
                                  final deltaY =
                                      details.focalPoint.dy - dragStartPos!.dy;

                                  viewOffset = Offset(
                                    panStartOffset!.dx + deltaX,
                                    panStartOffset!.dy + deltaY,
                                  );
                                  print(
                                      '아이패드 두 손가락 팬: ${viewOffset.dx.toStringAsFixed(1)}, ${viewOffset.dy.toStringAsFixed(1)}');
                                }
                              });
                            },
                      onScaleEnd: (circleMode || isPointDragging)
                          ? null
                          : (details) {
                              print(
                                  'Scale end - 최종 스케일: ${viewScale.toStringAsFixed(2)}, 터치 수: $_touchCount');
                              // 아이패드 웹에서 제스처 종료 처리 개선
                              if (isTablet) {
                                // 아이패드에서는 즉시 상태 리셋
                                setState(() {
                                  _isScaling = false;
                                  _touchCount = 0;
                                  _isPanning = false;
                                });
                              } else {
                                // 다른 플랫폼에서는 기존 딜레이 유지
                                Future.delayed(
                                    const Duration(milliseconds: 150), () {
                                  if (mounted) {
                                    setState(() {
                                      _isScaling = false;
                                      _touchCount = 0;
                                      _isPanning = false;
                                    });
                                  }
                                });
                              }
                            },
                      // 점 드래그 처리 (대각선 모드일 때만 활성화)
                      onPanStart: (!circleMode &&
                              diagonalMode &&
                              !_isScaling &&
                              _touchCount <= 1)
                          ? _handlePointDragStart
                          : null,
                      onPanUpdate: ((isPointDragging || _isPanning) &&
                              !_isScaling &&
                              _touchCount <= 1)
                          ? _handlePointDragUpdate
                          : null,
                      onPanEnd: ((isPointDragging || _isPanning) && !_isScaling)
                          ? _handlePointDragEnd
                          : null,

                      onTap: () {
                        print(
                            'onTap 호출됨 - _lastTapPosition: $_lastTapPosition');
                        print(
                            '현재 모드 - isPointDragging: $isPointDragging, circle: $circleMode, scaling: $_isScaling');

                        // 스케일 제스처 중이거나 점 드래그 중이면 탭 이벤트 무시
                        if (_isScaling || isPointDragging) {
                          print('스케일 제스처 중 또는 점 드래그 중 - onTap 무시');
                          return;
                        }

                        // 데스크톱에서만 onTap 사용 (모바일/태블릿은 onTapDown에서 처리)
                        if (!isMobile && !isTablet) {
                          if (_lastTapPosition == null) {
                            print(
                                '데스크톱: _lastTapPosition이 null - onTapDown이 먼저 호출되지 않음');
                            return;
                          }

                          // 중복 터치 방지 (100ms 이내 중복 터치 무시)
                          final now = DateTime.now();
                          if (_lastTapTime != null &&
                              now.difference(_lastTapTime!).inMilliseconds <
                                  100) {
                            print('중복 터치 감지 - 무시');
                            return;
                          }

                          print('데스크톱에서 onTap 처리');
                          _handleTap(_lastTapPosition!);
                          _focusNode.requestFocus();
                        }
                      },
                      onTapDown: (details) {
                        print('onTapDown 호출됨 - 위치: ${details.localPosition}');
                        // 터치 위치와 시간 저장
                        final now = DateTime.now();
                        setState(() {
                          _lastTapPosition = details.localPosition;
                          _lastTapTime = now;
                        });

                        // 점 드래그 중이면 무시
                        if (isPointDragging) {
                          print('점 드래그 중 - onTapDown 무시');
                          return;
                        }

                        // 모바일/태블릿에서 원 모드일 때는 즉시 처리
                        if ((isMobile || isTablet) && circleMode) {
                          print('모바일/태블릿 원 모드에서 onTapDown 즉시 처리');
                          // 스케일 제스처 중이면 무시
                          if (_isScaling) {
                            print('스케일 제스처 중 - onTapDown 무시');
                            return;
                          }

                          // 중복 터치 방지
                          final now = DateTime.now();
                          if (_lastTapTime != null &&
                              now.difference(_lastTapTime!).inMilliseconds <
                                  300) {
                            print('중복 터치 감지 (300ms 이내) - 무시');
                            return;
                          }

                          _handleTap(details.localPosition);
                          _focusNode.requestFocus();
                        }
                      },
                      onTapUp: (details) {
                        print('onTapUp 호출됨 - 위치: ${details.localPosition}');
                        print(
                            '현재 모드 - isPointDragging: $isPointDragging, circle: $circleMode, scaling: $_isScaling');

                        // 스케일 제스처 중이거나 점 드래그 중이면 탭 이벤트 무시
                        if (_isScaling || isPointDragging) {
                          print('스케일 제스처 중 또는 점 드래그 중 - onTapUp 무시');
                          return;
                        }

                        // 저장된 위치 사용 (더 정확함)
                        final position =
                            _lastTapPosition ?? details.localPosition;

                        // 모바일/태블릿에서 원 모드는 onTapDown에서만 처리 (중복 방지)
                        if ((isMobile || isTablet) && circleMode) {
                          print('모바일/태블릿 원 모드는 onTapDown에서 처리됨 - onTapUp 무시');
                          return;
                        } else if (!circleMode) {
                          // 일반 모드에서만 onTapUp 사용
                          print('일반 모드에서 onTapUp 처리');
                          _handleTap(position);
                          _focusNode.requestFocus();
                        } else {
                          print('데스크톱 원 모드에서는 onTap에서 처리해야 함 - onTapUp 무시');
                        }
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.basic,
                        onHover: (event) {
                          final hovered =
                              _findEndpointNear(event.localPosition);
                          final newHoveredPoint = hovered?['point'] as Offset?;

                          final newHoveredLineIndex =
                              _findLineNear(event.localPosition);

                          if (newHoveredPoint != hoveredPoint ||
                              newHoveredLineIndex != hoveredLineIndex) {
                            setState(() {
                              mousePosition = event.localPosition;
                              hoveredPoint = newHoveredPoint;
                              hoveredLineIndex = newHoveredLineIndex;
                            });
                          }
                        },
                        onExit: (_) {
                          setState(() {
                            hoveredPoint = null;
                            mousePosition = null;
                            hoveredLineIndex = null;
                          });
                        },
                        child: CustomPaint(
                          painter: LinesPainter(
                            lines: lines,
                            circles: circles,
                            currentPoint: currentPoint,
                            viewScale: viewScale,
                            viewOffset: viewOffset,
                            selectedLineIndex: selectedLineIndex,
                            selectedCircleIndex: selectedCircleIndex,
                            arrowDirection: arrowDirection,
                            isPointDragging: isPointDragging,
                            circleMode: circleMode,
                            pointDragStart: pointDragStart,
                            pointDragEnd: pointDragEnd,
                            circleCenter: circleCenter,
                            pendingOpeningType: pendingOpeningType,
                            hoveredPoint: hoveredPoint,
                            hoveredLineIndex: hoveredLineIndex,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                  // 인라인 입력 - Cursor 스타일
                  if (showInlineInput)
                    Positioned(
                      left: _getInlineInputPosition().dx,
                      top: _getInlineInputPosition().dy,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: pendingOpeningType == 'window'
                                ? const Color(0xFF569CD6) // Cursor 파란색
                                : selectedLineIndex >= 0
                                    ? const Color(0xFF6A9955) // Cursor 초록색
                                    : const Color(0xFFCE9178), // Cursor 주황색
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (pendingOpeningType != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF569CD6).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '창문',
                                  style: TextStyle(
                                    color: const Color(0xFF569CD6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            if (selectedLineIndex >= 0 &&
                                arrowDirection == null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF6A9955).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '길이 수정',
                                  style: TextStyle(
                                    color: const Color(0xFF6A9955),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Container(
                              width: 45, // 너비 45px
                              height: 14, // 높이 14px
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3), // 반투명 배경
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: TextField(
                                controller: inlineController,
                                focusNode: inlineFocus,
                                autofocus: true,
                                keyboardType: (isMobile || isTablet)
                                    ? TextInputType.none
                                    : TextInputType.number,
                                readOnly: (isMobile || isTablet),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFE6EDF3),
                                  fontSize: 14, // 폰트 크기 14px
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                cursorColor: Colors.transparent, // 커서 색상 투명
                                cursorWidth: 0, // 커서 너비 0
                                cursorHeight: 0, // 커서 높이 0
                                showCursor: false, // 커서 표시 완전 비활성화
                                enableInteractiveSelection:
                                    false, // 텍스트 선택 비활성화
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 4),
                                  isDense: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9+\-.]')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 하단 컨트롤 패널 - 레이아웃별 분기
                  if (isMobile)
                    _buildMobileControls()
                  else if (isDesktop)
                    _buildDesktopControls()
                  else
                    _buildTabletControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceButton() {
    IconData icon;
    String label;
    Color color;
    bool isPrimary;

    if (_isVoiceProcessing) {
      icon = Icons.hourglass_empty_rounded;
      label = '처리 중';
      color = const Color(0xFFFFB300); // 노란색
      isPrimary = true;
    } else if (_isListening) {
      icon = Icons.mic_off_rounded;
      label = '음성 중지';
      color = const Color(0xFFCE9178); // 주황색
      isPrimary = true;
    } else {
      icon = Icons.mic_rounded;
      label = '음성 인식';
      color = const Color(0xFF9CDCFE); // 연한 파란색
      isPrimary = false;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isVoiceProcessing
            ? null
            : () {
                print(
                    '음성 인식 버튼 클릭됨 - _speechAvailable: $_speechAvailable, _isListening: $_isListening');
                if (_speechAvailable && !_isVoiceProcessing) {
                  if (_isListening) {
                    // 현재 음성 인식 중이면 중지
                    print('음성 인식 중지');
                    _stopListening();
                  } else {
                    // 음성 인식 시작
                    print('음성 인식 시작');
                    _startListening();
                  }
                } else if (!_speechAvailable) {
                  print('음성 인식 사용 불가 - 초기화 재시도');
                  _initSpeech();
                }
              },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 6 : 8, // 모바일에서 패딩 축소
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isPrimary ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isPrimary ? color : color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isVoiceProcessing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPrimary ? Colors.white : color,
                    ),
                  ),
                )
              else
                Icon(
                  icon,
                  color: isPrimary ? Colors.white : color,
                  size: 14,
                ),
              // 모바일 모드에서는 텍스트 숨김
              if (!isMobile) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCursorButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 6 : 8, // 모바일에서 패딩 축소
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isPrimary ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isPrimary ? color : color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : color,
                size: 14,
              ),
              // 모바일 모드에서는 텍스트 숨김
              if (!isMobile) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isTabletSize = false, // 태블릿 모드용 크기 옵션
  }) {
    Color buttonColor = const Color(0xFF6A9955); // Cursor 초록색
    if (pendingOpeningType == 'window') {
      buttonColor = const Color(0xFF569CD6); // Cursor 파란색
    }

    // 아이콘을 유니코드 화살표로 변환
    String arrowText = '';
    if (icon == Icons.keyboard_arrow_up_rounded) {
      arrowText = '↑';
    } else if (icon == Icons.keyboard_arrow_down_rounded) {
      arrowText = '↓';
    } else if (icon == Icons.keyboard_arrow_left_rounded) {
      arrowText = '←';
    } else if (icon == Icons.keyboard_arrow_right_rounded) {
      arrowText = '→';
    }

    // 태블릿 모드에서는 20% 크게
    final double buttonSize = isTabletSize ? 57.6 : 48.0; // 48 * 1.2 = 57.6
    final double fontSize = isTabletSize ? 28.8 : 24.0; // 24 * 1.2 = 28.8

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            color: buttonColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: buttonColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              arrowText,
              style: TextStyle(
                color: buttonColor,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 모바일 레이아웃 (데스크톱과 동일한 구조, 여백 조정)
  Widget _buildMobileControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 왼쪽: 간단한 방향키 (박스 제거)
            Container(
              margin: const EdgeInsets.only(left: 20, bottom: 80),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDirectionButton(
                    icon: Icons.keyboard_arrow_up_rounded,
                    onPressed: () => onDirectionKey('Up'),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDirectionButton(
                        icon: Icons.keyboard_arrow_left_rounded,
                        onPressed: () => onDirectionKey('Left'),
                      ),
                      const SizedBox(width: 6),
                      _buildDirectionButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        onPressed: () => onDirectionKey('Down'),
                      ),
                      const SizedBox(width: 6),
                      _buildDirectionButton(
                        icon: Icons.keyboard_arrow_right_rounded,
                        onPressed: () => onDirectionKey('Right'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 오른쪽: 미니 숫자패드 (박스 제거)
            Container(
              margin: const EdgeInsets.only(right: 20, bottom: 80),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCursorNumberButton('7'),
                      const SizedBox(width: 4),
                      _buildCursorNumberButton('8'),
                      const SizedBox(width: 4),
                      _buildCursorNumberButton('9'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCursorNumberButton('4'),
                      const SizedBox(width: 4),
                      _buildCursorNumberButton('5'),
                      const SizedBox(width: 4),
                      _buildCursorNumberButton('6'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCursorNumberButton('1'),
                      const SizedBox(width: 4),
                      _buildCursorNumberButton('2'),
                      const SizedBox(width: 4),
                      _buildCursorNumberButton('3'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCursorNumberButton('0'),
                      const SizedBox(width: 4),
                      _buildCursorNumberButton('Del',
                          isSpecial: true, color: const Color(0xFFCE9178)),
                      const SizedBox(width: 4),
                      _buildCursorNumberButton('Ent',
                          isSpecial: true, color: const Color(0xFF6A9955)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 데스크톱 레이아웃 (키보드 전용 - UI 컨트롤 없음)
  Widget _buildDesktopControls() {
    return const SizedBox.shrink(); // 빈 위젯 반환 - 데스크톱에서는 키보드만 사용
  }

  // 태블릿 레이아웃 (기존 레이아웃)
  Widget _buildTabletControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        margin: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 왼쪽: 방향키 패널 (배경 제거)
            Container(
              margin: const EdgeInsets.only(
                  left: 60, bottom: 70), // 왼쪽 60px, 하단 70px 추가 여백
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 위쪽 화살표 (태블릿 모드에서 20% 크게)
                  _buildDirectionButton(
                    icon: Icons.keyboard_arrow_up_rounded,
                    onPressed: () => onDirectionKey('Up'),
                    isTabletSize: true,
                  ),
                  const SizedBox(height: 6), // 숫자 버튼과 동일한 간격
                  // 중간 줄 (왼쪽, 아래, 오른쪽)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDirectionButton(
                        icon: Icons.keyboard_arrow_left_rounded,
                        onPressed: () => onDirectionKey('Left'),
                        isTabletSize: true,
                      ),
                      const SizedBox(width: 6), // 숫자 버튼과 동일한 간격
                      _buildDirectionButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        onPressed: () => onDirectionKey('Down'),
                        isTabletSize: true,
                      ),
                      const SizedBox(width: 6), // 숫자 버튼과 동일한 간격
                      _buildDirectionButton(
                        icon: Icons.keyboard_arrow_right_rounded,
                        onPressed: () => onDirectionKey('Right'),
                        isTabletSize: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 오른쪽: 숫자패드 (박스 제거)
            Container(
              margin: const EdgeInsets.only(right: 20, bottom: 120),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 첫 번째 줄: 7, 8, 9, - (태블릿 모드에서 10% 크게)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCursorNumberButton('7', isTabletSize: true),
                      const SizedBox(width: 6),
                      _buildCursorNumberButton('8', isTabletSize: true),
                      const SizedBox(width: 6),
                      _buildCursorNumberButton('9', isTabletSize: true),
                      const SizedBox(width: 6),
                      _buildCursorNumberButton('-',
                          isSpecial: true,
                          color: const Color(0xFF569CD6),
                          isTabletSize: true),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 두 번째 줄: 4, 5, 6, +
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCursorNumberButton('4', isTabletSize: true),
                      const SizedBox(width: 6),
                      _buildCursorNumberButton('5', isTabletSize: true),
                      const SizedBox(width: 6),
                      _buildCursorNumberButton('6', isTabletSize: true),
                      const SizedBox(width: 6),
                      _buildCursorNumberButton('+',
                          isSpecial: true,
                          color: const Color(0xFF569CD6),
                          isTabletSize: true),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 세 번째와 네 번째 줄
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 왼쪽 3x2 그리드
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 세 번째 줄: 1, 2, 3
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildCursorNumberButton('1', isTabletSize: true),
                              const SizedBox(width: 6),
                              _buildCursorNumberButton('2', isTabletSize: true),
                              const SizedBox(width: 6),
                              _buildCursorNumberButton('3', isTabletSize: true),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // 네 번째 줄: 0(2칸), Del
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 0 버튼 (2칸 크기)
                              _buildCursorNumberButton('0',
                                  isWide: true, isTabletSize: true),
                              const SizedBox(width: 6),
                              _buildCursorNumberButton('Del',
                                  isSpecial: true,
                                  color: const Color(0xFFCE9178),
                                  isTabletSize: true),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      // 오른쪽 Enter 버튼 (2줄 높이)
                      _buildCursorNumberButton('Ent',
                          isTall: true,
                          isSpecial: true,
                          color: const Color(0xFF6A9955),
                          isTabletSize: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutSwitchButton() {
    IconData getLayoutIcon() {
      switch (layoutMode) {
        case 'mobile':
          return Icons.smartphone_rounded;
        case 'tablet':
          return Icons.tablet_rounded;
        case 'desktop':
          return Icons.desktop_windows_rounded;
        default:
          return Icons.smartphone_rounded; // 기본값은 모바일
      }
    }

    String getLayoutLabel() {
      switch (layoutMode) {
        case 'mobile':
          return '모바일';
        case 'tablet':
          return '태블릿';
        case 'desktop':
          return '데스크톱';
        default:
          return '모바일'; // 기본값은 모바일
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            // 모바일 → 태블릿 → 데스크톱 → 모바일 순환
            switch (layoutMode) {
              case 'mobile':
                layoutMode = 'tablet';
                break;
              case 'tablet':
                layoutMode = 'desktop';
                break;
              case 'desktop':
                layoutMode = 'mobile';
                break;
              default:
                layoutMode = 'mobile'; // 기본값은 모바일
                break;
            }
          });

          // 레이아웃 변경 후 뷰 맞춤 자동 실행
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (isMobile || isTablet) {
              print('레이아웃 변경 후 - 모바일/태블릿 모드로 currentPoint 중심 맞춤');
              centerCurrentPoint();
            } else {
              fitViewToDrawing();
            }
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF9CDCFE).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF9CDCFE).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                getLayoutIcon(),
                color: const Color(0xFF9CDCFE),
                size: 16,
              ),
              // 모바일 모드에서는 텍스트 숨김, 다른 모드에서는 화면이 모바일이 아닐 때만 텍스트 표시
              if (layoutMode != 'mobile' && !isMobile) ...[
                const SizedBox(width: 6),
                Text(
                  getLayoutLabel(),
                  style: const TextStyle(
                    color: Color(0xFF9CDCFE),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCursorNumberButton(
    String label, {
    bool isSpecial = false,
    bool isWide = false,
    bool isTall = false,
    Color? color,
    bool isTabletSize = false, // 태블릿 모드용 크기 옵션
  }) {
    Color buttonColor = color ?? const Color(0xFF9CDCFE); // Cursor 연한 파란색

    // 태블릿 모드에서는 10% 크게
    final double baseSize = isTabletSize ? 52.8 : 48.0; // 48 * 1.1 = 52.8
    final double wideSize = isTabletSize ? 112.2 : 102.0; // 102 * 1.1 = 112.2
    final double fontSize = isTabletSize ? 17.6 : 16.0; // 16 * 1.1 = 17.6

    double width = isWide ? wideSize : baseSize;
    double height = isTall ? wideSize : baseSize; // isTall도 같은 비율로 증가

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onNumberPadKey(label),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isSpecial ? buttonColor : buttonColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSpecial ? buttonColor : buttonColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: isSpecial ? Colors.white : buttonColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
} // build 메서드 끝

// LinesPainter 클래스는 별도로 정의
class LinesPainter extends CustomPainter {
  final List<Line> lines;
  final List<Circle> circles;
  final Offset currentPoint;
  final double viewScale;
  final Offset viewOffset;
  final int selectedLineIndex;
  final int selectedCircleIndex;
  final String? arrowDirection;
  final bool isPointDragging;
  final bool circleMode;
  final Offset? pointDragStart;
  final Offset? pointDragEnd;
  final Offset? circleCenter;
  final String? pendingOpeningType;
  final Offset? hoveredPoint;
  final int? hoveredLineIndex;

  LinesPainter({
    required this.lines,
    required this.circles,
    required this.currentPoint,
    required this.viewScale,
    required this.viewOffset,
    required this.selectedLineIndex,
    required this.selectedCircleIndex,
    this.arrowDirection,
    required this.isPointDragging,
    required this.circleMode,
    this.pointDragStart,
    this.pointDragEnd,
    this.circleCenter,
    this.pendingOpeningType,
    this.hoveredPoint,
    this.hoveredLineIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 안전성 검사
    if (lines.isEmpty) return;

    // selectedLineIndex 유효성 검사
    final safeSelectedIndex =
        (selectedLineIndex >= 0 && selectedLineIndex < lines.length)
            ? selectedLineIndex
            : -1;

    // hoveredLineIndex 유효성 검사
    final safeHoveredIndex = (hoveredLineIndex != null &&
            hoveredLineIndex! >= 0 &&
            hoveredLineIndex! < lines.length)
        ? hoveredLineIndex
        : null;

    // 1. 먼저 모든 선 그리기
    for (int i = 0; i < lines.length; i++) {
      try {
        final line = lines[i];
        final start = _modelToScreen(line.start);
        final end = _modelToScreen(line.end);

        final paint = Paint()
          ..strokeWidth = i == safeSelectedIndex ? 3 : 2
          ..color =
              i == safeSelectedIndex ? const Color(0xFF4CAF50) : Colors.white;

        if (line.openingType == 'window') {
          // 호버 효과가 있는 경우 - 창문에만 적용
          if (i == safeHoveredIndex && i != safeSelectedIndex) {
            final hoverPaint = Paint()
              ..strokeWidth = 5
              ..color = const Color(0xFF00ACC1).withOpacity(0.5)
              ..strokeCap = StrokeCap.round;
            _drawDashedLine(canvas, start, end, hoverPaint, 5, 5);
          }

          // 창문 - 점선
          paint.color = i == safeSelectedIndex
              ? const Color(0xFF4CAF50)
              : const Color(0xFF00ACC1);
          paint.strokeWidth = i == safeSelectedIndex ? 3 : 3;
          _drawDashedLine(canvas, start, end, paint, 5, 5);

          // 이중선
          final angle = math.atan2(
              line.end.dy - line.start.dy, line.end.dx - line.start.dx);
          final offset = 5 * viewScale;
          final nx = offset * math.sin(angle);
          final ny = -offset * math.cos(angle);

          final doublePaint = Paint()
            ..color = i == safeSelectedIndex
                ? const Color(0xFF4CAF50)
                : const Color(0xFF00ACC1)
            ..strokeWidth = 1;

          canvas.drawLine(
            Offset(start.dx + nx, start.dy + ny),
            Offset(end.dx + nx, end.dy + ny),
            doublePaint,
          );
          canvas.drawLine(
            Offset(start.dx - nx, start.dy - ny),
            Offset(end.dx - nx, end.dy - ny),
            doublePaint,
          );
        } else {
          // 일반 선 호버 효과 - 선택되지 않은 경우에만
          if (i == safeHoveredIndex && i != safeSelectedIndex) {
            // 그림자 효과
            final shadowPaint = Paint()
              ..strokeWidth = 4
              ..color = Colors.white.withOpacity(0.2)
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
            canvas.drawLine(start, end, shadowPaint);

            // 밝은 선
            paint.strokeWidth = 2.5;
            paint.color = Colors.white;
          } else if (i == safeSelectedIndex) {
            // 선택된 경우 녹색 유지
            paint.strokeWidth = 3;
            paint.color = const Color(0xFF4CAF50);
          }

          canvas.drawLine(start, end, paint);
        }
      } catch (e) {
        // 개별 선 렌더링 오류 시 로그만 출력하고 계속 진행
        print('LinesPainter: 선 $i 렌더링 오류 - $e');
      }
    }

    // 2. 모든 원 그리기
    for (int i = 0; i < circles.length; i++) {
      try {
        final circle = circles[i];
        final centerScreen = _modelToScreen(circle.center);
        final radiusScreen = circle.radius * viewScale;

        // 선택된 원은 녹색, 일반 원은 흰색
        final isSelected = i == selectedCircleIndex;
        final circleColor = isSelected
            ? const Color(0xFF4CAF50) // 선택된 원: 녹색 (선과 동일)
            : Colors.white; // 일반 원: 흰색 (선과 동일)

        final paint = Paint()
          ..color = circleColor
          ..strokeWidth = isSelected ? 3 : 2 // 선택된 원은 더 두껍게
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(centerScreen, radiusScreen, paint);

        // 중심점 표시
        canvas.drawCircle(
          centerScreen,
          3,
          Paint()
            ..color = circleColor
            ..style = PaintingStyle.fill,
        );
      } catch (e) {
        print('LinesPainter: 원 렌더링 오류 - $e');
      }
    }

    // 3. 모든 치수 표시 (선 위에 그려짐)
    for (final line in lines) {
      _drawDimension(canvas, line);
    }

    // 4. 원의 치수 표시
    for (final circle in circles) {
      _drawCircleDimension(canvas, circle);
    }

    // 점 드래그 미리보기
    if (isPointDragging && pointDragStart != null && pointDragEnd != null) {
      final startScreen = _modelToScreen(pointDragStart!);
      final endScreen = _modelToScreen(pointDragEnd!);

      // 점 드래그 미리보기 선 그리기 (실선으로)
      final previewPaint = Paint()
        ..color = const Color(0xFF4CAF50).withOpacity(0.8) // 녹색 반투명
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(startScreen, endScreen, previewPaint);

      // 시작점 표시 (파란색)
      canvas.drawCircle(
        startScreen,
        8,
        Paint()
          ..color = const Color(0xFF2196F3).withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        startScreen,
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        startScreen,
        5,
        Paint()
          ..color = const Color(0xFF2196F3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // 끝점 표시 (녹색)
      canvas.drawCircle(
        endScreen,
        8,
        Paint()
          ..color = const Color(0xFF4CAF50).withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        endScreen,
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        endScreen,
        5,
        Paint()
          ..color = const Color(0xFF4CAF50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // 길이 표시
      final distance = (pointDragEnd! - pointDragStart!).distance;
      final midPoint = Offset(
        (startScreen.dx + endScreen.dx) / 2,
        (startScreen.dy + endScreen.dy) / 2,
      );

      _drawText(
        canvas,
        '${distance.toStringAsFixed(0)}mm',
        midPoint,
        const Color(0xFF4CAF50),
        fontSize: 12,
        backgroundColor: Colors.black.withOpacity(0.7),
      );
    }

    // 현재 점 그리기 (드래그 중이거나 원 모드가 아닐 때만)
    if (!isPointDragging && !circleMode) {
      final currentScreen = _modelToScreen(currentPoint);

      if (arrowDirection != null) {
        // 화살표 그리기
        _drawArrow(canvas, currentScreen, arrowDirection!);
      } else {
        // 심플한 속이 찬 원
        canvas.drawCircle(
          currentScreen,
          5,
          Paint()
            ..color = const Color(0xFFE53935)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // 원 모드에서 선택된 중심점
    if (circleMode && circleCenter != null) {
      final centerScreen = _modelToScreen(circleCenter!);

      // 펄스 효과를 위한 외부 원
      canvas.drawCircle(
        centerScreen,
        12,
        Paint()
          ..color = const Color(0xFFFF7043).withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );

      // 메인 원
      canvas.drawCircle(
        centerScreen,
        8,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );

      // 테두리
      canvas.drawCircle(
        centerScreen,
        8,
        Paint()
          ..color = const Color(0xFFFF7043)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // 호버된 점 표시
    if (hoveredPoint != null) {
      final hoveredScreen = _modelToScreen(hoveredPoint!);

      // 호버 효과 - 반투명 원
      canvas.drawCircle(
        hoveredScreen,
        8,
        Paint()
          ..color = const Color(0xFFE53935).withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );

      // 중심점
      canvas.drawCircle(
        hoveredScreen,
        4,
        Paint()
          ..color = const Color(0xFFE53935)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawArrow(Canvas canvas, Offset position, String direction) {
    // 미니멀 모던 디자인
    const double arrowLength = 16.0;
    const double arrowAngle = 0.5; // 화살표 각도 (라디안)

    // pendingOpeningType에 따라 색상 변경
    Color arrowColor = const Color(0xFFE53935);
    if (pendingOpeningType == 'window') {
      arrowColor = const Color(0xFFFF7043);
    }

    // 외곽 글로우 효과
    final glowPaint = Paint()
      ..color = arrowColor.withOpacity(0.3)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 메인 화살표 스트로크
    final strokePaint = Paint()
      ..color = arrowColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // 화살표 끝 점
    Offset endPoint;
    Offset leftWing;
    Offset rightWing;

    switch (direction) {
      case 'Up':
        endPoint = Offset(position.dx, position.dy - arrowLength);
        leftWing = Offset(
          endPoint.dx - arrowLength * math.sin(arrowAngle),
          endPoint.dy +
              arrowLength * math.cos(arrowAngle) * 0.48, // 0.6 * 0.8 = 0.48
        );
        rightWing = Offset(
          endPoint.dx + arrowLength * math.sin(arrowAngle),
          endPoint.dy +
              arrowLength * math.cos(arrowAngle) * 0.48, // 0.6 * 0.8 = 0.48
        );
        break;

      case 'Down':
        endPoint = Offset(position.dx, position.dy + arrowLength);
        leftWing = Offset(
          endPoint.dx - arrowLength * math.sin(arrowAngle),
          endPoint.dy -
              arrowLength * math.cos(arrowAngle) * 0.48, // 0.6 * 0.8 = 0.48
        );
        rightWing = Offset(
          endPoint.dx + arrowLength * math.sin(arrowAngle),
          endPoint.dy -
              arrowLength * math.cos(arrowAngle) * 0.48, // 0.6 * 0.8 = 0.48
        );
        break;

      case 'Left':
        endPoint = Offset(position.dx - arrowLength, position.dy);
        leftWing = Offset(
          endPoint.dx +
              arrowLength * math.cos(arrowAngle) * 0.48, // 0.6 * 0.8 = 0.48
          endPoint.dy - arrowLength * math.sin(arrowAngle),
        );
        rightWing = Offset(
          endPoint.dx +
              arrowLength * math.cos(arrowAngle) * 0.48, // 0.6 * 0.8 = 0.48
          endPoint.dy + arrowLength * math.sin(arrowAngle),
        );
        break;

      case 'Right':
        endPoint = Offset(position.dx + arrowLength, position.dy);
        leftWing = Offset(
          endPoint.dx -
              arrowLength * math.cos(arrowAngle) * 0.48, // 0.6 * 0.8 = 0.48
          endPoint.dy - arrowLength * math.sin(arrowAngle),
        );
        rightWing = Offset(
          endPoint.dx -
              arrowLength * math.cos(arrowAngle) * 0.48, // 0.6 * 0.8 = 0.48
          endPoint.dy + arrowLength * math.sin(arrowAngle),
        );
        break;

      default:
        return;
    }

    // 글로우 효과 (선택적)
    canvas.drawLine(position, endPoint, glowPaint);
    canvas.drawLine(leftWing, endPoint, glowPaint);
    canvas.drawLine(rightWing, endPoint, glowPaint);

    // 메인 화살표 그리기
    canvas.drawLine(position, endPoint, strokePaint);
    canvas.drawLine(leftWing, endPoint, strokePaint);
    canvas.drawLine(rightWing, endPoint, strokePaint);

    // 중심점 - 작은 원
    canvas.drawCircle(
      position,
      4,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      position,
      4,
      Paint()
        ..color = arrowColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawDimension(Canvas canvas, Line line) {
    final start = _modelToScreen(line.start);
    final end = _modelToScreen(line.end);

    final dx = line.end.dx - line.start.dx;
    final dy = line.end.dy - line.start.dy;
    final length = math.sqrt(dx * dx + dy * dy).round();

    if (length == 0) return;

    final midX = (start.dx + end.dx) / 2;
    final midY = (start.dy + end.dy) / 2;

    // 텍스트 위치 계산 - 12픽셀 거리
    final angle = math.atan2(dy, dx);
    final offset = 12.0;
    final nx = -math.sin(angle) * offset;
    final ny = math.cos(angle) * offset;

    canvas.save();
    canvas.translate(midX + nx, midY + ny);

    // 텍스트 회전
    double textAngle = -angle;
    if (textAngle > math.pi / 2) {
      textAngle -= math.pi;
    } else if (textAngle < -math.pi / 2) {
      textAngle += math.pi;
    }
    canvas.rotate(textAngle);

    // 텍스트 외곽선 (stroke) 그리기
    final outlinePainter = TextPainter(
      text: TextSpan(
        text: length.toString(),
        style: TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.w600,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = const Color(0xFF212830),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    outlinePainter.layout();
    outlinePainter.paint(
      canvas,
      Offset(-outlinePainter.width / 2, -outlinePainter.height / 2),
    );

    // 텍스트 채우기 (fill) 그리기
    final fillPainter = TextPainter(
      text: TextSpan(
        text: length.toString(),
        style: const TextStyle(
          color: Color(0xFFFFB300),
          fontSize: 16.0,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    fillPainter.layout();
    fillPainter.paint(
      canvas,
      Offset(-fillPainter.width / 2, -fillPainter.height / 2),
    );

    canvas.restore();
  }

  void _drawCircleDimension(Canvas canvas, Circle circle) {
    final centerScreen = _modelToScreen(circle.center);
    final diameter = (circle.radius * 2).round();

    if (diameter == 0) return;

    // 지름 표시 위치 - 원의 우측 상단
    final textX = centerScreen.dx + (circle.radius * viewScale * 0.7);
    final textY = centerScreen.dy - (circle.radius * viewScale * 0.7);

    canvas.save();
    canvas.translate(textX, textY);

    // 지름 표시 텍스트 (Ø 기호와 함께)
    final dimensionText = 'Ø$diameter';

    // 텍스트 외곽선 (stroke) 그리기
    final outlinePainter = TextPainter(
      text: TextSpan(
        text: dimensionText,
        style: TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFF212830),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    outlinePainter.layout();
    outlinePainter.paint(
      canvas,
      Offset(-outlinePainter.width / 2, -outlinePainter.height / 2),
    );

    // 텍스트 채우기 (fill) 그리기
    final fillPainter = TextPainter(
      text: TextSpan(
        text: dimensionText,
        style: const TextStyle(
          color: Color(0xFFFFB300),
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    fillPainter.layout();
    fillPainter.paint(
      canvas,
      Offset(-fillPainter.width / 2, -fillPainter.height / 2),
    );

    canvas.restore();
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint,
      double dashWidth, double dashSpace) {
    final distance = (end - start).distance;
    final dx = (end.dx - start.dx) / distance;
    final dy = (end.dy - start.dy) / distance;

    double currentDistance = 0;
    while (currentDistance < distance) {
      final dashEnd = currentDistance + dashWidth;
      if (dashEnd > distance) {
        canvas.drawLine(
          Offset(
              start.dx + dx * currentDistance, start.dy + dy * currentDistance),
          end,
          paint,
        );
      } else {
        canvas.drawLine(
          Offset(
              start.dx + dx * currentDistance, start.dy + dy * currentDistance),
          Offset(start.dx + dx * dashEnd, start.dy + dy * dashEnd),
          paint,
        );
      }
      currentDistance += dashWidth + dashSpace;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    Color color, {
    double fontSize = 14.0,
    Color? backgroundColor,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final textOffset = Offset(
      position.dx - textPainter.width / 2,
      position.dy - textPainter.height / 2,
    );

    // 배경색이 있으면 배경 그리기
    if (backgroundColor != null) {
      final backgroundRect = Rect.fromLTWH(
        textOffset.dx - 4,
        textOffset.dy - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(backgroundRect, const Radius.circular(4)),
        Paint()..color = backgroundColor,
      );
    }

    textPainter.paint(canvas, textOffset);
  }

  Offset _modelToScreen(Offset model) {
    return Offset(
      viewOffset.dx + model.dx * viewScale,
      viewOffset.dy - model.dy * viewScale,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
