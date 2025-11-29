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
import 'dart:typed_data';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

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

  // PWA 모드 감지 (홈 화면에 추가된 앱)
  static bool get isPWA {
    if (kIsWeb) {
      // display-mode: standalone 체크
      final isStandalone = js.context.callMethod('eval', [
        "(window.matchMedia('(display-mode: standalone)').matches)"
      ]) as bool;

      // iOS Safari의 navigator.standalone 체크
      final isIOSStandalone = js.context['navigator']['standalone'] ?? false;

      // 디버깅 로그
      print(
          'PWA 감지 - standalone: $isStandalone, iOS standalone: $isIOSStandalone');

      return isStandalone || isIOSStandalone;
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
      title: 'HV LINE',
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
  int timestamp;

  Line({
    required this.start,
    required this.end,
    this.openingType,
    this.isDiagonal = false,
    this.connectedPoints,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Line copy() {
    return Line(
      start: start,
      end: end,
      openingType: openingType,
      isDiagonal: isDiagonal,
      connectedPoints:
          connectedPoints != null ? Map.from(connectedPoints!) : null,
      timestamp: timestamp,
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
      'timestamp': timestamp,
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
      timestamp: json['timestamp'] as int?,
    );
  }
}

class Circle {
  Offset center;
  double radius;
  int timestamp;

  Circle({
    required this.center,
    required this.radius,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Circle copy() {
    return Circle(
      center: center,
      radius: radius,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'centerX': center.dx,
      'centerY': center.dy,
      'radius': radius,
      'timestamp': timestamp,
    };
  }

  static Circle fromJson(Map<dynamic, dynamic> json) {
    return Circle(
      center: Offset(
        (json['centerX'] as num).toDouble(),
        (json['centerY'] as num).toDouble(),
      ),
      radius: (json['radius'] as num).toDouble(),
      timestamp: json['timestamp'] as int?,
    );
  }
}

// 거리측정 클래스
class DistanceMeasurement {
  final int lineIndex1;
  final int lineIndex2;
  final Offset point1; // 첫 번째 선분에서의 최단거리 점
  final Offset point2; // 두 번째 선분에서의 최단거리 점
  final double distance;
  final int timestamp;

  DistanceMeasurement({
    required this.lineIndex1,
    required this.lineIndex2,
    required this.point1,
    required this.point2,
    required this.distance,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;
}

// 거리측정 아이콘 위젯
class DistanceMeasureIcon extends StatelessWidget {
  final Color color;
  final double size;

  const DistanceMeasureIcon({
    Key? key,
    required this.color,
    this.size = 14,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DistanceMeasurePainter(color: color),
    );
  }
}

class _DistanceMeasurePainter extends CustomPainter {
  final Color color;

  _DistanceMeasurePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 두 개의 평행선 그리기
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.3),
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.7),
      Offset(size.width * 0.8, size.height * 0.7),
      paint,
    );

    // 양방향 화살표로 거리 표시
    final arrowPaint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // 중앙 수직선
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.3),
      Offset(size.width * 0.5, size.height * 0.7),
      arrowPaint,
    );

    // 위쪽 화살표
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.3),
      Offset(size.width * 0.4, size.height * 0.4),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.3),
      Offset(size.width * 0.6, size.height * 0.4),
      arrowPaint,
    );

    // 아래쪽 화살표
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.7),
      Offset(size.width * 0.4, size.height * 0.6),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.7),
      Offset(size.width * 0.6, size.height * 0.6),
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 점 연결 아이콘 위젯
class DiagonalDotsIcon extends StatelessWidget {
  final Color color;
  final double size;

  const DiagonalDotsIcon({
    Key? key,
    required this.color,
    this.size = 14,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DiagonalDotsPainter(color: color),
    );
  }
}

class _DiagonalDotsPainter extends CustomPainter {
  final Color color;

  _DiagonalDotsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 대각선 그리기
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.2),
      paint,
    );

    // 양 끝에 점 그리기
    final dotRadius = size.width * 0.15;
    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.8), dotRadius, dotPaint);
    canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.2), dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 창문 아이콘 위젯
class WindowIcon extends StatelessWidget {
  final Color color;
  final double size;

  const WindowIcon({
    Key? key,
    required this.color,
    this.size = 14,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _WindowPainter(color: color),
    );
  }
}

class _WindowPainter extends CustomPainter {
  final Color color;

  _WindowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 정사각형 그리기
    final rect = Rect.fromLTWH(
      size.width * 0.15,
      size.height * 0.15,
      size.width * 0.7,
      size.height * 0.7,
    );
    canvas.drawRect(rect, paint);

    // 수직선 (가운데)
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.15),
      Offset(size.width * 0.5, size.height * 0.85),
      paint,
    );

    // 수평선 (가운데)
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.5),
      Offset(size.width * 0.85, size.height * 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
  double viewRotation = 0.0; // 화면 회전 각도 (라디안)
  int selectedLineIndex = -1;
  int selectedCircleIndex = -1;

  // 거리측정 관련 변수
  bool distanceMeasureMode = false;
  int? firstSelectedLineForDistance;
  Offset? firstSelectedPointForDistance; // 점 선택 추가
  List<DistanceMeasurement> distanceMeasurements = [];
  int? selectedMeasurementIndex;

  // 페이지 관련 변수
  int currentPage = 1; // 현재 선택된 페이지 (1-5)
  bool isPageDropdownOpen = false; // 드롭다운 열림 상태
  final LayerLink _dropdownLayerLink = LayerLink(); // 드롭다운 위치 연결용
  OverlayEntry? _dropdownOverlay; // 드롭다운 오버레이
  // 점 간 드래그 선 그리기 변수
  bool isPointDragging = false;
  Offset? pointDragStart;
  Offset? pointDragEnd;
  bool circleMode = false;
  bool diagonalMode = false; // 대각선(점과 점 연결) 모드
  Offset? circleCenter;
  String? pendingOpeningType;
  String? arrowDirection;
  bool isDoubleDirectionPressed = false; // 방향키 두 번 누름 상태

  // 그룹 드래그 앤 드롭 변수
  bool isGroupDragging = false;
  Offset? groupDragStartPoint; // 드래그 시작한 끝점
  Offset? groupDragCurrentPoint; // 현재 드래그 위치
  Set<int> draggedGroupLines = {}; // 드래그 중인 그룹의 선들
  Map<int, Offset> originalLineStarts = {}; // 원래 선들의 시작점
  Map<int, Offset> originalLineEnds = {}; // 원래 선들의 끝점
  Offset? snapTargetPoint; // 스냅될 대상 끝점

  // 더블클릭으로 선택된 그룹
  Set<int> selectedGroupLines = {}; // 선택된 그룹의 선들
  DateTime? lastTapTime; // 마지막 탭 시간 (더블클릭 감지용)

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

  // 선택된 끝점
  Offset? selectedEndpoint;
  int? selectedEndpointLineIndex;
  String? selectedEndpointType; // 'start' 또는 'end'

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
  String layoutMode = _getDefaultLayoutMode(); // 자동 감지

  // 자동 기기 감지 함수
  static String _getDefaultLayoutMode() {
    if (kIsWeb) {
      final userAgent = html.window.navigator.userAgent.toLowerCase();
      final platform = html.window.navigator.platform?.toLowerCase() ?? '';
      final maxTouchPoints = html.window.navigator.maxTouchPoints ?? 0;
      final screenWidth = html.window.screen?.width ?? 0;
      final screenHeight = html.window.screen?.height ?? 0;

      // 아이패드 감지 (iPadOS 13+ 포함)
      final isIPad = userAgent.contains('ipad') ||
          (userAgent.contains('macintosh') && maxTouchPoints > 0) ||
          platform.contains('ipad');

      // 모바일 기기 감지
      final isMobileDevice = userAgent.contains('iphone') ||
          userAgent.contains('android') ||
          userAgent.contains('mobile') ||
          userAgent.contains('phone');

      // 데스크톱 감지 (터치가 없고, 화면이 큰 경우)
      final isDesktopDevice = !isMobileDevice &&
          !isIPad &&
          maxTouchPoints == 0 &&
          screenWidth >= 1024;

      print('=== 자동 기기 감지 ===');
      print('User Agent: ${html.window.navigator.userAgent}');
      print('Platform: ${html.window.navigator.platform}');
      print('Touch Points: $maxTouchPoints');
      print('Screen: ${screenWidth}x$screenHeight');
      print(
          'iPad: $isIPad, Mobile: $isMobileDevice, Desktop: $isDesktopDevice');

      if (isIPad) {
        print('감지 결과: 태블릿 모드');
        return 'tablet';
      } else if (isMobileDevice) {
        print('감지 결과: 모바일 모드');
        return 'mobile';
      } else if (isDesktopDevice) {
        print('감지 결과: 데스크톱 모드');
        return 'desktop';
      } else {
        print('감지 결과: 기본값 (데스크톱 모드)');
        return 'desktop'; // 기본값을 데스크톱으로 변경
      }
    } else {
      // 모바일 앱인 경우
      return 'mobile';
    }
  }

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
  Set<double> _recentlyProcessedNumbers = {}; // 최근 처리된 숫자 집합
  double? _lastProcessedNumber; // 마지막으로 처리된 숫자
  DateTime? _lastLineDrawTime; // 마지막 선 그리기 시간
  bool _isVoiceProcessing = false; // 음성 처리 중 상태 (UI용)

  // 음성 인식 토글 모드 관련 변수
  // 자동 음성 모드 변수들 제거 - 성능 최적화를 위해 단순한 음성 인식 모드로 변경

  // 화면 이동 및 줌 관련 변수
  bool _isPanning = false;
  Offset? _lastPanPosition;
  double _initialScale = 1.0;
  double _initialRotation = 0.0; // 초기 회전 각도
  Offset? _rotationCenterScreen; // 회전 중심점 (화면 좌표)
  Offset? _rotationCenterModel; // 회전 중심점 (모델 좌표)
  int _touchCount = 0;

  // Firebase 참조를 페이지별로 업데이트
  void _updateFirebaseRefs() {
    _linesRef = FirebaseDatabase.instance.ref('drawing/page$currentPage/lines');
    _circlesRef =
        FirebaseDatabase.instance.ref('drawing/page$currentPage/circles');
    _currentPointRef =
        FirebaseDatabase.instance.ref('drawing/page$currentPage/currentPoint');
    _metadataRef =
        FirebaseDatabase.instance.ref('drawing/page$currentPage/metadata');
  }

  // 페이지 변경 함수
  void _changePage(int newPage) async {
    if (newPage == currentPage) return;

    print('페이지 변경: $currentPage → $newPage');

    // 현재 페이지 데이터 저장
    await _updateFirebase();

    // 기존 구독 취소
    await _linesSubscription?.cancel();
    await _circlesSubscription?.cancel();
    await _currentPointSubscription?.cancel();
    await _metadataSubscription?.cancel();

    // 구독 변수 초기화
    _linesSubscription = null;
    _circlesSubscription = null;
    _currentPointSubscription = null;
    _metadataSubscription = null;

    // 페이지 변경
    setState(() {
      currentPage = newPage;
      isPageDropdownOpen = false;

      // 데이터 초기화 (새 페이지 데이터 로드 전까지 빈 상태)
      lines.clear();
      circles.clear();
      currentPoint = const Offset(0, 0);
      selectedLineIndex = -1;
      selectedCircleIndex = -1;
      selectedGroupLines.clear();
      linesHistory.clear();

      // 로딩 상태 초기화
      _linesLoaded = false;
      _circlesLoaded = false;
      _currentPointLoaded = false;
      _initialViewFitExecuted = false;
    });

    // 새 페이지 Firebase 참조 업데이트
    _updateFirebaseRefs();

    // 새 페이지 데이터 즉시 로드
    await _loadCompleteDataFromFirebase();

    // 새 페이지 데이터 구독 설정
    _setupRealtimeSync();
  }

  @override
  void initState() {
    super.initState();

    // Firebase 초기화 (현재 페이지 기준)
    _updateFirebaseRefs();

    // 실시간 동기화 설정
    _setupRealtimeSync();

    // 전체화면 리스너 설정
    _setupFullscreenListener();

    // 기기 감지 디버깅 정보 출력
    _printDeviceInfo();

    // 음성 인식 초기화
    _initSpeech();

    // 앱 시작 시 포커스 설정 및 즉시 뷰 맞춤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();

      // 앱 시작 시 즉시 뷰 맞춤 실행 (강화된 버전)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          print('앱 시작 시 자동 뷰 맞춤 실행');
          print('현재 선 개수: ${lines.length}, 원 개수: ${circles.length}');
          print('현재 뷰 스케일: $viewScale, 오프셋: $viewOffset');

          // 데이터가 있으면 fitViewToDrawing, 없으면 centerCurrentPoint
          if (lines.isNotEmpty || circles.isNotEmpty) {
            print('데이터가 있음 - fitViewToDrawing 실행');
            fitViewToDrawing();
          } else {
            print('데이터가 없음 - centerCurrentPoint 실행');
            centerCurrentPoint();
          }
        }
      });

      // 추가로 1초 후에도 한 번 더 실행 (Firebase 데이터 로딩 완료 후)
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && (lines.isNotEmpty || circles.isNotEmpty)) {
          print('1.5초 후 추가 뷰 맞춤 실행 (데이터 로딩 완료 후)');
          fitViewToDrawing();
        }
      });
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
      print('isPWA: ${AppVersion.isPWA}');
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

  Future<void> _updateFirebase() async {
    if (_isUpdating) {
      print('Firebase 업데이트 중 - 중복 호출 무시');
      return;
    }

    _isUpdating = true;
    _isLocalUpdate = true;

    try {
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

      print('Firebase 업데이트 시작 - 페이지: $currentPage, 타임스탬프: $currentTimestamp');
      print('업데이트할 선 개수: ${lines.length}');
      print('업데이트할 원 개수: ${circles.length}');
      print('현재 점: $currentPoint');

      // 로컬 데이터를 Firebase 형식으로 변환
      final localLinesJson = lines.map((line) => line.toJson()).toList();
      final localCirclesJson =
          circles.map((circle) => circle.toJson()).toList();

      // 모든 데이터를 한 번에 업데이트 (원자적 업데이트)
      final updates = <String, dynamic>{};
      updates['drawing/page$currentPage/lines'] = localLinesJson;
      updates['drawing/page$currentPage/circles'] = localCirclesJson;
      updates['drawing/page$currentPage/currentPoint'] = {
        'x': currentPoint.dx,
        'y': currentPoint.dy,
        'timestamp': currentTimestamp,
      };
      updates['drawing/page$currentPage/metadata'] = {
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

      print('Firebase 업데이트 실행 중...');

      // Firebase 업데이트 실행
      await FirebaseDatabase.instance.ref().update(updates);

      print(
          'Firebase 업데이트 완료 - 선: ${localLinesJson.length}, 원: ${localCirclesJson.length}');
      print('타임스탬프: $currentTimestamp, 기기: $sessionId');
      print('업데이트 성공 - 모든 데이터 저장됨');
    } catch (e) {
      print('Firebase 업데이트 오류: $e');
      print('오류 상세 정보: ${e.toString()}');
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
      print('Firebase에서 완전한 데이터 로드 시작... (페이지: $currentPage)');

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

        print(
            '완전한 데이터 로드 완료 (페이지: $currentPage) - 선: ${lines.length}, 원: ${circles.length}');
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
    print('PWA 모드: ${AppVersion.isPWA}');

    // iPad PWA에서 권한 사전 요청
    if (AppVersion.isPWA && isTablet) {
      print('iPad PWA 감지 - 사전 권한 요청 시도');
      try {
        // 권한 상태 먼저 확인
        final permissionStatus = await html.window.navigator.permissions
            ?.query({'name': 'microphone'});
        print('현재 마이크 권한 상태: ${permissionStatus?.state}');

        // 권한이 prompt 상태면 사용자에게 안내
        if (permissionStatus?.state == 'prompt') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('음성인식을 사용하려면 마이크 권한을 허용해주세요.'),
                duration: Duration(seconds: 3),
                backgroundColor: Color(0xFF569CD6),
              ),
            );
          }
        }
      } catch (e) {
        print('권한 상태 확인 실패: $e');
      }
    }

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
              // PWA와 일반 브라우저 모두에서 동일한 방식으로 확인
              final webkitSupported = js.context.callMethod('eval',
                  ['typeof webkitSpeechRecognition !== "undefined"']) as bool;

              print(
                  'webkitSpeechRecognition 지원: $webkitSupported (PWA: ${AppVersion.isPWA})');

              if (webkitSupported) {
                // iPad PWA에서 추가 초기화
                if (AppVersion.isPWA && isTablet) {
                  print('iPad PWA 모드 - webkitSpeechRecognition 추가 초기화');

                  // PWA에서 webkitSpeechRecognition 객체 생성 테스트
                  try {
                    js.context.callMethod('eval', [
                      '''
                      // webkitSpeechRecognition 테스트 객체 생성
                      window._testSpeechRecognition = new webkitSpeechRecognition();
                      window._testSpeechRecognition = null; // 즉시 해제
                      console.log('iPad PWA: webkitSpeechRecognition 객체 생성 테스트 성공');
                    '''
                    ]);
                  } catch (e) {
                    print('iPad PWA webkitSpeechRecognition 객체 생성 실패: $e');
                    throw Exception('iPad PWA에서 음성인식 객체를 생성할 수 없습니다.');
                  }
                }

                _webSpeechAvailable = true;
                _speechAvailable = true;
                print('Safari 음성인식 초기화 성공 (PWA: ${AppVersion.isPWA})');
                return;
              }

              throw Exception('Safari에서 webkitSpeechRecognition을 찾을 수 없습니다.');
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
                } else {
                  // 중간 결과는 UI 업데이트만 하고 처리하지 않음
                  print('중간 결과 - UI 업데이트만: $_recognizedText');
                }
              }
            }
          });

          _webSpeechRecognition!.onError.listen((event) {
            print('웹 음성 인식 오류: ${event.error}');

            // aborted 오류 처리
            if (event.error == 'aborted') {
              print('음성 인식이 중단됨 (정상 종료 또는 권한 문제)');
              setState(() {
                _isListening = false;
              });
              // continuous=false 모드에서 stop() 호출 시 aborted는 정상 동작
              // 사용자에게 오류 메시지를 표시하지 않음
              return;
            }

            // no-speech 오류는 무시 (음성이 감지되지 않음)
            if (event.error == 'no-speech') {
              print('음성이 감지되지 않음 - 정상 동작');
              return;
            }

            // 기타 오류 처리
            setState(() {
              _isListening = false;
            });

            if (mounted && event.error != 'not-allowed') {
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
    _lastProcessedNumber = null;
    _processedTexts.clear(); // 처리된 텍스트 집합 초기화
    _recentlyProcessedNumbers.clear(); // 처리된 숫자 집합 초기화
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
    print('PWA 모드: ${AppVersion.isPWA}');
    print('현재 레이아웃: $layoutMode');

    try {
      // 모든 플랫폼에서 마이크 권한 요청 (iPad PWA 포함)
      final isIPadPWA = AppVersion.isPWA && isTablet;

      if (isIPadPWA) {
        print('아이패드 PWA 모드 - 마이크 권한 요청 시작');
      }

      try {
        // 권한 요청 전에 webkitSpeechRecognition 가용성 확인
        if (isIPadPWA) {
          final webkitAvailable = js.context.callMethod(
                  'eval', ['typeof webkitSpeechRecognition !== "undefined"'])
              as bool;
          print('iPad PWA webkitSpeechRecognition 가용성: $webkitAvailable');

          if (!webkitAvailable) {
            throw Exception('iPad PWA에서 음성인식 API를 사용할 수 없습니다.');
          }
        }

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

        // iPad PWA에서는 스트림을 더 오래 유지
        if (mediaStream != null) {
          final delay = isIPadPWA ? 500 : 100;
          Future.delayed(Duration(milliseconds: delay), () {
            mediaStream.getTracks().forEach((track) => track.stop());
            print('권한 체크용 스트림 종료 (${delay}ms 후)');
          });
        }
      } catch (e) {
        print('마이크 권한 요청 실패: $e');

        if (isIPadPWA) {
          // iPad PWA에서 권한 실패 시 명확한 안내
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📱 iPad 권한 설정 필요:\n\n'
                    '1. 설정 > 개인정보 보호 및 보안 > 마이크\n'
                    '2. Safari가 있으면 켜기\n'
                    '3. 없으면 Safari에서 hvl.kr 접속 후 음성인식 허용'),
                duration: Duration(seconds: 8),
                backgroundColor: Color(0xFFCE9178),
              ),
            );
          }
          throw Exception('iPad PWA 마이크 권한 거부됨');
        }
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
    print('PWA 모드: ${AppVersion.isPWA}');

    try {
      // 아이패드 PWA에서만 추가 권한 확인
      final isIPadPWA = AppVersion.isPWA && isTablet;

      if (isIPadPWA) {
        print('아이패드 PWA 모드 - 음성인식 권한 확인');

        // 마이크 권한 확인 (아이패드 PWA에서는 필수)
        try {
          final permissionStatus = await html.window.navigator.permissions
              ?.query({'name': 'microphone'});
          print('아이패드 PWA 마이크 권한 상태: ${permissionStatus?.state}');

          if (permissionStatus?.state == 'denied') {
            throw Exception('마이크 권한이 거부되었습니다.');
          }
        } catch (e) {
          print('아이패드 PWA 권한 확인 실패: $e');
          // 권한 확인 실패해도 계속 진행
        }
      }

      // iPad PWA에서 특별한 처리가 필요한지 확인
      if (isIPadPWA) {
        print('iPad PWA 모드 - Safari 음성인식 특별 처리');

        // PWA에서 권한 재확인
        try {
          final permissionResult = await html.window.navigator.permissions
              ?.query({'name': 'microphone'});
          print('iPad PWA 현재 마이크 권한 상태: ${permissionResult?.state}');
        } catch (e) {
          print('권한 상태 확인 실패: $e');
        }
      }

      // JavaScript 코드를 직접 실행하여 음성 인식 처리
      js.context.callMethod('eval', [
        '''
        try {
          // PWA 모드에서 webkitSpeechRecognition 생성 시도
          if (typeof webkitSpeechRecognition === 'undefined') {
            console.error('webkitSpeechRecognition이 정의되지 않음');
            throw new Error('webkitSpeechRecognition not available');
          }
          
          // iPad PWA에서는 다른 설정 사용
          var isIPadPWA = ${isIPadPWA ? 'true' : 'false'};
          
          window.safariSpeechRecognition = new webkitSpeechRecognition();
          window.safariSpeechRecognition.lang = 'ko-KR';
          
          // iPad PWA에서는 continuous를 true로 설정 (더 나은 호환성)
          window.safariSpeechRecognition.continuous = isIPadPWA ? true : false;
          window.safariSpeechRecognition.interimResults = true;
          window.safariSpeechRecognition.maxAlternatives = 1;
          
          console.log('Safari 음성인식 객체 생성 성공 (iPad PWA: ' + isIPadPWA + ')');
        } catch (e) {
          console.error('Safari 음성인식 객체 생성 실패:', e);
          window.safariSpeechRecognitionError = e.toString();
        }
        
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
        } else {
          // 중간 결과는 UI 업데이트만
          print('Safari 중간 결과: $transcript (UI 업데이트만)');
        }
      });

      js.context['dartSafariSpeechError'] = js.allowInterop((String error) {
        print('Dart 콜백 - Safari 음성 오류: $error');

        // aborted 오류 처리
        if (error == 'aborted') {
          print('Safari 음성 인식이 중단됨 (정상 종료 또는 권한 문제)');
          setState(() {
            _isListening = false;
          });
          // continuous=false 모드에서 stop() 호출 시 aborted는 정상 동작
          return;
        }

        // no-speech 오류는 무시
        if (error == 'no-speech') {
          print('Safari 음성이 감지되지 않음 - 정상 동작');
          return;
        }

        // 기타 오류 처리
        setState(() {
          _isListening = false;
        });

        if (mounted && error != 'not-allowed') {
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

      // 에러 체크
      final creationError = js.context['safariSpeechRecognitionError'];
      if (creationError != null) {
        print('Safari 음성인식 생성 오류 감지: $creationError');
        throw Exception('Safari 음성인식 생성 실패: $creationError');
      }

      // 음성 인식 시작
      final hasRecognition = js.context.callMethod(
          'eval', ['window.safariSpeechRecognition != null']) as bool;

      if (!hasRecognition) {
        throw Exception('Safari 음성인식 객체가 생성되지 않았습니다.');
      }

      // iPad PWA에서는 약간의 지연 후 시작
      if (isIPadPWA) {
        print('iPad PWA - 음성인식 시작 전 지연 (권한 안정화)');
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // 음성인식 시작 시도
      js.context.callMethod('eval', [
        '''
        try {
          window.safariSpeechRecognition.start();
          console.log('Safari 음성인식 start() 호출 성공');
        } catch (e) {
          console.error('Safari 음성인식 start() 실패:', e);
          window.safariStartError = e.toString();
          throw e;
        }
      '''
      ]);

      print('Safari 음성 인식 시작 요청 완료');

      // Safari 음성 인식 시작 메시지 제거 (팝업 없이 조용히 처리)
    } catch (e) {
      print('Safari 음성 인식 시작 실패: $e');

      // 시작 에러 상세 정보 확인
      try {
        final startError = js.context['safariStartError'];
        if (startError != null) {
          print('Safari 시작 에러 상세: $startError');
        }
      } catch (e2) {
        print('에러 정보 확인 실패: $e2');
      }

      setState(() {
        _isListening = false;
      });

      if (mounted) {
        String errorMessage = 'Safari 음성 인식 시작 실패: $e';

        // 아이패드 PWA 모드에서만 특별한 안내 메시지
        final isIPadPWA = AppVersion.isPWA && isTablet;
        if (isIPadPWA) {
          // 더 구체적인 해결 방법 안내
          errorMessage = '✅ iPad 홈화면 앱 음성인식 해결 방법:\n\n'
              '방법 1 (권장):\n'
              '• 홈화면 앱 삭제 → Safari에서 hvl.kr 접속\n'
              '• 음성인식 버튼 클릭하여 권한 허용\n'
              '• 공유 버튼 → 홈화면에 추가\n\n'
              '방법 2 (설정에서 확인):\n'
              '• 설정 > 개인정보 보호 및 보안 > 마이크 > Safari 켜기\n'
              '• 설정 > Safari > 카메라 및 마이크 접근 > "확인" 선택\n\n'
              '방법 3:\n'
              '• Safari 브라우저에서 hvl.kr 직접 사용';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
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
            } else {
              // 중간 결과는 UI 업데이트만
              print('모바일 중간 결과: $_recognizedText (UI 업데이트만)');
            }
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(milliseconds: 750), // 감도 향상을 위해 0.75초로 단축
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

    // 시간 간격 기반 분리 처리 (성능 최적화: 800ms → 400ms)
    final speechGapThreshold = 400; // 반응 속도 개선을 위해 더 단축
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

    // 새로운 세션이 아니고 너무 빠른 호출이면 무시 (성능 최적화: 400ms → 200ms)
    if (!isNewSpeechSession &&
        _lastSpeechProcessTime != null &&
        now.difference(_lastSpeechProcessTime!).inMilliseconds < 200) {
      print(
          '동일 세션 내 빠른 처리 200ms 이내 중복 호출 무시 (${now.difference(_lastSpeechProcessTime!).inMilliseconds}ms)');
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
        // 최근에 처리된 숫자인지 확인
        if (_recentlyProcessedNumbers.contains(bestNumber)) {
          print('빠른 처리 - 최근 처리된 숫자 중복 방지: $bestNumber');
          return;
        }

        print('빠른 처리 - 추출된 숫자: $bestNumber (새로운 세션: $isNewSpeechSession)');

        setState(() {
          _isSpeechProcessing = true;
          _isVoiceProcessing = true; // UI 로딩 상태 활성화
        });

        _lastProcessedText = trimmedText;
        _lastSpeechProcessTime = now;
        _lastLineDrawTime = now; // 선 그리기 시간 기록

        // 처리된 텍스트와 숫자를 집합에 추가
        _processedTexts.add(trimmedText);
        if (_processedTexts.length > 10) {
          _processedTexts.clear();
          _processedTexts.add(trimmedText);
        }

        _recentlyProcessedNumbers.add(bestNumber);
        if (_recentlyProcessedNumbers.length > 5) {
          _recentlyProcessedNumbers.clear();
          _recentlyProcessedNumbers.add(bestNumber);
        }

        // 1초 후 숫자 중복 방지 목록에서 제거
        Future.delayed(const Duration(seconds: 1), () {
          _recentlyProcessedNumbers.remove(bestNumber);
        });

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

        // 즉시 처리 가능한 경우 지연 시간 더 단축 (200ms → 100ms)
        Future.delayed(const Duration(milliseconds: 100), () {
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

    // 최근 선 그리기 후 너무 빠른 호출 방지 (성능 최적화: 500ms → 250ms)
    if (_lastLineDrawTime != null &&
        now.difference(_lastLineDrawTime!).inMilliseconds < 250) {
      print(
          '최근 선 그리기 후 250ms 이내 - 일반 처리 무시 (${now.difference(_lastLineDrawTime!).inMilliseconds}ms)');
      return;
    }

    // 시간 간격 기반 분리 처리 (성능 최적화: 800ms → 400ms)
    final speechGapThreshold = 400; // 반응 속도 개선을 위해 더 단축
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

    // 새로운 세션이 아니고 너무 빠른 호출이면 무시 (성능 최적화: 500ms → 250ms)
    if (!isNewSpeechSession &&
        _lastSpeechProcessTime != null &&
        now.difference(_lastSpeechProcessTime!).inMilliseconds < 250) {
      print(
          '동일 세션 내 음성 처리 250ms 이내 중복 호출 무시 (${now.difference(_lastSpeechProcessTime!).inMilliseconds}ms)');
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

    // 먼저 음성 명령 확인
    final lowerText = trimmedText.toLowerCase();

    // 방향과 숫자가 함께 있는지 확인 (예: "오른쪽 200", "위로 300")
    String? detectedDirection;
    String remainingText = lowerText;

    // 방향 패턴 검사
    if (lowerText.contains('위') ||
        lowerText.contains('위로') ||
        lowerText.contains('위쪽')) {
      detectedDirection = 'Up';
      remainingText = lowerText
          .replaceAll('위쪽', '')
          .replaceAll('위로', '')
          .replaceAll('위', '')
          .trim();
    } else if (lowerText.contains('아래') ||
        lowerText.contains('아래로') ||
        lowerText.contains('아래쪽')) {
      detectedDirection = 'Down';
      remainingText = lowerText
          .replaceAll('아래쪽', '')
          .replaceAll('아래로', '')
          .replaceAll('아래', '')
          .trim();
    } else if (lowerText.contains('왼쪽') || lowerText.contains('좌')) {
      detectedDirection = 'Left';
      remainingText = lowerText
          .replaceAll('왼쪽으로', '')
          .replaceAll('왼쪽', '')
          .replaceAll('좌', '')
          .trim();
    } else if (lowerText.contains('오른쪽') || lowerText.contains('우')) {
      detectedDirection = 'Right';
      remainingText = lowerText
          .replaceAll('오른쪽으로', '')
          .replaceAll('오른쪽', '')
          .replaceAll('우', '')
          .trim();
    }

    // 방향과 함께 숫자가 있는지 확인
    if (detectedDirection != null && remainingText.isNotEmpty) {
      // 남은 텍스트에서 숫자를 찾아보기
      final processedRemainingText =
          _convertKoreanNumbersToDigits(remainingText);
      final numberRegex = RegExp(r'\b(\d+(?:\.\d+)?)\b');
      final matches = numberRegex.allMatches(processedRemainingText);

      if (matches.isNotEmpty) {
        // 숫자가 있으면 방향 설정 후 숫자 처리
        print('방향과 숫자 동시 인식: 방향=$detectedDirection, 텍스트=$remainingText');

        // 방향 설정
        onDirectionKey(detectedDirection);

        // 잠시 후 숫자 처리를 위해 텍스트 재처리
        Future.delayed(const Duration(milliseconds: 100), () {
          // 숫자만 포함된 텍스트로 다시 처리
          _processRecognizedText(remainingText);
        });

        setState(() {
          _isSpeechProcessing = false;
          _isVoiceProcessing = false;
        });

        return;
      }
    }

    // 창문 명령
    if (lowerText.contains('창문')) {
      print('음성 명령: 창문');
      setState(() {
        // 창문 모드 토글
        final newOpeningType = pendingOpeningType == 'window' ? null : 'window';
        pendingOpeningType = newOpeningType;
        print('창문 모드 ${newOpeningType != null ? '활성화' : '비활성화'}');

        _isSpeechProcessing = false;
        _isVoiceProcessing = false;
      });

      // 처리 완료 후 플래그 리셋
      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          _isSpeechProcessing = false;
          _isVoiceProcessing = false;
        });
      });
      return;
    }

    // 점연결/대각선 명령
    if (lowerText.contains('점연결') || lowerText.contains('대각선')) {
      print('음성 명령: 점연결/대각선');
      setState(() {
        // 점연결 모드 토글
        diagonalMode = !diagonalMode;
        print('점연결 모드 ${diagonalMode ? '활성화' : '비활성화'}');

        _isSpeechProcessing = false;
        _isVoiceProcessing = false;
      });

      // 처리 완료 후 플래그 리셋
      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          _isSpeechProcessing = false;
          _isVoiceProcessing = false;
        });
      });
      return;
    }

    // 취소/뒤로 명령
    if (lowerText.contains('취소') || lowerText.contains('뒤로')) {
      print('음성 명령: 취소/뒤로');

      // 되돌리기 실행
      undo();

      setState(() {
        _isSpeechProcessing = false;
        _isVoiceProcessing = false;
      });

      // 처리 완료 후 플래그 리셋
      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          _isSpeechProcessing = false;
          _isVoiceProcessing = false;
        });
      });
      return;
    }

    // 원 명령
    if (lowerText == '원' || lowerText.contains('원 모드')) {
      print('음성 명령: 원');
      setState(() {
        // 원 모드 토글
        circleMode = !circleMode;
        if (circleMode) {
          // 원 모드 활성화 시 다른 모드 비활성화
          diagonalMode = false;
          selectedLineIndex = -1;
          selectedCircleIndex = -1;
          selectedEndpoint = null;
          selectedEndpointLineIndex = null;
          selectedEndpointType = null;
          selectedGroupLines.clear();
        }
        print('원 모드 ${circleMode ? '활성화' : '비활성화'}');

        _isSpeechProcessing = false;
        _isVoiceProcessing = false;
      });

      // 처리 완료 후 플래그 리셋
      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          _isSpeechProcessing = false;
          _isVoiceProcessing = false;
        });
      });
      return;
    }

    // 방향키 명령
    if (lowerText == '위' || lowerText == '위로' || lowerText.contains('위쪽')) {
      print('음성 명령: 위');
      onDirectionKey('Up');

      setState(() {
        _isSpeechProcessing = false;
        _isVoiceProcessing = false;
      });

      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          _isSpeechProcessing = false;
          _isVoiceProcessing = false;
        });
      });
      return;
    }

    if (lowerText == '아래' || lowerText == '아래로' || lowerText.contains('아래쪽')) {
      print('음성 명령: 아래');
      onDirectionKey('Down');

      setState(() {
        _isSpeechProcessing = false;
        _isVoiceProcessing = false;
      });

      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          _isSpeechProcessing = false;
          _isVoiceProcessing = false;
        });
      });
      return;
    }

    if (lowerText == '왼쪽' || lowerText == '좌' || lowerText.contains('왼쪽으로')) {
      print('음성 명령: 왼쪽');
      onDirectionKey('Left');

      setState(() {
        _isSpeechProcessing = false;
        _isVoiceProcessing = false;
      });

      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          _isSpeechProcessing = false;
          _isVoiceProcessing = false;
        });
      });
      return;
    }

    if (lowerText == '오른쪽' || lowerText == '우' || lowerText.contains('오른쪽으로')) {
      print('음성 명령: 오른쪽');
      onDirectionKey('Right');

      setState(() {
        _isSpeechProcessing = false;
        _isVoiceProcessing = false;
      });

      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          _isSpeechProcessing = false;
          _isVoiceProcessing = false;
        });
      });
      return;
    }

    // 초기화 명령
    if (lowerText.contains('초기화') ||
        lowerText.contains('다시') ||
        lowerText.contains('리셋')) {
      print('음성 명령: 초기화');

      // 초기화 실행
      setState(() {
        lines.clear();
        circles.clear();
        currentPoint = const Offset(0, 0);
        selectedLineIndex = -1;
        selectedCircleIndex = -1;
        selectedEndpoint = null;
        selectedEndpointLineIndex = null;
        selectedEndpointType = null;
        diagonalMode = false;
        circleMode = false;
        pendingOpeningType = null;
        selectedGroupLines.clear();
        _lastProcessedNumber = null;
        arrowDirection = null;
        inlineDirection = "";
        showInlineInput = false;
        inlineController.clear();
      });

      // Firebase 업데이트
      _updateFirebase();

      setState(() {
        _isSpeechProcessing = false;
        _isVoiceProcessing = false;
      });

      // 처리 완료 후 플래그 리셋
      Future.delayed(const Duration(milliseconds: 150), () {
        setState(() {
          _isSpeechProcessing = false;
          _isVoiceProcessing = false;
        });
      });
      return;
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
        // 최근에 처리된 숫자인지 확인
        if (_recentlyProcessedNumbers.contains(bestNumber)) {
          print('최근 처리된 숫자 중복 방지: $bestNumber');
          setState(() {
            _isSpeechProcessing = false;
            _isVoiceProcessing = false;
          });
          return;
        }

        // 마지막 처리된 숫자가 현재 숫자에 포함되는지 확인 (예: 1000 < 1300)
        if (_lastProcessedNumber != null &&
            DateTime.now()
                    .difference(_lastSpeechProcessTime ?? DateTime.now())
                    .inMilliseconds <
                1000) {
          // 천(1000) -> 천삼백(1300)처럼 작은 숫자가 큰 숫자에 포함되는 경우
          if (bestNumber > _lastProcessedNumber! &&
              _lastProcessedNumber == 1000 &&
              bestNumber >= 1000 &&
              bestNumber < 2000) {
            print('천 단위 포함 관계 감지 - 이전: $_lastProcessedNumber, 현재: $bestNumber');
            // 이전 선을 삭제하고 새로운 선으로 대체
            if (lines.isNotEmpty) {
              setState(() {
                lines.removeLast();
              });
            }
          }
          // 백(100) -> 백XX처럼 작은 숫자가 큰 숫자에 포함되는 경우
          else if (bestNumber > _lastProcessedNumber! &&
              _lastProcessedNumber == 100 &&
              bestNumber >= 100 &&
              bestNumber < 200) {
            print('백 단위 포함 관계 감지 - 이전: $_lastProcessedNumber, 현재: $bestNumber');
            if (lines.isNotEmpty) {
              setState(() {
                lines.removeLast();
              });
            }
          }
        }

        print('추출된 숫자: $bestNumber');

        // 처리된 숫자 추가
        _recentlyProcessedNumbers.add(bestNumber);
        if (_recentlyProcessedNumbers.length > 5) {
          _recentlyProcessedNumbers.clear();
          _recentlyProcessedNumbers.add(bestNumber);
        }

        // 1초 후 숫자 중복 방지 목록에서 제거
        Future.delayed(const Duration(seconds: 1), () {
          _recentlyProcessedNumbers.remove(bestNumber);
        });

        // 마지막 처리된 숫자 업데이트
        _lastProcessedNumber = bestNumber;

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

    // 처리 완료 후 플래그 리셋 (성능 최적화: 300ms → 150ms)
    Future.delayed(const Duration(milliseconds: 150), () {
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

    // 음성 인식 오류 패턴 수정 (예: "1003백" -> "천삼백")
    processedText =
        processedText.replaceAllMapped(RegExp(r'(\d+)([백천만])'), (match) {
      final number = match.group(1)!;
      final unit = match.group(2)!;

      // 1003백 -> 천삼백
      if (number == '1003' && unit == '백') return '천삼백';
      if (number == '1004' && unit == '백') return '천사백';
      if (number == '1005' && unit == '백') return '천오백';
      if (number == '1006' && unit == '백') return '천육백';
      if (number == '1007' && unit == '백') return '천칠백';
      if (number == '1008' && unit == '백') return '천팔백';
      if (number == '1009' && unit == '백') return '천구백';

      return match.group(0)!;
    });

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
    _dropdownOverlay?.remove();
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
      viewRotation = 0.0;
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
    print('현재 상태 - lines.length: ${lines.length}, currentPoint: $currentPoint');
    print(
        '현재 상태 - selectedLineIndex: $selectedLineIndex, selectedCircleIndex: $selectedCircleIndex');
    print(
        '현재 상태 - arrowDirection: $arrowDirection, isDoubleDirectionPressed: $isDoubleDirectionPressed');

    // 방향키 두 번 누름 감지
    bool wasDoublePressed = false;
    if (arrowDirection == direction && !isDoubleDirectionPressed) {
      wasDoublePressed = true;
      print('방향키 두 번 누름 감지: $direction');
    }

    // 선택된 선이나 원이 있을 때의 처리
    if (selectedLineIndex >= 0 || selectedCircleIndex >= 0) {
      if (selectedCircleIndex >= 0) {
        print('선택된 원이 있음 - 원 이동을 위한 방향키 설정');
        // 원이 선택된 경우 선택 취소하지 않고 방향키만 설정
      } else {
        print('선택된 선이 있음 - 선택 취소하고 방향키 설정');
        // 선이 선택된 경우 선택 취소
      }
    }

    // 자동 음성 모드 제거 - 화살표 버튼 누를 때마다 음성 인식 시작하지 않음
    // 성능 향상을 위해 사용자가 명시적으로 음성 버튼을 누를 때만 음성 인식 시작

    setState(() {
      // 선택된 선/원이 있을 때의 처리
      if (selectedLineIndex >= 0 || selectedCircleIndex >= 0) {
        if (selectedCircleIndex >= 0) {
          // 원이 선택된 경우 선택 상태 유지하고 방향키만 설정
          print('원 선택 상태 유지하고 방향키 설정');
        } else {
          // 선이 선택된 경우 선택 취소 (파란선 그룹 선택은 유지)
          selectedLineIndex = -1;
          selectedCircleIndex = -1;
          print('선 선택 취소 완료 - 그룹 선택 상태: ${selectedGroupLines.length}개');
        }
      }

      // 방향키 두 번 누름 상태 업데이트
      if (wasDoublePressed) {
        isDoubleDirectionPressed = true;
        print('방향키 두 번 누름 상태 활성화');
      } else if (arrowDirection != direction) {
        isDoubleDirectionPressed = false;
        print('다른 방향키 누름 - 두 번 누름 상태 해제');
      }

      arrowDirection = direction;
      inlineDirection = direction;
      lastDirection = direction; // 방향키 클릭 시 마지막 방향 설정

      print('방향키 설정 후 - selectedGroupLines: $selectedGroupLines');

      // 이미 인라인 입력이 표시 중이고 텍스트가 있다면 바로 실행
      if (showInlineInput && inlineController.text.isNotEmpty) {
        print('인라인 입력이 있음 - 즉시 실행');
        // 즉시 선 그리기 실행
        WidgetsBinding.instance.addPostFrameCallback((_) {
          confirmInlineInput();
        });
      } else {
        print('방향키 설정 완료 - 화살표 표시 및 숫자 입력 대기 중');
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

    // 화면 회전을 고려한 방향 변환
    String transformedDirection = _transformDirectionForRotation(direction);
    print('화면 회전 고려 - 원래 방향: $direction, 변환된 방향: $transformedDirection');

    Offset newPoint;
    switch (transformedDirection) {
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
        print('잘못된 방향: $transformedDirection');
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

      // 선 그리기 후 선택된 끝점 해제
      selectedEndpoint = null;
      selectedEndpointLineIndex = null;
      selectedEndpointType = null;
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

  void moveCurrentPointWithDistance(String direction, double distance) {
    print('moveCurrentPointWithDistance 호출됨 - 방향: $direction, 거리: $distance');
    print(
        'moveCurrentPointWithDistance - isProcessingInput: $isProcessingInput');

    // 이미 confirmInlineInput에서 isProcessingInput이 true로 설정되었으므로
    // 여기서는 추가로 설정하지 않음
    if (!isProcessingInput) {
      print('처리 중 상태가 아님 - 예상치 못한 호출');
      isProcessingInput = true;
    }

    // 화면 회전을 고려한 방향 변환
    String transformedDirection = _transformDirectionForRotation(direction);
    print('화면 회전 고려 - 원래 방향: $direction, 변환된 방향: $transformedDirection');

    Offset newPoint;
    switch (transformedDirection) {
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
        print('잘못된 방향: $transformedDirection');
        isProcessingInput = false;
        return;
    }

    print('점 이동: $currentPoint -> $newPoint');

    saveState();

    setState(() {
      // 방향키 두 번 누른 상태에서는 선을 수정하지 않고 currentPoint만 이동
      currentPoint = newPoint;

      // 선택된 끝점 해제 (새로운 위치로 이동했으므로)
      selectedEndpoint = null;
      selectedEndpointLineIndex = null;
      selectedEndpointType = null;

      lastDirection = direction; // 마지막 방향 저장
      isProcessingInput = false;
      isDoubleDirectionPressed = false; // 점 이동 후 두 번 누름 상태 해제
    });

    print('점 이동 완료 - 새 위치: $currentPoint');

    _updateFirebase();

    // 모바일/태블릿에서는 새 점이 화면에 보이도록 뷰 조정
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

    if (distance == null || distance < 0) {
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
    print('원 모드 상태 - circleMode: $circleMode, circleCenter: $circleCenter');

    // 원 모드에서 지름 입력
    if (circleMode && circleCenter != null) {
      print('✅ 원 생성 모드 진입: 중심점 $circleCenter, 지름 $distance');

      // 원 생성 전 유효성 검사
      if (distance <= 0) {
        print('원 생성 오류: 지름이 0 이하입니다 ($distance)');
        setState(() {
          showInlineInput = false;
          isProcessingInput = false;
          circleMode = false;
          circleCenter = null;
          arrowDirection = null;
        });
        print('원 생성 실패 - circleMode 해제 (지름 오류)');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
        });
        return;
      }

      final radius = distance / 2; // 지름을 반지름으로 변환

      // 반지름 유효성 검사
      if (radius <= 0 || radius.isNaN || radius.isInfinite) {
        print('원 생성 오류: 반지름이 유효하지 않습니다 ($radius)');
        setState(() {
          showInlineInput = false;
          isProcessingInput = false;
          circleMode = false;
          circleCenter = null;
          arrowDirection = null;
        });
        print('원 생성 실패 - circleMode 해제 (반지름 오류)');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
        });
        return;
      }

      saveState();

      try {
        circles.add(Circle(
          center: circleCenter!,
          radius: radius,
        ));
        print('원 생성 성공: 중심점 $circleCenter, 반지름 $radius');

        // 생성된 원을 선택 상태로 설정
        final newCircleIndex = circles.length - 1;

        setState(() {
          showInlineInput = false;
          isProcessingInput = false;
          circleMode = false;
          circleCenter = null;
          arrowDirection = null;
          inlineDirection = "";
          // 새로 생성된 원을 선택 상태로 설정
          selectedCircleIndex = newCircleIndex;
          selectedLineIndex = -1; // 선 선택 해제
        });

        print('원 생성 완료 - circleMode 해제');
        _updateFirebase();
      } catch (e) {
        print('원 생성 중 오류 발생: $e');
        setState(() {
          showInlineInput = false;
          isProcessingInput = false;
          circleMode = false;
          circleCenter = null;
          arrowDirection = null;
          isDoubleDirectionPressed = false;
        });
        print('원 생성 실패 - circleMode 해제');
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
      return;
    }

    // 파란선 그룹 이동 처리 (selectedGroupLines가 있을 때)
    if (selectedGroupLines.isNotEmpty && arrowDirection != null) {
      print(
          '파란선 그룹 이동 모드 - 선택된 선: ${selectedGroupLines.length}개, 방향: $arrowDirection, 거리: $distance');
      saveState();

      // 화면 회전을 고려한 방향 변환
      String transformedDirection =
          _transformDirectionForRotation(arrowDirection!);

      // 이동 오프셋 계산
      Offset moveOffset;
      switch (transformedDirection) {
        case 'Up':
          moveOffset = Offset(0, distance); // 위로 이동 = Y 증가
          break;
        case 'Down':
          moveOffset = Offset(0, -distance); // 아래로 이동 = Y 감소
          break;
        case 'Left':
          moveOffset = Offset(-distance, 0);
          break;
        case 'Right':
          moveOffset = Offset(distance, 0);
          break;
        default:
          print('잘못된 방향: $transformedDirection');
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

      setState(() {
        // 선택된 모든 선들을 이동
        for (int lineIndex in selectedGroupLines) {
          if (lineIndex >= 0 && lineIndex < lines.length) {
            lines[lineIndex].start = lines[lineIndex].start + moveOffset;
            lines[lineIndex].end = lines[lineIndex].end + moveOffset;
          }
        }

        showInlineInput = false;
        isProcessingInput = false;
        arrowDirection = null;
        inlineDirection = "";
        inlineController.clear();
      });

      _updateFirebase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
      return;
    }

    // 원 이동 모드 (선택된 원이 있고 방향키가 설정된 경우)
    if (selectedCircleIndex >= 0 && arrowDirection != null) {
      print(
          '원 이동 모드: 원 인덱스 $selectedCircleIndex, 방향 $arrowDirection, 거리 $distance');

      if (selectedCircleIndex >= 0 && selectedCircleIndex < circles.length) {
        saveState();

        final circle = circles[selectedCircleIndex];
        Offset newCenter;

        switch (arrowDirection) {
          case 'Up':
            newCenter = Offset(circle.center.dx, circle.center.dy + distance);
            break;
          case 'Down':
            newCenter = Offset(circle.center.dx, circle.center.dy - distance);
            break;
          case 'Left':
            newCenter = Offset(circle.center.dx - distance, circle.center.dy);
            break;
          case 'Right':
            newCenter = Offset(circle.center.dx + distance, circle.center.dy);
            break;
          default:
            print('잘못된 방향: $arrowDirection');
            setState(() {
              showInlineInput = false;
              isProcessingInput = false;
              arrowDirection = null;
              isDoubleDirectionPressed = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _focusNode.requestFocus();
            });
            return;
        }

        setState(() {
          circles[selectedCircleIndex] = Circle(
            center: newCenter,
            radius: circle.radius,
          );
          showInlineInput = false;
          isProcessingInput = false;
          arrowDirection = null;
          inlineDirection = "";
          isDoubleDirectionPressed = false;
          // 원 선택 상태 유지
        });

        print('원 이동 완료: 새 중심점 $newCenter');
        _updateFirebase();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
        });
        return;
      }
    }

    if (selectedLineIndex >= 0 && arrowDirection == null) {
      print('선 길이 수정 모드: $selectedLineIndex to length $distance');
      saveState();
      modifyLineLength(selectedLineIndex, distance);
      setState(() {
        showInlineInput = false;
        isProcessingInput = false;
        arrowDirection = null;
        isDoubleDirectionPressed = false;
        selectedLineIndex = -1; // 수정 후 선택 해제
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
      return;
    }

    // 방향키 두 번 누름 상태에서는 점 이동, 그렇지 않으면 선 그리기
    String direction = inlineDirection.isNotEmpty
        ? inlineDirection
        : (arrowDirection ?? 'Right');

    if (isDoubleDirectionPressed) {
      print('점 이동 시작 - 방향: $direction, 거리: $distance');
      print('현재 점: $currentPoint');

      // 점 이동 함수 호출
      moveCurrentPointWithDistance(direction, distance);
    } else {
      print('선 그리기 시작 - 방향: $direction, 거리: $distance');
      print('현재 점: $currentPoint');

      // 선 그리기 함수 호출
      drawLineWithDistance(direction, distance);
    }

    setState(() {
      showInlineInput = false;
      arrowDirection = null;
      inlineDirection = "";
      // 두 번 누름 상태는 moveCurrentPointWithDistance 함수 내부에서 초기화됨
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
      isDoubleDirectionPressed = false;
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

        // 원 모드에서 중심점이 설정되어 있으면 지름 입력 모드
        if (circleMode && circleCenter != null) {
          print('원 모드 - 지름 입력 모드로 전환');
          arrowDirection = null;
          inlineDirection = "";
        } else if (selectedCircleIndex >= 0) {
          // 선택된 원이 있으면 원 이동 모드
          // 방향키 설정은 그대로 유지 (원 이동을 위해)
          print('원 선택됨 - 원 이동 모드: 방향키 유지');
        } else if (selectedLineIndex >= 0) {
          // 선택된 선이 있으면 길이 수정 모드
          // 방향키 설정은 그대로 유지
        } else if (arrowDirection != null || inlineDirection.isNotEmpty) {
          // 방향키가 설정되어 있으면 해당 방향으로 새 선 그리기 모드
          print('방향키 설정됨 - 새 선 그리기 모드: $arrowDirection / $inlineDirection');
        } else if (lines.isNotEmpty && !circleMode) {
          // 원 모드가 아니고, 방향키가 없고 선이 존재하면 마지막 선 수정 모드
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
        // 숫자 입력 중이 아니면 선/원/거리측정 삭제
        print(
            'Del 키 처리 - selectedLineIndex: $selectedLineIndex, selectedCircleIndex: $selectedCircleIndex, selectedMeasurementIndex: $selectedMeasurementIndex');
        if (selectedMeasurementIndex != null) {
          // 선택된 거리측정이 있으면 삭제
          print('Del 버튼: 선택된 거리측정 삭제 (인덱스: $selectedMeasurementIndex)');
          setState(() {
            distanceMeasurements.removeAt(selectedMeasurementIndex!);
            selectedMeasurementIndex = null;
          });
        } else if (selectedCircleIndex >= 0) {
          // 선택된 원이 있으면 해당 원 삭제
          print('Del 버튼: 선택된 원 삭제 (인덱스: $selectedCircleIndex)');
          deleteSelectedCircle();
        } else if (selectedLineIndex >= 0) {
          // 선택된 선이 있으면 해당 선 삭제
          print('Del 버튼: 선택된 선 삭제 (인덱스: $selectedLineIndex)');
          deleteSelectedLine();
        } else {
          // 선택된 것이 없으면 가장 최근에 추가된 것 삭제
          int? lastLineTimestamp =
              lines.isNotEmpty ? lines.last.timestamp : null;
          int? lastCircleTimestamp =
              circles.isNotEmpty ? circles.last.timestamp : null;
          int? lastMeasurementTimestamp = distanceMeasurements.isNotEmpty
              ? distanceMeasurements.last.timestamp
              : null;

          int maxTimestamp = -1;
          String? deleteType;

          if (lastLineTimestamp != null && lastLineTimestamp > maxTimestamp) {
            maxTimestamp = lastLineTimestamp;
            deleteType = 'line';
          }
          if (lastCircleTimestamp != null &&
              lastCircleTimestamp > maxTimestamp) {
            maxTimestamp = lastCircleTimestamp;
            deleteType = 'circle';
          }
          if (lastMeasurementTimestamp != null &&
              lastMeasurementTimestamp > maxTimestamp) {
            maxTimestamp = lastMeasurementTimestamp;
            deleteType = 'measurement';
          }

          if (deleteType == 'line') {
            print('Del 버튼: 마지막 선 삭제');
            deleteLastLine();
          } else if (deleteType == 'circle') {
            print('Del 버튼: 마지막 원 삭제');
            deleteLastCircle();
          } else if (deleteType == 'measurement') {
            print('Del 버튼: 마지막 거리측정 삭제');
            setState(() {
              distanceMeasurements.removeLast();
            });
          }
        }
      }
    } else if (key == 'Ent') {
      print(
          'Enter 키 눌림 - showInlineInput: $showInlineInput, circleMode: $circleMode, circleCenter: $circleCenter');
      if (showInlineInput) {
        print('인라인 입력 확인 호출');
        confirmInlineInput();
      } else {
        print('인라인 입력 모드로 전환');
        // 인라인 입력이 없는 상태에서 Enter를 누르면 기본 동작
        setState(() {
          showInlineInput = true;
          inlineController.text = '';

          // 원 모드에서 중심점이 설정되어 있으면 지름 입력 모드
          if (circleMode && circleCenter != null) {
            print('원 모드 - Enter로 지름 입력 모드 전환');
            arrowDirection = null;
            inlineDirection = "";
          } else if (selectedCircleIndex >= 0) {
            // 선택된 원이 있으면 원 이동 모드 - 방향키 유지
            print('원 선택됨 - Enter로 원 이동 모드 전환');
          } else if (inlineDirection.isEmpty && arrowDirection == null) {
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

    // 길이가 0이 되는 경우 특별 처리
    if (newLength == 0) {
      print('선 길이를 0으로 변경 - 연결된 모든 선들 이동');

      // 일반적인 길이 수정처럼 끝점을 시작점으로 이동시키되 선은 삭제
      final oldEnd = line.end;
      final newEnd = line.start; // 길이가 0이므로 끝점을 시작점으로

      setState(() {
        // 대각선이든 아니든 연결된 모든 요소들을 이동시킴
        // 연결된 모든 요소들을 이동시키는 함수
        void moveConnectedElements(
            Offset oldPoint, Offset newPoint, Set<int> visitedLines) {
          final pointShift = Offset(
            newPoint.dx - oldPoint.dx,
            newPoint.dy - oldPoint.dy,
          );

          for (int i = 0; i < lines.length; i++) {
            if (visitedLines.contains(i) || i == index) continue; // 현재 선은 제외

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

        // 길이가 0인 선 삭제
        lines.removeAt(index);

        // 선택 상태 초기화
        selectedLineIndex = -1;

        // 대각선 연결 정보 업데이트
        for (final line in lines) {
          if (line.isDiagonal && line.connectedPoints != null) {
            final startInfo = line.connectedPoints!['start'] as List<int>;
            final endInfo = line.connectedPoints!['end'] as List<int>;

            // 삭제된 선을 참조하는 경우 -1로 설정
            if (startInfo[0] == index) {
              startInfo[0] = -1;
            } else if (startInfo[0] > index) {
              startInfo[0]--;
            }

            if (endInfo[0] == index) {
              endInfo[0] = -1;
            } else if (endInfo[0] > index) {
              endInfo[0]--;
            }
          }
        }
      });

      _updateFirebase();
      return;
    }

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

  // 주어진 점에 연결된 모든 선들을 찾는 함수
  Set<int> findConnectedLines(Offset point) {
    Set<int> connectedLines = {};
    Set<Offset> visitedPoints = {};

    void findConnected(Offset currentPoint) {
      if (visitedPoints.contains(currentPoint)) return;
      visitedPoints.add(currentPoint);

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        bool isConnected = false;
        Offset? nextPoint;

        if ((line.start.dx - currentPoint.dx).abs() < 0.01 &&
            (line.start.dy - currentPoint.dy).abs() < 0.01) {
          isConnected = true;
          nextPoint = line.end;
        } else if ((line.end.dx - currentPoint.dx).abs() < 0.01 &&
            (line.end.dy - currentPoint.dy).abs() < 0.01) {
          isConnected = true;
          nextPoint = line.start;
        }

        if (isConnected && !connectedLines.contains(i)) {
          connectedLines.add(i);
          if (nextPoint != null) {
            findConnected(nextPoint);
          }
        }
      }
    }

    findConnected(point);
    return connectedLines;
  }

  // 드래그 중인 그룹의 스냅 정보
  Map<String, Offset>? groupSnapInfo;

  // 드래그 중인 그룹과 다른 그룹의 끝점 중 가장 가까운 점 찾기
  Map<String, Offset>? findNearestSnapPoint() {
    Offset? nearestSnapPoint;
    Offset? correspondingGroupPoint;
    double minDistance = double.infinity;
    const double snapThreshold = 30.0; // 스냅 거리 임계값

    // 드래그 중인 그룹의 모든 끝점에 대해 검사
    for (int groupLineIdx in draggedGroupLines) {
      if (groupLineIdx >= lines.length) continue;
      final groupLine = lines[groupLineIdx];

      // 그룹의 각 끝점에 대해
      for (final groupPoint in [groupLine.start, groupLine.end]) {
        // 다른 모든 선의 끝점과 비교
        for (int i = 0; i < lines.length; i++) {
          if (draggedGroupLines.contains(i)) continue; // 드래그 중인 그룹은 제외

          final line = lines[i];

          // 시작점 검사
          final startDist = (line.start - groupPoint).distance;
          if (startDist < minDistance && startDist < snapThreshold) {
            minDistance = startDist;
            nearestSnapPoint = line.start;
            correspondingGroupPoint = groupPoint;
          }

          // 끝점 검사
          final endDist = (line.end - groupPoint).distance;
          if (endDist < minDistance && endDist < snapThreshold) {
            minDistance = endDist;
            nearestSnapPoint = line.end;
            correspondingGroupPoint = groupPoint;
          }
        }

        // 빨간 점(선택된 끝점)과도 비교
        if (selectedEndpoint != null) {
          final redPointDist = (selectedEndpoint! - groupPoint).distance;
          if (redPointDist < minDistance && redPointDist < snapThreshold) {
            minDistance = redPointDist;
            nearestSnapPoint = selectedEndpoint;
            correspondingGroupPoint = groupPoint;
          }
        }
      }
    }

    // 스냅할 점을 찾았으면, 그룹 점과 스냅 대상 점의 정보 반환
    if (nearestSnapPoint != null && correspondingGroupPoint != null) {
      return {
        'snapTarget': nearestSnapPoint,
        'groupPoint': correspondingGroupPoint,
      };
    }

    return null;
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

  void deleteLastCircle() {
    if (circles.isEmpty) {
      print('deleteLastCircle: 삭제할 원이 없음');
      return;
    }

    final lastIndex = circles.length - 1;
    print('deleteLastCircle: 마지막 원 삭제 시작 - 인덱스: $lastIndex');

    saveState();

    setState(() {
      try {
        // 원 삭제
        circles.removeAt(lastIndex);
        print('deleteLastCircle: 원 삭제 완료 - 남은 원 개수: ${circles.length}');

        // 선택 상태 초기화
        selectedCircleIndex = -1;
        selectedLineIndex = -1;
      } catch (e) {
        print('deleteLastCircle: 오류 발생 - $e');
        // 오류 발생 시 안전하게 상태 초기화
        selectedCircleIndex = -1;
        selectedLineIndex = -1;
      }
    });

    _updateFirebase();
    print('deleteLastCircle: 완료');
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

    // 페이지 드롭다운이 열려있으면 닫기
    if (isPageDropdownOpen) {
      _hideDropdownOverlay();
    }

    // 점 드래그 중이면 탭 무시
    if (isPointDragging) {
      print('점 드래그 중 - 탭 무시');
      return;
    }

    // 원 모드 처리
    if (circleMode) {
      print('원 모드로 이동');
      // 원 모드에서는 인라인 입력을 취소하지 않음 (다른 끝점 클릭 시 위치 이동을 위해)
      _handleCircleClick(position);
      return; // 원 모드에서는 다른 처리 없이 즉시 종료
    }

    // 일반 모드 처리
    // 빈 화면 클릭 시 인라인 입력을 유지 (삭제됨)
    // if (showInlineInput) {
    //   cancelInlineInput();
    // }

    // 원 모드가 아닐 때만 끝점 이동 처리
    if (!circleMode) {
      final endpointInfo = _findEndpointNear(position);

      if (endpointInfo != null) {
        final clickedPoint = endpointInfo['point'] as Offset;

        // 거리측정 모드일 때 끝점 클릭 처리
        if (distanceMeasureMode) {
          print('거리측정 모드 - 점 클릭: $clickedPoint');
          if (firstSelectedPointForDistance == null &&
              firstSelectedLineForDistance == null) {
            // 첫 번째 점 선택
            setState(() {
              firstSelectedPointForDistance = clickedPoint;
              selectedEndpoint = clickedPoint;
              currentPoint = clickedPoint;
            });
            print('첫 번째 점 선택됨');
          } else if (firstSelectedPointForDistance == clickedPoint) {
            // 같은 점을 다시 클릭하면 선택 해제
            setState(() {
              firstSelectedPointForDistance = null;
              selectedEndpoint = null;
            });
            print('점 선택 해제');
          } else if (firstSelectedPointForDistance != null) {
            // 점이 선택된 상태에서 다른 점 클릭 - 점과 점 사이 거리 측정
            final measurement = _calculatePointToPointDistance(
                firstSelectedPointForDistance!, clickedPoint);
            if (measurement != null) {
              setState(() {
                distanceMeasurements.add(measurement);
                firstSelectedPointForDistance = null;
                selectedEndpoint = null;
                distanceMeasureMode = false;
              });
              print('점-점 거리 측정 완료: ${measurement.distance.toInt()}');
            }
          } else if (firstSelectedLineForDistance != null) {
            // 선이 선택된 상태에서 점 클릭 - 선과 점 사이 거리 측정
            final measurement = _calculatePointToLineDistance(
                clickedPoint, firstSelectedLineForDistance!);
            if (measurement != null) {
              setState(() {
                distanceMeasurements.add(measurement);
                firstSelectedLineForDistance = null;
                selectedLineIndex = -1;
                selectedEndpoint = null;
                distanceMeasureMode = false;
              });
              print('선-점 거리 측정 완료: ${measurement.distance.toInt()}');
            }
          }
          return;
        }

        setState(() {
          // 이미 선택된 끝점을 다시 클릭하면 선택 해제
          if (selectedEndpoint == clickedPoint) {
            selectedEndpoint = null;
            selectedEndpointLineIndex = null;
            selectedEndpointType = null;
          } else {
            // 새로운 끝점 선택하고 currentPoint도 변경
            selectedEndpoint = clickedPoint;
            currentPoint = clickedPoint;
            selectedEndpointLineIndex = endpointInfo['index'] as int?;
            selectedEndpointType = endpointInfo['type'] as String?;
          }

          // 끝점 클릭 시 선/원 선택 상태 초기화
          selectedLineIndex = -1;
          selectedCircleIndex = -1;
          hoveredLineIndex = null;

          // 화살표 상태 초기화 (다른 점을 클릭했으므로)
          arrowDirection = null;
          inlineDirection = "";
          isDoubleDirectionPressed = false;
        });
        _updateFirebase();
        return;
      }
    }

    // 거리측정선 클릭 감지 (선/원 선택보다 우선, 거리측정 모드가 아닐 때)
    if (!circleMode && !distanceMeasureMode) {
      final clickedMeasurementIndex = _findMeasurementNear(position);
      if (clickedMeasurementIndex != null) {
        setState(() {
          selectedMeasurementIndex = clickedMeasurementIndex;
          selectedLineIndex = -1;
          selectedCircleIndex = -1;
        });
        print('거리측정선 선택됨: $clickedMeasurementIndex');
        return;
      }
    }

    // 원 모드가 아닐 때만 선/원 선택 처리
    if (!circleMode) {
      final lineIndex = _findLineNear(position);
      final circleIndex = _findCircleNear(position);

      if (lineIndex != null) {
        // 더블클릭 감지
        final now = DateTime.now();
        final isDoubleClick = lastTapTime != null &&
            now.difference(lastTapTime!).inMilliseconds < 300 &&
            selectedLineIndex == lineIndex;

        if (isDoubleClick) {
          // 더블클릭: 연결된 모든 선 선택
          print('선 더블클릭 - 연결된 모든 선 선택');
          final line = lines[lineIndex];

          // 시작점과 끝점에서 연결된 모든 선 찾기
          final connectedFromStart = findConnectedLines(line.start);
          final connectedFromEnd = findConnectedLines(line.end);

          setState(() {
            // 클릭한 선 자체도 포함하여 그룹 설정
            selectedGroupLines = {
              lineIndex,
              ...connectedFromStart,
              ...connectedFromEnd
            };
            selectedLineIndex = lineIndex;
            selectedCircleIndex = -1;
            lastTapTime = null; // 더블클릭 후 리셋
            print('더블클릭 - 선택된 그룹: $selectedGroupLines');
          });

          HapticFeedback.selectionClick();
        } else if (distanceMeasureMode) {
          // 거리측정 모드에서 선 클릭
          print('거리측정 모드 - 선 클릭: $lineIndex');
          if (firstSelectedLineForDistance == null &&
              firstSelectedPointForDistance == null) {
            // 첫 번째 선 선택
            setState(() {
              firstSelectedLineForDistance = lineIndex;
              selectedLineIndex = lineIndex;
              selectedCircleIndex = -1;
            });
            print('첫 번째 선 선택됨: $lineIndex');
          } else if (firstSelectedLineForDistance == lineIndex) {
            // 같은 선을 다시 클릭하면 선택 해제
            setState(() {
              firstSelectedLineForDistance = null;
              selectedLineIndex = -1;
            });
            print('선 선택 해제');
          } else if (firstSelectedPointForDistance != null) {
            // 점이 선택된 상태에서 선 클릭 - 점과 선 사이 거리 측정
            final measurement = _calculatePointToLineDistance(
                firstSelectedPointForDistance!, lineIndex);
            if (measurement != null) {
              setState(() {
                distanceMeasurements.add(measurement);
                firstSelectedPointForDistance = null;
                selectedLineIndex = -1;
                distanceMeasureMode = false;
              });
              print('점-선 거리 측정 완료: ${measurement.distance.toInt()}');
            }
          } else {
            // 선이 선택된 상태에서 다른 선 클릭 - 선과 선 사이 거리 측정
            final measurement = _calculateLineToLineDistance(
                firstSelectedLineForDistance!, lineIndex);
            if (measurement != null) {
              setState(() {
                distanceMeasurements.add(measurement);
                firstSelectedLineForDistance = null;
                selectedLineIndex = -1;
                distanceMeasureMode = false; // 측정 후 자동 비활성화
              });
              print('선-선 거리 측정 완료: ${measurement.distance.toInt()}');
            }
          }
        } else if (arrowDirection != null) {
          // 화살표가 표시된 상태에서 선을 클릭하면 길이 수정 모드로 전환
          print('화살표 상태에서 선 클릭 - 길이 수정 모드로 전환 (팝업은 숫자 입력 시 표시)');
          setState(() {
            selectedLineIndex = lineIndex;
            selectedCircleIndex = -1;
            selectedGroupLines.clear(); // 그룹 선택 해제
            // 화살표 상태 초기화하지만 인라인 입력 모드는 바로 표시하지 않음
            arrowDirection = null;
            inlineDirection = "";
            showInlineInput = false; // 팝업은 숫자 입력 시 표시
            inlineController.clear();
            lastTapTime = now;
          });

          // 포커스는 메인으로 유지 (숫자 입력을 위해)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _focusNode.requestFocus();
          });
        } else {
          // 일반 선택 모드
          setState(() {
            selectedLineIndex = lineIndex;
            selectedCircleIndex = -1; // 원 선택 해제
            selectedGroupLines.clear(); // 그룹 선택 해제
            lastTapTime = now;
          });
        }
      } else if (circleIndex != null) {
        // 원 선택
        setState(() {
          selectedCircleIndex = circleIndex;
          selectedLineIndex = -1; // 선 선택 해제
        });
      } else {
        // 빈 화면 클릭 - 더블클릭 감지
        final now = DateTime.now();
        final isDoubleClick = lastTapTime != null &&
            now.difference(lastTapTime!).inMilliseconds < 300;

        if (isDoubleClick) {
          // 더블클릭: 뷰 맞춤 실행 (모든 모드에서 동일하게 fitViewToDrawing 사용)
          print('빈 화면 더블클릭 - 뷰 맞춤 실행');
          fitViewToDrawing();
          setState(() {
            lastTapTime = null; // 더블클릭 후 리셋
          });
        } else {
          // 일반 클릭
          setState(() {
            selectedLineIndex = -1;
            selectedCircleIndex = -1;
            selectedMeasurementIndex = null; // 거리측정 선택 해제
            // 파란선 그룹이 선택되어 있는 경우에는 selectedEndpoint를 유지
            if (selectedGroupLines.isEmpty) {
              selectedEndpoint = null; // 빈 곳 클릭 시 끝점 선택도 해제
              selectedEndpointLineIndex = null;
              selectedEndpointType = null;
            }
            selectedGroupLines.clear(); // 그룹 선택 해제
            lastTapTime = now;

            // 빈 곳 클릭 시에는 화살표 상태를 유지
          });
        }
      }
    }
  }

  void _handleCircleClick(Offset position) {
    print('원 클릭: $position');

    // 가장 가까운 끝점 찾기
    final endpointInfo = _findEndpointNear(position);
    Offset? closestPoint = endpointInfo?['point'] as Offset?;

    print('끝점 찾기 결과: $endpointInfo');

    // 끝점을 찾지 못하면 원을 생성하지 않음
    if (closestPoint == null) {
      print('끝점을 찾지 못함 - 원 생성 취소');
      return;
    }

    final centerPoint = closestPoint;

    print('원 중심점 후보: $centerPoint (끝점 발견: true)');

    // 중심점 유효성 검사
    if (centerPoint.dx.isNaN ||
        centerPoint.dy.isNaN ||
        centerPoint.dx.isInfinite ||
        centerPoint.dy.isInfinite) {
      print('원 중심점 오류: 유효하지 않은 좌표 ($centerPoint)');
      return;
    }

    // 인라인 입력이 표시되어 있고 원이 아직 생성되지 않은 상태에서 다른 끝점 클릭
    print(
        '원 모드 체크 - showInlineInput: $showInlineInput, circleCenter: $circleCenter, circleMode: $circleMode');
    if (showInlineInput && circleCenter != null && circleMode) {
      print('원 중심점 변경 조건 만족!');
      print('이전 중심점: $circleCenter');
      print('새로운 중심점: $centerPoint');

      setState(() {
        circleCenter = centerPoint;
        // 입력된 텍스트는 유지
      });

      print('setState 후 circleCenter: $circleCenter');

      // 포커스 유지
      WidgetsBinding.instance.addPostFrameCallback((_) {
        inlineFocus.requestFocus();
      });
      return;
    }

    // 첫 번째 클릭 또는 새로운 원 생성
    if (circleCenter == null) {
      setState(() {
        circleCenter = centerPoint;
        // 원 중심점 설정 시 모든 선택 상태 초기화
        selectedLineIndex = -1;
        selectedCircleIndex = -1;
        hoveredLineIndex = null;
      });
      print('원 중심점 설정 완료: $circleCenter (선택 상태 초기화)');

      // 지름 입력 모드로 전환
      setState(() {
        showInlineInput = true;
        inlineController.clear();
        arrowDirection = null;
        inlineDirection = "";
      });

      print('지름 입력 모드로 전환 완료');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        inlineFocus.requestFocus();
      });
    }
  }

  // 점 간 드래그 선 그리기 함수들
  void _handleCirclePanStart(DragStartDetails details) {
    print('=== 원 모드 화면 이동 시작 ===');
    final position = details.localPosition;
    setState(() {
      _isPanning = true;
      _lastPanPosition = position;
      isPointDragging = false;
    });
    print('원 모드 화면 이동 시작: $position');
  }

  void _handlePointDragStart(DragStartDetails details) {
    // 원 모드 중이면 무시 (인라인 입력 중에는 화면 이동 허용)
    if (circleMode) {
      print('원 모드 중 - 점 드래그 무시');
      return;
    }

    final position = details.localPosition;
    print('\n=== 점연결 드래그 시작: 터치위치=$position ===');

    // 터치/클릭 위치 업데이트 (디버깅용)
    setState(() {
      mousePosition = position;
    });

    final startPoint = _findNearestEndpoint(position);
    print('끝점 찾기 결과: ${startPoint != null ? "찾음 $startPoint" : "못찾음"}');

    // 그룹이 선택된 상태에서는 화면 아무 곳이나 드래그해도 그룹 이동
    print('그룹 선택 확인 - selectedGroupLines: ${selectedGroupLines.length}개');
    if (selectedGroupLines.isNotEmpty) {
      print('그룹이 선택됨 - 화면 아무 곳 드래그로 그룹 이동 시작');

      // 드래그 시작 위치를 모델 좌표로 변환
      final dragStartModelPos = _screenToModel(position);

      setState(() {
        isGroupDragging = true;
        groupDragStartPoint = dragStartModelPos;
        groupDragCurrentPoint = dragStartModelPos;
        draggedGroupLines = Set.from(selectedGroupLines);

        // 원래 위치 저장
        originalLineStarts.clear();
        originalLineEnds.clear();
        for (int i in draggedGroupLines) {
          if (i < lines.length) {
            originalLineStarts[i] = lines[i].start;
            originalLineEnds[i] = lines[i].end;
          }
        }

        _isPanning = false;
        _isScaling = false;
        isPointDragging = false;
      });

      HapticFeedback.selectionClick();
      return;
    }

    // 대각선 모드가 아니고 그룹도 선택되지 않았거나 인라인 입력 중이면 화면 이동만 허용
    if ((!diagonalMode && selectedGroupLines.isEmpty) || showInlineInput) {
      print('대각선 모드가 아니고 그룹도 선택되지 않았거나 인라인 입력 중 - 점 드래그 비활성화, 화면 이동만 허용');
      // 대각선 모드가 아니고 그룹도 선택되지 않았거나 인라인 입력 중일 때는 화면 이동만 허용
      setState(() {
        _isPanning = true;
        _lastPanPosition = position;
        isPointDragging = false;
      });
      print(
          '화면 이동 시작: $position (대각선 모드: $diagonalMode, 그룹 선택: ${selectedGroupLines.length}개, 인라인 입력: $showInlineInput)');
      return;
    }

    // 아이패드 웹에서 멀티터치 중이면 무시
    if (isTablet && _touchCount > 1) {
      print('아이패드 웹 - 멀티터치 중이므로 점 드래그 무시');
      return;
    }

    // Shift 키가 눌려있거나 그룹이 선택된 상태에서 끝점 근처에서 시작한 경우 그룹 드래그 시작
    final isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.shiftRight);

    // Shift 키를 누른 상태에서 끝점 드래그 (기존 기능)
    if (isShiftPressed && startPoint != null) {
      print('Shift + 드래그로 그룹 이동 시작: $startPoint');
      setState(() {
        isGroupDragging = true;
        groupDragStartPoint = startPoint;
        groupDragCurrentPoint = startPoint;
        draggedGroupLines = findConnectedLines(startPoint);

        // 원래 위치 저장
        originalLineStarts.clear();
        originalLineEnds.clear();
        for (int i in draggedGroupLines) {
          originalLineStarts[i] = lines[i].start;
          originalLineEnds[i] = lines[i].end;
        }

        _isPanning = false;
        _isScaling = false;
        isPointDragging = false;
      });

      HapticFeedback.selectionClick();
      return;
    }

    // 점 근처에서 시작한 경우에만 점 드래그 시작 (그룹이 선택되지 않은 경우에만)
    if (startPoint != null && selectedGroupLines.isEmpty && diagonalMode) {
      setState(() {
        isPointDragging = true;
        pointDragStart = startPoint;
        pointDragEnd = startPoint;
        _isPanning = false; // 점 드래그 중에는 화면 이동 비활성화
        _isScaling = false; // 점 드래그 중에는 스케일 제스처 비활성화

        // 다른 선택 상태 초기화
        selectedLineIndex = -1;
        selectedCircleIndex = -1;
        hoveredLineIndex = null;
        // 점 드래그 시에만 selectedEndpoint 초기화 (그룹 드래그와 무관)
        selectedEndpoint = null;
        selectedEndpointLineIndex = null;
        selectedEndpointType = null;
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

    print(
        '드래그 업데이트 - isGroupDragging: $isGroupDragging, isPointDragging: $isPointDragging');

    if (isGroupDragging && groupDragStartPoint != null) {
      // 그룹 드래그 처리
      final currentModelPos = _screenToModel(position);
      final offset = currentModelPos - groupDragStartPoint!;

      print('그룹 드래그 중 - offset: $offset');

      setState(() {
        groupDragCurrentPoint = currentModelPos;

        // 드래그 중인 그룹의 모든 선들을 이동
        for (int i in draggedGroupLines) {
          if (originalLineStarts.containsKey(i) &&
              originalLineEnds.containsKey(i)) {
            lines[i].start = originalLineStarts[i]! + offset;
            lines[i].end = originalLineEnds[i]! + offset;
          }
        }

        // 스냅 대상 찾기
        groupSnapInfo = findNearestSnapPoint();
        if (groupSnapInfo != null) {
          print('스냅 대상 발견: ${groupSnapInfo!['snapTarget']}');
          snapTargetPoint = groupSnapInfo!['snapTarget'];
        } else {
          snapTargetPoint = null;
        }
      });
    } else if (isPointDragging && pointDragStart != null) {
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

    if (isGroupDragging && groupDragStartPoint != null) {
      print('그룹 드래그 종료 처리');

      // 스냅 대상이 있으면 그 위치로 정확히 이동
      if (groupSnapInfo != null) {
        final snapTarget = groupSnapInfo!['snapTarget'] as Offset;
        final groupPoint = groupSnapInfo!['groupPoint'] as Offset;

        // 스냅을 위한 오프셋 계산
        final snapOffset = snapTarget - groupPoint;

        setState(() {
          // 최종 위치로 이동
          for (int i in draggedGroupLines) {
            lines[i].start = lines[i].start + snapOffset;
            lines[i].end = lines[i].end + snapOffset;
          }
        });

        // 햅틱 피드백
        HapticFeedback.mediumImpact();
      }

      // 상태 초기화
      setState(() {
        isGroupDragging = false;
        groupDragStartPoint = null;
        groupDragCurrentPoint = null;
        draggedGroupLines.clear();
        originalLineStarts.clear();
        originalLineEnds.clear();
        snapTargetPoint = null;
        groupSnapInfo = null;
      });

      _updateFirebase();
      saveState();
      return;
    }

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

      // 끝점이 스냅된 위치인지 확인 (허공에 놓으면 취소)
      final screenEndPoint = _modelToScreen(pointDragEnd!);
      final snapPoint = _findNearestEndpoint(screenEndPoint);

      if (snapPoint == null) {
        print('끝점이 스냅 위치가 아님 - 허공에 놓음, 선 생성 취소');
        _cancelPointDrag();
        return;
      }

      // 끝점을 스냅된 위치로 보정
      pointDragEnd = snapPoint;

      // 일반 선 생성 (대각선도 가능)
      saveState();
      setState(() {
        lines.add(Line(
          start: pointDragStart!,
          end: pointDragEnd!,
          openingType: pendingOpeningType,
          isDiagonal: true, // 점 연결 모드로 생성된 선은 대각선으로 표시
        ));

        // 현재 점을 끝점으로 이동
        currentPoint = pointDragEnd!;
        pendingOpeningType = null;
      });

      // 성공 햅틱 피드백
      HapticFeedback.lightImpact();
      print('점 드래그 선 생성 완료 - 길이: $distance');

      // 점 연결 완료 후 diagonalMode 해제
      setState(() {
        diagonalMode = false;
      });
      print('점 연결 완료 - diagonalMode 해제');

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

  // 도면의 중심을 모델 좌표로 계산
  Offset _getDrawingCenterModel() {
    if (lines.isEmpty && circles.isEmpty) {
      return Offset.zero;
    }

    // 모든 선과 원의 경계 계산
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    // 선들의 경계
    for (final line in lines) {
      minX = math.min(minX, math.min(line.start.dx, line.end.dx));
      maxX = math.max(maxX, math.max(line.start.dx, line.end.dx));
      minY = math.min(minY, math.min(line.start.dy, line.end.dy));
      maxY = math.max(maxY, math.max(line.start.dy, line.end.dy));
    }

    // 원들의 경계
    for (final circle in circles) {
      minX = math.min(minX, circle.center.dx - circle.radius);
      maxX = math.max(maxX, circle.center.dx + circle.radius);
      minY = math.min(minY, circle.center.dy - circle.radius);
      maxY = math.max(maxY, circle.center.dy + circle.radius);
    }

    // 도면 중심 계산 (모델 좌표)
    return Offset((minX + maxX) / 2, (minY + maxY) / 2);
  }

  // 90도 단위로 스냅하는 함수
  double _snapTo90Degrees(double angle) {
    // 라디안을 도로 변환
    double degrees = angle * 180 / math.pi;

    // 가장 가까운 90도 배수로 스냅
    double snappedDegrees = (degrees / 90).round() * 90;

    // 360도로 정규화
    snappedDegrees = snappedDegrees % 360;
    if (snappedDegrees < 0) snappedDegrees += 360;

    // 다시 라디안으로 변환
    return snappedDegrees * math.pi / 180;
  }

  // 화면 회전을 고려한 방향 변환
  String _transformDirectionForRotation(String direction) {
    // 현재 회전 각도를 도 단위로 변환
    double rotationDegrees = (viewRotation * 180 / math.pi) % 360;
    if (rotationDegrees < 0) rotationDegrees += 360;

    // 90도 단위로 반올림
    int rotationSteps = ((rotationDegrees + 45) ~/ 90) % 4;

    // 방향 변환 매핑
    const directions = ['Up', 'Right', 'Down', 'Left'];
    int directionIndex = directions.indexOf(direction);
    if (directionIndex == -1) return direction;

    // 회전에 따라 방향 조정
    int newIndex = (directionIndex + rotationSteps) % 4;
    return directions[newIndex];
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
    // 모바일/태블릿에서는 터치 영역이 넓으므로 tolerance를 크게 설정
    final tolerance = (isMobile || isTablet) ? 50.0 : 30.0;
    double minDist = double.infinity;
    Offset? closestPoint;

    print(
        '\n=== 끝점 찾기: 터치위치=$screenPosition, 선=${lines.length}개, tolerance=$tolerance ===');

    // 끝점 중복 확인을 위한 Set
    final Set<String> processedPoints = {};

    // 기존 선의 끝점들 확인
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 시작점 확인
      final startKey =
          '${line.start.dx.toStringAsFixed(2)},${line.start.dy.toStringAsFixed(2)}';
      final startScreen = _modelToScreen(line.start);
      final dist1 = (screenPosition - startScreen).distance;
      if (!processedPoints.contains(startKey)) {
        processedPoints.add(startKey);
        if (dist1 < tolerance) {
          print('  선[$i] 시작점: 거리=$dist1 ${dist1 < minDist ? "✓ 선택됨" : ""}');
          if (dist1 < minDist) {
            minDist = dist1;
            closestPoint = line.start;
          }
        }
      }

      // 끝점 확인
      final endKey =
          '${line.end.dx.toStringAsFixed(2)},${line.end.dy.toStringAsFixed(2)}';
      final endScreen = _modelToScreen(line.end);
      final dist2 = (screenPosition - endScreen).distance;
      if (!processedPoints.contains(endKey)) {
        processedPoints.add(endKey);
        if (dist2 < tolerance) {
          print('  선[$i] 끝점: 거리=$dist2 ${dist2 < minDist ? "✓ 선택됨" : ""}');
          if (dist2 < minDist) {
            minDist = dist2;
            closestPoint = line.end;
          }
        }
      }
    }

    // diagonalMode일 때만 직교점도 확인
    if (diagonalMode && pointDragStart != null) {
      // 직교점은 잠시 비활성화 (디버깅을 위해)
      // 직교점 로직이 일반 끝점 선택을 방해할 수 있음
    }

    print('결과: ${closestPoint != null ? "점 찾음 (거리=$minDist)" : "점 없음"}\n');

    return closestPoint;
  }

  // 점에서 선으로의 직교점 찾기
  Offset? _findPerpendicularPoint(Offset point, Line line) {
    // 선의 방향 벡터
    final lineVec = line.end - line.start;
    final lineLength = lineVec.distance;

    if (lineLength == 0) return null;

    // 정규화된 방향 벡터
    final lineDir = lineVec / lineLength;

    // 점에서 선의 시작점까지의 벡터
    final pointVec = point - line.start;

    // 내적을 통해 투영 길이 계산
    final projLength = pointVec.dx * lineDir.dx + pointVec.dy * lineDir.dy;

    // 투영 길이가 선의 범위 내에 있는지 확인
    if (projLength < 0 || projLength > lineLength) return null;

    // 직교점 계산
    final perpPoint = line.start + lineDir * projLength;

    // 원래 점과 직교점 사이의 거리가 합리적인지 확인
    final dist = (point - perpPoint).distance;
    if (dist > 500) return null; // 너무 먼 직교점은 무시

    return perpPoint;
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

  // 거리측정선 클릭 감지
  int? _findMeasurementNear(Offset position) {
    const tolerance = 20.0; // 더 넓은 감지 범위

    print(
        '거리측정선 클릭 감지 시도 - 측정선 개수: ${distanceMeasurements.length}, 클릭 위치: $position');

    for (int i = 0; i < distanceMeasurements.length; i++) {
      final measurement = distanceMeasurements[i];
      final point1Screen = _modelToScreen(measurement.point1);
      final point2Screen = _modelToScreen(measurement.point2);

      final dist = _pointToLineDistance(position, point1Screen, point2Screen);
      print('측정선 $i: 거리 = $dist (허용범위: $tolerance)');

      if (dist <= tolerance) {
        print('측정선 $i 클릭 감지됨!');
        return i;
      }
    }

    print('클릭한 위치에 측정선 없음');
    return null;
  }

  // 두 선분 사이의 최단거리 계산
  DistanceMeasurement? _calculateLineToLineDistance(
      int lineIndex1, int lineIndex2) {
    if (lineIndex1 < 0 ||
        lineIndex1 >= lines.length ||
        lineIndex2 < 0 ||
        lineIndex2 >= lines.length) {
      return null;
    }

    final line1 = lines[lineIndex1];
    final line2 = lines[lineIndex2];

    // 두 선분이 평행한지 확인
    final vec1 = line1.end - line1.start;
    final vec2 = line2.end - line2.start;

    final len1 = vec1.distance;
    final len2 = vec2.distance;

    // 외적을 이용한 평행 판단 (정규화된 벡터로 계산)
    final crossProduct = (vec1.dx * vec2.dy - vec1.dy * vec2.dx).abs();
    final normalizedCross =
        len1 > 0 && len2 > 0 ? crossProduct / (len1 * len2) : 0.0;
    final isParallel = normalizedCross < 0.05; // 거의 평행 (약 3도 이내)

    print(
        '선분 $lineIndex1 - $lineIndex2: crossProduct=$crossProduct, normalized=$normalizedCross, isParallel=$isParallel');

    if (isParallel) {
      print('평행한 선분 감지');

      // 두 선분을 무한 직선으로 확장했을 때의 수직 거리
      final perpendicularDist =
          _pointToLineSegmentDistance(line1.start, line2.start, line2.end);
      print('수직 거리: $perpendicularDist');

      // 겹치는 구간 계산
      final overlap = _calculateOverlap(line1, line2);

      if (overlap != null) {
        print('겹치는 구간 있음: ${overlap['start']} ~ ${overlap['end']}');

        // 겹치는 구간의 중심점
        final overlapCenter = Offset(
          (overlap['start']!.dx + overlap['end']!.dx) / 2,
          (overlap['start']!.dy + overlap['end']!.dy) / 2,
        );

        // line1의 겹치는 구간 중심점
        final point1 = overlapCenter;

        // line2에서 수직으로 가장 가까운 점
        final point2 =
            _closestPointOnLineSegment(point1, line2.start, line2.end);

        final actualDistance = (point1 - point2).distance;
        print('실제 거리 (point1-point2): $actualDistance');

        return DistanceMeasurement(
          lineIndex1: lineIndex1,
          lineIndex2: lineIndex2,
          point1: point1,
          point2: point2,
          distance: actualDistance,
        );
      } else {
        print('겹치는 구간 없음 - 기존 로직 사용');
      }
    }

    // 평행하지 않거나 겹치지 않는 경우 기존 로직
    double minDistance = double.infinity;
    Offset? closestPoint1;
    Offset? closestPoint2;

    // 1. line1의 각 점에서 line2까지의 거리
    final dist1Start =
        _pointToLineSegmentDistance(line1.start, line2.start, line2.end);
    if (dist1Start < minDistance) {
      minDistance = dist1Start;
      closestPoint1 = line1.start;
      closestPoint2 =
          _closestPointOnLineSegment(line1.start, line2.start, line2.end);
    }

    final dist1End =
        _pointToLineSegmentDistance(line1.end, line2.start, line1.end);
    if (dist1End < minDistance) {
      minDistance = dist1End;
      closestPoint1 = line1.end;
      closestPoint2 =
          _closestPointOnLineSegment(line1.end, line2.start, line2.end);
    }

    // 2. line2의 각 점에서 line1까지의 거리
    final dist2Start =
        _pointToLineSegmentDistance(line2.start, line1.start, line1.end);
    if (dist2Start < minDistance) {
      minDistance = dist2Start;
      closestPoint1 =
          _closestPointOnLineSegment(line2.start, line1.start, line1.end);
      closestPoint2 = line2.start;
    }

    final dist2End =
        _pointToLineSegmentDistance(line2.end, line1.start, line1.end);
    if (dist2End < minDistance) {
      minDistance = dist2End;
      closestPoint1 =
          _closestPointOnLineSegment(line2.end, line1.start, line1.end);
      closestPoint2 = line2.end;
    }

    if (closestPoint1 == null || closestPoint2 == null) {
      return null;
    }

    return DistanceMeasurement(
      lineIndex1: lineIndex1,
      lineIndex2: lineIndex2,
      point1: closestPoint1,
      point2: closestPoint2,
      distance: minDistance,
    );
  }

  // 두 평행 선분의 겹치는 구간 계산
  Map<String, Offset>? _calculateOverlap(Line line1, Line line2) {
    // 선분의 방향 벡터
    final vec1 = line1.end - line1.start;
    final length1 = vec1.distance;

    if (length1 == 0) return null;

    // 정규화된 방향 벡터
    final dir = Offset(vec1.dx / length1, vec1.dy / length1);

    // line1의 시작점을 기준(0)으로 각 점의 위치를 투영
    final line1Start_t = 0.0;
    final line1End_t = length1;

    // line2의 점들을 line1의 방향으로 투영
    final toLine2Start = line2.start - line1.start;
    final line2Start_t = toLine2Start.dx * dir.dx + toLine2Start.dy * dir.dy;

    final toLine2End = line2.end - line1.start;
    final line2End_t = toLine2End.dx * dir.dx + toLine2End.dy * dir.dy;

    // line2의 투영 범위
    final line2Min_t = line2Start_t < line2End_t ? line2Start_t : line2End_t;
    final line2Max_t = line2Start_t > line2End_t ? line2Start_t : line2End_t;

    // 겹치는 구간 계산
    final overlapStart_t =
        line1Start_t > line2Min_t ? line1Start_t : line2Min_t;
    final overlapEnd_t = line1End_t < line2Max_t ? line1End_t : line2Max_t;

    // 겹치는 구간이 없으면 null
    if (overlapStart_t >= overlapEnd_t) {
      return null;
    }

    // 겹치는 구간의 시작점과 끝점을 실제 좌표로 변환
    final overlapStart = Offset(
      line1.start.dx + dir.dx * overlapStart_t,
      line1.start.dy + dir.dy * overlapStart_t,
    );

    final overlapEnd = Offset(
      line1.start.dx + dir.dx * overlapEnd_t,
      line1.start.dy + dir.dy * overlapEnd_t,
    );

    return {
      'start': overlapStart,
      'end': overlapEnd,
    };
  }

  // 점에서 선분까지의 최단거리
  double _pointToLineSegmentDistance(
      Offset point, Offset lineStart, Offset lineEnd) {
    final closestPoint = _closestPointOnLineSegment(point, lineStart, lineEnd);
    return (point - closestPoint).distance;
  }

  // 선분 위의 점 중 주어진 점에서 가장 가까운 점 찾기
  Offset _closestPointOnLineSegment(
      Offset point, Offset lineStart, Offset lineEnd) {
    final lineVec = lineEnd - lineStart;
    final pointVec = point - lineStart;

    final lineLengthSquared = lineVec.dx * lineVec.dx + lineVec.dy * lineVec.dy;

    if (lineLengthSquared == 0) {
      return lineStart; // 선분이 점인 경우
    }

    // 투영 비율 계산 (0~1 사이로 클램프)
    final t = ((pointVec.dx * lineVec.dx + pointVec.dy * lineVec.dy) /
            lineLengthSquared)
        .clamp(0.0, 1.0);

    return Offset(
      lineStart.dx + t * lineVec.dx,
      lineStart.dy + t * lineVec.dy,
    );
  }

  // 점과 선 사이의 거리 측정
  DistanceMeasurement? _calculatePointToLineDistance(
      Offset point, int lineIndex) {
    if (lineIndex < 0 || lineIndex >= lines.length) {
      return null;
    }

    final line = lines[lineIndex];
    final closestPoint =
        _closestPointOnLineSegment(point, line.start, line.end);
    final distance = (point - closestPoint).distance;

    return DistanceMeasurement(
      lineIndex1: -1, // 점이므로 -1
      lineIndex2: lineIndex,
      point1: point,
      point2: closestPoint,
      distance: distance,
    );
  }

  // 점과 점 사이의 거리 측정
  DistanceMeasurement? _calculatePointToPointDistance(
      Offset point1, Offset point2) {
    final distance = (point1 - point2).distance;

    return DistanceMeasurement(
      lineIndex1: -1, // 점이므로 -1
      lineIndex2: -1,
      point1: point1,
      point2: point2,
      distance: distance,
    );
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
    // 회전 변환 적용
    final cos = math.cos(viewRotation);
    final sin = math.sin(viewRotation);

    // 회전된 좌표
    final rotatedX = model.dx * cos - model.dy * sin;
    final rotatedY = model.dx * sin + model.dy * cos;

    return Offset(
      viewOffset.dx + rotatedX * viewScale,
      viewOffset.dy - rotatedY * viewScale,
    );
  }

  Offset _screenToModel(Offset screen) {
    // 화면 좌표를 중심 기준으로 변환
    final translatedX = (screen.dx - viewOffset.dx) / viewScale;
    final translatedY = -(screen.dy - viewOffset.dy) / viewScale;

    // 역회전 변환 적용
    final cos = math.cos(-viewRotation);
    final sin = math.sin(-viewRotation);

    return Offset(
      translatedX * cos - translatedY * sin,
      translatedX * sin + translatedY * cos,
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

    // 원이 선택된 상태에서 방향키가 설정된 경우 (원 이동 모드)
    if (selectedCircleIndex >= 0 &&
        selectedCircleIndex < circles.length &&
        arrowDirection != null) {
      final circle = circles[selectedCircleIndex];
      final centerScreen = _modelToScreen(circle.center);
      return Offset(
        centerScreen.dx + 30, // 원 중심 우측으로 이동
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

      // 현재 날짜로 파일명 생성 (날짜_HV LINE 형식)
      final now = DateTime.now();
      final fileName =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_HV LINE.dxf';

      // Blob 생성 및 다운로드 (DXF 파일용 MIME 타입 사용)
      final bytes = Uint8List.fromList(dxfContent.codeUnits);
      final blob = html.Blob([bytes], 'application/dxf');
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

    // 첫 번째 선의 시작점을 원점으로 설정
    final firstLine = lines.first;
    final originX = firstLine.start.dx;
    final originY = firstLine.start.dy;

    print('DXF 생성 - 첫 번째 선의 시작점을 원점으로 설정: ($originX, $originY)');

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
    buffer.writeln('4'); // cyan 색상 (색상 코드 4)
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

    // 좌표 변환: 첫 번째 선의 시작점을 원점으로 이동 (실제 크기 유지)
    const double scale = 1.0; // 1:1 스케일 (HV Line에서 그린 것과 동일한 크기)

    for (final line in lines) {
      // 첫 번째 선의 시작점을 원점으로 이동 후 스케일 적용
      final startX = (line.start.dx - originX) * scale;
      final startY = (line.start.dy - originY) * scale;
      final endX = (line.end.dx - originX) * scale;
      final endY = (line.end.dy - originY) * scale;

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

      // 창문인 경우 평행선 추가 제거 - 단일 선으로만 저장
    }

    // 원들 출력
    for (final circle in circles) {
      final centerX = (circle.center.dx - originX) * scale;
      final centerY = (circle.center.dy - originY) * scale;
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
    print(
        'fitViewToDrawing 시작 - 선: ${lines.length}개, 원: ${circles.length}개, 회전: ${(viewRotation * 180 / math.pi).toStringAsFixed(0)}°');

    if (lines.isEmpty && circles.isEmpty) {
      // 선과 원이 모두 없으면 기본 뷰로 설정
      print('선/원이 없음 - 기본 뷰 설정');
      setState(() {
        viewScale = 0.3;
        viewOffset = const Offset(500, 500);
      });
      print('기본 뷰 설정 완료 - 스케일: $viewScale, 오프셋: $viewOffset');
      return;
    }

    // 회전 변환 행렬
    final cos = math.cos(viewRotation);
    final sin = math.sin(viewRotation);

    // 회전된 좌표에서의 경계 계산
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    // 점을 회전시켜 경계 계산하는 함수
    void updateBoundsWithPoint(double x, double y) {
      final rotatedX = x * cos - y * sin;
      final rotatedY = x * sin + y * cos;
      minX = math.min(minX, rotatedX);
      maxX = math.max(maxX, rotatedX);
      minY = math.min(minY, rotatedY);
      maxY = math.max(maxY, rotatedY);
    }

    // 선들의 경계
    for (final line in lines) {
      updateBoundsWithPoint(line.start.dx, line.start.dy);
      updateBoundsWithPoint(line.end.dx, line.end.dy);
    }

    // 원들의 경계 (원의 바운딩 박스 4개 모서리)
    for (final circle in circles) {
      updateBoundsWithPoint(
          circle.center.dx - circle.radius, circle.center.dy - circle.radius);
      updateBoundsWithPoint(
          circle.center.dx + circle.radius, circle.center.dy - circle.radius);
      updateBoundsWithPoint(
          circle.center.dx - circle.radius, circle.center.dy + circle.radius);
      updateBoundsWithPoint(
          circle.center.dx + circle.radius, circle.center.dy + circle.radius);
    }

    // 회전된 경계 박스 크기 계산
    final drawingWidth = maxX - minX;
    final drawingHeight = maxY - minY;
    final drawingCenterX = (minX + maxX) / 2;
    final drawingCenterY = (minY + maxY) / 2;

    print('Rotated drawing bounds: ($minX, $minY) to ($maxX, $maxY)');
    print('Rotated drawing size: ${drawingWidth} x ${drawingHeight}');
    print('Rotated drawing center: ($drawingCenterX, $drawingCenterY)');

    // 화면 크기 가져오기
    final context = this.context;
    final screenSize = MediaQuery.of(context).size;

    // 스케일 계산용 캔버스 크기 (여백 고려)
    final canvasWidth = screenSize.width - 100;
    final canvasHeight = screenSize.height - 300;

    // 적절한 스케일 계산
    final maxDimension = math.max(drawingWidth, drawingHeight);
    final marginFactor = maxDimension > 10000 ? 1.1 : 1.4;

    double scaleX = canvasWidth / (drawingWidth * marginFactor);
    double scaleY = canvasHeight / (drawingHeight * marginFactor);
    double optimalScale = math.min(scaleX, scaleY);

    // 스케일 범위 제한
    optimalScale = optimalScale.clamp(0.02, 2.0);

    // 화면 중심 계산
    final screenCenterX = screenSize.width / 2;
    final screenCenterY = (screenSize.height - 350) / 2;

    // 회전된 중심점을 화면 중심에 맞추기 위한 오프셋 계산
    final newOffsetX = screenCenterX - (drawingCenterX * optimalScale);
    final newOffsetY = screenCenterY + (drawingCenterY * optimalScale);

    setState(() {
      viewScale = optimalScale;
      viewOffset = Offset(newOffsetX, newOffsetY);
    });

    print(
        'Rotated drawing size: ${drawingWidth.toStringAsFixed(1)} x ${drawingHeight.toStringAsFixed(1)}');
    print(
        'Max dimension: ${maxDimension.toStringAsFixed(1)}, margin factor: ${marginFactor.toStringAsFixed(1)}');
    print(
        'New scale: ${optimalScale.toStringAsFixed(4)} (${(optimalScale * 100).toStringAsFixed(1)}%)');
    print(
        'New offset: (${newOffsetX.toStringAsFixed(1)}, ${newOffsetY.toStringAsFixed(1)})');
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
              } else {
                // 숫자 입력 중이 아니면 선/원/거리측정 삭제
                print(
                    'Delete 키 처리 - selectedLineIndex: $selectedLineIndex, selectedCircleIndex: $selectedCircleIndex, selectedMeasurementIndex: $selectedMeasurementIndex');
                if (selectedMeasurementIndex != null) {
                  // 선택된 거리측정이 있으면 삭제
                  print(
                      'Delete 키: 선택된 거리측정 삭제 (인덱스: $selectedMeasurementIndex)');
                  setState(() {
                    distanceMeasurements.removeAt(selectedMeasurementIndex!);
                    selectedMeasurementIndex = null;
                  });
                } else if (selectedCircleIndex >= 0) {
                  // 선택된 원이 있으면 해당 원 삭제
                  print('Delete 키: 선택된 원 삭제 (인덱스: $selectedCircleIndex)');
                  deleteSelectedCircle();
                } else if (selectedLineIndex >= 0 &&
                    selectedLineIndex < lines.length) {
                  // 선택된 선이 있으면 해당 선 삭제
                  print('Delete 키: 선택된 선 삭제 (인덱스: $selectedLineIndex)');
                  deleteSelectedLine();
                } else {
                  // 선택된 것이 없으면 가장 최근에 추가된 것 삭제
                  int? lastLineTimestamp =
                      lines.isNotEmpty ? lines.last.timestamp : null;
                  int? lastCircleTimestamp =
                      circles.isNotEmpty ? circles.last.timestamp : null;
                  int? lastMeasurementTimestamp =
                      distanceMeasurements.isNotEmpty
                          ? distanceMeasurements.last.timestamp
                          : null;

                  int maxTimestamp = -1;
                  String? deleteType;

                  if (lastLineTimestamp != null &&
                      lastLineTimestamp > maxTimestamp) {
                    maxTimestamp = lastLineTimestamp;
                    deleteType = 'line';
                  }
                  if (lastCircleTimestamp != null &&
                      lastCircleTimestamp > maxTimestamp) {
                    maxTimestamp = lastCircleTimestamp;
                    deleteType = 'circle';
                  }
                  if (lastMeasurementTimestamp != null &&
                      lastMeasurementTimestamp > maxTimestamp) {
                    maxTimestamp = lastMeasurementTimestamp;
                    deleteType = 'measurement';
                  }

                  if (deleteType == 'line') {
                    print('Delete 키: 마지막 선 삭제');
                    deleteLastLine();
                  } else if (deleteType == 'circle') {
                    print('Delete 키: 마지막 원 삭제');
                    deleteLastCircle();
                  } else if (deleteType == 'measurement') {
                    print('Delete 키: 마지막 거리측정 삭제');
                    setState(() {
                      distanceMeasurements.removeLast();
                    });
                  }
                }
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
              } else if (distanceMeasureMode) {
                // 거리측정 모드 해제
                setState(() {
                  distanceMeasureMode = false;
                  firstSelectedLineForDistance = null;
                  firstSelectedPointForDistance = null;
                  selectedLineIndex = -1;
                  selectedEndpoint = null;
                });
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
                  hoveredLineIndex = null;
                });
              }
            } else if (event.logicalKey == LogicalKeyboardKey.equal &&
                (event.isControlPressed || event.isMetaPressed)) {
              setState(() {
                viewScale = (viewScale * 1.2).clamp(0.02, 2.0);
              });
            } else if (event.logicalKey == LogicalKeyboardKey.minus &&
                (event.isControlPressed || event.isMetaPressed)) {
              setState(() {
                viewScale = (viewScale * 0.8).clamp(0.02, 2.0);
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
                            'HV LINE',
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

                  const SizedBox(width: 8),

                  // 페이지 선택 드롭다운
                  _buildPageDropdown(),

                  const Spacer(),

                  const SizedBox(width: 8),

                  // 모드 버튼들
                  _buildCursorButtonWithWidget(
                    iconWidget: WindowIcon(
                      color: pendingOpeningType == 'window'
                          ? Colors.white
                          : const Color(0xFF569CD6),
                      size: 14,
                    ),
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
                  _buildCursorButtonWithWidget(
                    iconWidget: DiagonalDotsIcon(
                      color:
                          diagonalMode ? Colors.white : const Color(0xFFDCDCAA),
                      size: 14,
                    ),
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
                    color: const Color(0xFF66BB6A), // 녹색
                    isPrimary: circleMode,
                  ),

                  const SizedBox(width: 8),

                  // 메인 액션 버튼들

                  _buildCursorButton(
                    icon: Icons.straighten,
                    label: '거리측정',
                    onPressed: () {
                      setState(() {
                        distanceMeasureMode = !distanceMeasureMode;
                        firstSelectedLineForDistance = null;
                        firstSelectedPointForDistance = null;
                        if (!distanceMeasureMode) {
                          // 모드 해제 시 선택 초기화
                          selectedLineIndex = -1;
                          selectedEndpoint = null;
                        }
                      });
                    },
                    color: const Color(0xFFFF7043),
                    isPrimary: distanceMeasureMode,
                  ),

                  const SizedBox(width: 6),

                  _buildCursorButton(
                    icon: Icons.undo_rounded,
                    label: '되돌리기',
                    onPressed: undo,
                    color: const Color(0xFFCE9178), // Cursor 주황색
                  ),

                  const SizedBox(width: 6),

                  // 초기화 버튼
                  _buildCursorButton(
                    icon: Icons.refresh_rounded,
                    label: '초기화',
                    onPressed: reset,
                    color: const Color(0xFF9CDCFE), // Cursor 연한 파란색
                  ),

                  const SizedBox(width: 6),

                  // 음성 인식 버튼 (로딩 상태 포함)
                  _buildVoiceButton(),

                  const SizedBox(width: 8),

                  // DXF 저장 버튼
                  _buildCursorButton(
                    icon: Icons.save_alt_rounded,
                    label: 'DXF 저장',
                    onPressed: saveToDXF,
                    color: const Color(0xFF6A9955), // Cursor 초록색
                    isPrimary: true,
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
                          viewScale =
                              (viewScale * scaleFactor).clamp(0.02, 2.0);

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
                      // 모든 드래그/스케일 제스처를 scale로 통합 처리
                      onScaleStart: (details) {
                        print(
                            'Scale start - 터치 포인트 수: ${details.pointerCount}');

                        // 한 손가락 제스처인 경우
                        if (details.pointerCount == 1) {
                          // 그룹 선택 시 드래그 처리
                          if (selectedGroupLines.isNotEmpty) {
                            _handlePointDragStart(DragStartDetails(
                              localPosition: details.localFocalPoint,
                              globalPosition: details.focalPoint,
                            ));
                            return;
                          }
                          // 대각선 모드 드래그 처리
                          else if (diagonalMode && !circleMode) {
                            print(
                                '대각선 모드 - onScaleStart에서 _handlePointDragStart 호출');
                            print('details.focalPoint: ${details.focalPoint}');
                            print(
                                'details.localFocalPoint: ${details.localFocalPoint}');
                            _handlePointDragStart(DragStartDetails(
                              localPosition: details.localFocalPoint,
                              globalPosition: details.focalPoint,
                            ));
                            return;
                          }
                          // 원 모드 처리
                          else if (circleMode) {
                            _handleCirclePanStart(DragStartDetails(
                              localPosition: details.localFocalPoint,
                              globalPosition: details.focalPoint,
                            ));
                            return;
                          }
                        }

                        // 기본 스케일 처리
                        setState(() {
                          _isScaling = true;
                          _isPanning = false;
                          _touchCount = details.pointerCount;

                          // 아이패드 웹에서 한 손가락 제스처인 경우
                          if (details.pointerCount == 1 && isTablet) {
                            print('아이패드 웹 - 한 손가락 제스처 시작');
                            _isScaling = false;
                          }
                        });
                        panStartOffset = viewOffset;
                        zoomStartScale = viewScale;
                        _initialScale = viewScale;
                        _initialRotation = viewRotation;
                        dragStartPos = details.focalPoint;

                        // 두 손가락 터치 시에는 두 손가락의 중심점을 기준으로 확대/축소 및 회전
                        if (details.pointerCount >= 2) {
                          _rotationCenterScreen = details.localFocalPoint;
                          // 두 손가락 중심점의 모델 좌표 계산
                          _rotationCenterModel =
                              _screenToModel(_rotationCenterScreen!);
                        } else {
                          // 한 손가락인 경우 화면의 중심을 기준
                          final renderBox =
                              context.findRenderObject() as RenderBox;
                          final screenSize = renderBox.size;
                          _rotationCenterScreen = Offset(
                              screenSize.width / 2, screenSize.height / 2);
                          _rotationCenterModel =
                              _screenToModel(_rotationCenterScreen!);
                        }

                        print(
                            '아이패드 제스처 시작 - 초기 스케일: ${_initialScale.toStringAsFixed(2)}, 초기 회전: ${(_initialRotation * 180 / math.pi).toStringAsFixed(1)}°, 회전 중심(모델): $_rotationCenterModel, 회전 중심(화면): $_rotationCenterScreen, 터치 수: ${details.pointerCount}');
                      },
                      onScaleUpdate: (details) {
                        // 드래그 중인 경우 처리
                        if (isPointDragging || isGroupDragging || _isPanning) {
                          _handlePointDragUpdate(DragUpdateDetails(
                            localPosition: details.localFocalPoint,
                            globalPosition: details.focalPoint,
                            delta: details.focalPointDelta,
                          ));
                          return;
                        }
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
                            final newScale = (_initialScale * details.scale)
                                .clamp(0.02, 2.0);
                            final scaleChange = newScale / viewScale;

                            // 줌 중심점을 기준으로 스케일 조정
                            final focalPoint = details.focalPoint;
                            viewOffset = Offset(
                              focalPoint.dx -
                                  (focalPoint.dx - viewOffset.dx) * scaleChange,
                              focalPoint.dy -
                                  (focalPoint.dy - viewOffset.dy) * scaleChange,
                            );

                            viewScale = newScale;

                            // 회전 처리 - 10도 이상 회전했을 때만 적용
                            final rotationDegrees =
                                (details.rotation * 180 / math.pi).abs();
                            if (rotationDegrees >= 10) {
                              viewRotation =
                                  _initialRotation - details.rotation;

                              // 모델 좌표의 중심점이 화면의 같은 위치에 유지되도록 viewOffset 조정
                              if (_rotationCenterModel != null &&
                                  _rotationCenterScreen != null) {
                                // 회전 후 모델 중심점의 새로운 화면 좌표 계산
                                final cos = math.cos(viewRotation);
                                final sin = math.sin(viewRotation);
                                final rotatedX =
                                    _rotationCenterModel!.dx * cos -
                                        _rotationCenterModel!.dy * sin;
                                final rotatedY =
                                    _rotationCenterModel!.dx * sin +
                                        _rotationCenterModel!.dy * cos;

                                // viewOffset을 조정하여 중심점이 원래 화면 위치에 유지되도록
                                viewOffset = Offset(
                                  _rotationCenterScreen!.dx -
                                      rotatedX * viewScale,
                                  _rotationCenterScreen!.dy +
                                      rotatedY * viewScale,
                                );
                              }
                            }

                            print(
                                '아이패드 핀치 줌: ${viewScale.toStringAsFixed(2)}x, 스케일: ${details.scale.toStringAsFixed(2)}, 회전: ${(viewRotation * 180 / math.pi).toStringAsFixed(0)}°');
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
                            // 두 손가락이지만 스케일 변화가 없는 경우 - 회전 또는 두 손가락 팬
                            final deltaX =
                                details.focalPoint.dx - dragStartPos!.dx;
                            final deltaY =
                                details.focalPoint.dy - dragStartPos!.dy;

                            viewOffset = Offset(
                              panStartOffset!.dx + deltaX,
                              panStartOffset!.dy + deltaY,
                            );

                            // 회전 처리 - 10도 이상 회전했을 때만 적용
                            final rotationDegrees =
                                (details.rotation * 180 / math.pi).abs();
                            if (rotationDegrees >= 10) {
                              viewRotation =
                                  _initialRotation - details.rotation;

                              // 모델 좌표의 중심점이 화면의 같은 위치에 유지되도록 viewOffset 조정
                              if (_rotationCenterModel != null &&
                                  _rotationCenterScreen != null) {
                                // 회전 후 모델 중심점의 새로운 화면 좌표 계산
                                final cos = math.cos(viewRotation);
                                final sin = math.sin(viewRotation);
                                final rotatedX =
                                    _rotationCenterModel!.dx * cos -
                                        _rotationCenterModel!.dy * sin;
                                final rotatedY =
                                    _rotationCenterModel!.dx * sin +
                                        _rotationCenterModel!.dy * cos;

                                // viewOffset을 조정하여 중심점이 원래 화면 위치에 유지되도록
                                viewOffset = Offset(
                                  _rotationCenterScreen!.dx -
                                      rotatedX * viewScale,
                                  _rotationCenterScreen!.dy +
                                      rotatedY * viewScale,
                                );
                              }
                            }

                            print(
                                '아이패드 두 손가락 팬/회전: 위치(${viewOffset.dx.toStringAsFixed(1)}, ${viewOffset.dy.toStringAsFixed(1)}), 회전: ${(viewRotation * 180 / math.pi).toStringAsFixed(0)}°');
                          }
                        });
                      },
                      onScaleEnd: (details) {
                        // 드래그 종료 처리
                        if (isPointDragging || isGroupDragging || _isPanning) {
                          _handlePointDragEnd(DragEndDetails());
                          return;
                        }
                        print(
                            'Scale end - 최종 스케일: ${viewScale.toStringAsFixed(2)}, 터치 수: $_touchCount');

                        // 제스처 종료 시 회전 각도를 90도 단위로 스냅
                        setState(() {
                          viewRotation = _snapTo90Degrees(viewRotation);
                          print(
                              '회전 종료 - 90도로 스냅: ${(viewRotation * 180 / math.pi).toStringAsFixed(0)}°');
                        });

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
                          Future.delayed(const Duration(milliseconds: 150), () {
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

                          print(
                              '데스크톱에서 onTap 처리 - circleMode: $circleMode, 위치: $_lastTapPosition');
                          _handleTap(_lastTapPosition!);
                          _focusNode.requestFocus();
                        }
                      },
                      onTapDown: (details) {
                        print('onTapDown 호출됨 - 위치: ${details.localPosition}');

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

                          // 중복 터치 방지 (이전 터치와 현재 터치 비교)
                          final now = DateTime.now();
                          if (_lastTapTime != null &&
                              now.difference(_lastTapTime!).inMilliseconds <
                                  300) {
                            print('중복 터치 감지 (300ms 이내) - 무시');
                            return;
                          }

                          // 터치 위치와 시간 저장 (처리 직전에)
                          setState(() {
                            _lastTapPosition = details.localPosition;
                            _lastTapTime = now;
                          });

                          print('모바일/태블릿 원 모드 터치 처리 실행');
                          _handleTap(details.localPosition);
                          _focusNode.requestFocus();
                        } else {
                          // 일반 모드 및 데스크톱 원 모드에서는 터치 위치와 시간만 저장
                          final now = DateTime.now();
                          setState(() {
                            _lastTapPosition = details.localPosition;
                            _lastTapTime = now;
                          });

                          // 데스크톱 원 모드일 때 디버깅 로그 추가
                          if (!isMobile && !isTablet && circleMode) {
                            print(
                                '데스크톱 원 모드 - onTapDown에서 위치 저장: ${details.localPosition}');
                          }
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
                        } else if (!isMobile && !isTablet && circleMode) {
                          // 데스크톱 원 모드에서는 onTapUp에서 직접 처리
                          print('데스크톱 원 모드에서 onTapUp 직접 처리');
                          _handleTap(position);
                          _focusNode.requestFocus();
                        } else {
                          print('기타 상황 - onTapUp 무시');
                        }
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.basic,
                        onHover: (event) {
                          // 끝점 호버 효과 제거 - 선만 호버 표시
                          final newHoveredLineIndex =
                              _findLineNear(event.localPosition);

                          if (newHoveredLineIndex != hoveredLineIndex) {
                            setState(() {
                              mousePosition = event.localPosition;
                              hoveredLineIndex = newHoveredLineIndex;
                            });
                          }
                        },
                        onExit: (_) {
                          setState(() {
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
                            distanceMeasurements: distanceMeasurements,
                            firstSelectedLineForDistance:
                                firstSelectedLineForDistance,
                            selectedMeasurementIndex: selectedMeasurementIndex,
                            viewRotation: viewRotation,
                            selectedLineIndex: selectedLineIndex,
                            selectedCircleIndex: selectedCircleIndex,
                            arrowDirection: arrowDirection,
                            isDoubleDirectionPressed: isDoubleDirectionPressed,
                            isPointDragging: isPointDragging,
                            circleMode: circleMode,
                            pointDragStart: pointDragStart,
                            pointDragEnd: pointDragEnd,
                            circleCenter: circleCenter,
                            pendingOpeningType: pendingOpeningType,
                            hoveredLineIndex: hoveredLineIndex,
                            selectedEndpoint: selectedEndpoint,
                            isGroupDragging: isGroupDragging,
                            draggedGroupLines: draggedGroupLines,
                            snapTargetPoint: snapTargetPoint,
                            selectedGroupLines: selectedGroupLines,
                            diagonalMode: diagonalMode,
                            mousePosition: mousePosition,
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
                                : circleMode && circleCenter != null
                                    ? const Color(0xFFFF7043) // 원 모드 주황색
                                    : selectedCircleIndex >= 0 &&
                                            arrowDirection != null
                                        ? const Color(0xFF4CAF50) // 원 이동 모드 녹색
                                        : selectedLineIndex >= 0
                                            ? const Color(
                                                0xFF6A9955) // Cursor 초록색
                                            : const Color(
                                                0xFFCE9178), // Cursor 주황색
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
                            if (circleMode && circleCenter != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFFF7043).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '원 지름',
                                  style: TextStyle(
                                    color: const Color(0xFFFF7043),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            else if (selectedCircleIndex >= 0 &&
                                arrowDirection != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF4CAF50).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '원 이동',
                                  style: TextStyle(
                                    color: const Color(0xFF4CAF50),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            else if (selectedLineIndex >= 0 &&
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

  Widget _buildCursorButtonWithWidget({
    required Widget iconWidget,
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
              iconWidget,
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

    // 태블릿 모드에서는 40% 크게
    final double buttonSize = isTabletSize ? 67.2 : 48.0; // 48 * 1.4 = 67.2
    final double fontSize = isTabletSize ? 33.6 : 24.0; // 24 * 1.4 = 33.6

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
              margin: const EdgeInsets.only(left: 15, bottom: 80),
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
              margin: const EdgeInsets.only(right: 15, bottom: 80),
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
              margin: const EdgeInsets.only(right: 30, bottom: 120),
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

  // 드롭다운 오버레이 표시
  void _showDropdownOverlay() {
    _dropdownOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 전체 화면을 덮는 투명한 레이어 (드롭다운 외부 클릭 감지용)
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideDropdownOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // 드롭다운 메뉴
          CompositedTransformFollower(
            link: _dropdownLayerLink,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF252526),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF3C3C3C),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(10, (index) {
                    final page = index + 1;
                    final isSelected = page == currentPage;

                    return InkWell(
                      onTap: () {
                        print('페이지 선택: $page');
                        _changePage(page);
                        _hideDropdownOverlay();
                      },
                      borderRadius: page == 1
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(7),
                              topRight: Radius.circular(7))
                          : page == 10
                              ? const BorderRadius.only(
                                  bottomLeft: Radius.circular(7),
                                  bottomRight: Radius.circular(7))
                              : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF606060)
                              : Colors.transparent,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected)
                              const Icon(
                                Icons.check,
                                color: Color(0xFFC0C0C0),
                                size: 16,
                              ),
                            if (isSelected) const SizedBox(width: 6),
                            Text(
                              '$page',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.8),
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 20), // 최소 너비 확보
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_dropdownOverlay!);
  }

  // 드롭다운 오버레이 숨기기
  void _hideDropdownOverlay() {
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
    setState(() {
      isPageDropdownOpen = false;
    });
  }

  // 페이지 드롭다운 위젯
  Widget _buildPageDropdown() {
    return CompositedTransformTarget(
      link: _dropdownLayerLink,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              isPageDropdownOpen = !isPageDropdownOpen;
              if (isPageDropdownOpen) {
                _showDropdownOverlay();
              } else {
                _hideDropdownOverlay();
              }
            });
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 4.5 : 8, // 모바일에서 5px 늘림
              vertical: 4, // 26px 높이를 위해 4로 변경
            ),
            decoration: BoxDecoration(
              color: isPageDropdownOpen
                  ? const Color(0xFF707070)
                  : const Color(0xFF707070).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isPageDropdownOpen
                    ? const Color(0xFF707070)
                    : const Color(0xFF707070).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: isMobile ? 16 : 20, // 모바일에서 너비 줄임
                  child: Text(
                    '$currentPage',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isPageDropdownOpen
                          ? Colors.white
                          : const Color(0xFFC0C0C0),
                      fontSize: 12, // 12px로 변경
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 2 : 4), // 모바일에서 간격 줄임
                Icon(
                  isPageDropdownOpen
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  color: isPageDropdownOpen
                      ? Colors.white
                      : const Color(0xFFC0C0C0),
                  size: isMobile ? 14 : 16, // 모바일에서 아이콘 크기 줄임
                ),
              ],
            ),
          ),
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

    // 태블릿 모드에서는 40% 크게
    final double baseSize = isTabletSize ? 67.2 : 48.0; // 48 * 1.4 = 67.2
    final double wideSize = isTabletSize ? 142.8 : 102.0; // 102 * 1.4 = 142.8
    final double fontSize = isTabletSize ? 22.4 : 16.0; // 16 * 1.4 = 22.4

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
}

// LinesPainter 클래스는 별도로 정의
class LinesPainter extends CustomPainter {
  final List<Line> lines;
  final List<Circle> circles;
  final Offset currentPoint;
  final double viewScale;
  final Offset viewOffset;
  final double viewRotation;
  final int selectedLineIndex;
  final int selectedCircleIndex;
  final String? arrowDirection;
  final bool isDoubleDirectionPressed;
  final bool isPointDragging;
  final bool circleMode;
  final Offset? pointDragStart;
  final Offset? pointDragEnd;
  final Offset? circleCenter;
  final String? pendingOpeningType;
  final int? hoveredLineIndex;
  final Offset? selectedEndpoint;
  final bool isGroupDragging;
  final Set<int> draggedGroupLines;
  final Offset? snapTargetPoint;
  final Set<int> selectedGroupLines;
  final bool diagonalMode;
  final Offset? mousePosition;
  final List<DistanceMeasurement> distanceMeasurements;
  final int? firstSelectedLineForDistance;
  final int? selectedMeasurementIndex;

  LinesPainter({
    required this.lines,
    required this.circles,
    required this.currentPoint,
    required this.viewScale,
    required this.viewOffset,
    required this.viewRotation,
    required this.selectedLineIndex,
    required this.selectedCircleIndex,
    this.arrowDirection,
    required this.isDoubleDirectionPressed,
    required this.isPointDragging,
    required this.circleMode,
    this.pointDragStart,
    this.pointDragEnd,
    this.circleCenter,
    this.pendingOpeningType,
    this.hoveredLineIndex,
    this.selectedEndpoint,
    required this.isGroupDragging,
    required this.draggedGroupLines,
    this.snapTargetPoint,
    required this.selectedGroupLines,
    required this.diagonalMode,
    this.mousePosition,
    required this.distanceMeasurements,
    this.firstSelectedLineForDistance,
    this.selectedMeasurementIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
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

    // 1. 먼저 모든 선 그리기 (선이 있는 경우에만)
    for (int i = 0; i < lines.length; i++) {
      try {
        final line = lines[i];
        final start = _modelToScreen(line.start);
        final end = _modelToScreen(line.end);

        // 줌 레벨에 따른 동적 선 두께 계산 (더 보수적으로 조정)
        // 그룹에 속한 선이나 개별 선택된 선은 굵게 표시
        final isSelected =
            i == safeSelectedIndex || selectedGroupLines.contains(i);
        final baseStrokeWidth = isSelected ? 3.0 : 2.0;
        final adaptiveStrokeWidth = viewScale < 0.05
            ? baseStrokeWidth / viewScale * 0.01 // 매우 작은 줌에서 선 두께 약간 증가
            : baseStrokeWidth;

        // 선택된 그룹에 속한 선인지 확인
        final isInSelectedGroup = selectedGroupLines.contains(i);

        // 더블클릭한 선에 대해서만 디버깅
        if (selectedGroupLines.isNotEmpty &&
            safeSelectedIndex >= 0 &&
            i == safeSelectedIndex) {
          print(
              'Line $i: isInSelectedGroup=$isInSelectedGroup, safeSelectedIndex=$safeSelectedIndex, selectedGroupLines=$selectedGroupLines');
        }

        // 색상 결정 로직 수정: 그룹 선택이 우선
        Color lineColor;
        if (isInSelectedGroup) {
          lineColor = const Color(0xFF2196F3); // 선택된 그룹은 파란색
        } else if (i == safeSelectedIndex) {
          lineColor = const Color(0xFF4CAF50); // 개별 선택은 녹색
        } else {
          lineColor = Colors.white; // 기본은 흰색
        }

        final paint = Paint()
          ..strokeWidth = adaptiveStrokeWidth.clamp(1.0, 4.0) // 최소 1, 최대 4
          ..color = lineColor;

        if (line.openingType == 'window') {
          // 호버 효과가 있는 경우 - 창문에만 적용
          if (i == safeHoveredIndex && i != safeSelectedIndex) {
            final hoverStrokeWidth =
                viewScale < 0.05 ? 5.0 / viewScale * 0.01 : 5.0;
            final hoverPaint = Paint()
              ..strokeWidth = hoverStrokeWidth.clamp(2.0, 6.0)
              ..color = const Color(0xFF00ACC1).withOpacity(0.5)
              ..strokeCap = StrokeCap.round;
            _drawDashedLine(canvas, start, end, hoverPaint, 5, 5);
          }

          // 창문 - 점선 (이미 위에서 색상을 설정했으므로 기본 창문색만 처리)
          if (!isInSelectedGroup && i != safeSelectedIndex) {
            paint.color = const Color(0xFF00ACC1); // 기본 창문색만 설정
          }
          final windowStrokeWidth =
              viewScale < 0.05 ? 3.0 / viewScale * 0.01 : 3.0;
          paint.strokeWidth = windowStrokeWidth.clamp(1.0, 4.0);
          _drawDashedLine(canvas, start, end, paint, 5, 5);

          // 이중선
          final angle = math.atan2(
              line.end.dy - line.start.dy, line.end.dx - line.start.dx);
          final offset = 5 * viewScale;
          final nx = offset * math.sin(angle);
          final ny = -offset * math.cos(angle);

          final doubleStrokeWidth =
              viewScale < 0.05 ? 1.0 / viewScale * 0.01 : 1.0;
          final doublePaint = Paint()
            ..color = paint.color // 위에서 설정한 색상 그대로 사용
            ..strokeWidth = doubleStrokeWidth.clamp(0.5, 2.0);

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
            final shadowStrokeWidth =
                viewScale < 0.05 ? 4.0 / viewScale * 0.01 : 4.0;
            final shadowPaint = Paint()
              ..strokeWidth = shadowStrokeWidth.clamp(2.0, 6.0)
              ..color = Colors.white.withOpacity(0.2)
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
            canvas.drawLine(start, end, shadowPaint);

            // 밝은 선
            final hoverStrokeWidth =
                viewScale < 0.05 ? 2.5 / viewScale * 0.01 : 2.5;
            paint.strokeWidth = hoverStrokeWidth.clamp(1.0, 4.0);
            paint.color = Colors.white;
          }
          // 이 부분 삭제 - 이미 위에서 색상과 두께를 설정했으므로 중복되고 오히려 문제를 일으킴

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

        // 줌 레벨에 따른 동적 원 두께 계산 (더 보수적으로 조정)
        final baseCircleStrokeWidth = isSelected ? 3.0 : 2.0;
        final adaptiveCircleStrokeWidth = viewScale < 0.05
            ? baseCircleStrokeWidth / viewScale * 0.01
            : baseCircleStrokeWidth;

        final paint = Paint()
          ..color = circleColor
          ..strokeWidth =
              adaptiveCircleStrokeWidth.clamp(1.0, 4.0) // 선택된 원은 더 두껍게
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(centerScreen, radiusScreen, paint);

        // 중심점 표시 또는 화살표 표시
        if (isSelected && arrowDirection != null) {
          // 선택된 원에 방향키가 설정된 경우 화살표 표시
          _drawArrow(canvas, centerScreen, arrowDirection!);
        } else {
          // 일반 중심점 표시
          canvas.drawCircle(
            centerScreen,
            3,
            Paint()
              ..color = circleColor
              ..style = PaintingStyle.fill,
          );
        }
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

    // 현재 점 그리기 (드래그 중이거나 원 모드가 아니고, 원이 선택되지 않았을 때만)
    if (!isPointDragging && !circleMode && selectedCircleIndex < 0) {
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

    // 호버된 점 표시 제거 - 선택된 끝점만 표시

    // 점연결 모드일 때 모든 끝점에 작은 표시 (디버깅용)
    if (diagonalMode && !isPointDragging) {
      final dotColor = const Color(0xFFDCDCAA); // 점연결 버튼과 동일한 색상
      for (final line in lines) {
        // 시작점
        final startScreen = _modelToScreen(line.start);
        canvas.drawCircle(
          startScreen,
          4,
          Paint()
            ..color = dotColor
            ..style = PaintingStyle.fill,
        );

        // 끝점
        final endScreen = _modelToScreen(line.end);
        canvas.drawCircle(
          endScreen,
          4,
          Paint()
            ..color = dotColor
            ..style = PaintingStyle.fill,
        );
      }

      // 마우스/터치 위치 표시 (디버깅용)
      if (mousePosition != null) {
        // 십자선 표시
        final crossPaint = Paint()
          ..color = Colors.red.withOpacity(0.5)
          ..strokeWidth = 1;
        canvas.drawLine(
          Offset(mousePosition!.dx - 20, mousePosition!.dy),
          Offset(mousePosition!.dx + 20, mousePosition!.dy),
          crossPaint,
        );
        canvas.drawLine(
          Offset(mousePosition!.dx, mousePosition!.dy - 20),
          Offset(mousePosition!.dx, mousePosition!.dy + 20),
          crossPaint,
        );

        // 위치 텍스트
        final textPainter = TextPainter(
          text: TextSpan(
            text:
                '(${mousePosition!.dx.toInt()}, ${mousePosition!.dy.toInt()})',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 10,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, mousePosition! + const Offset(5, -15));
      }
    }

    // 선택된 끝점 표시 (빨간 점 또는 파란 점)
    if (selectedEndpoint != null) {
      final selectedScreen = _modelToScreen(selectedEndpoint!);

      // 방향키 두 번 눌렀을 때는 파란색, 아니면 빨간색
      final pointColor = isDoubleDirectionPressed
          ? const Color(0xFF2196F3) // 파란색
          : const Color(0xFFE53935); // 빨간색

      canvas.drawCircle(
        selectedScreen,
        5,
        Paint()
          ..color = pointColor
          ..style = PaintingStyle.fill,
      );
    }

    // 그룹 드래그 중일 때 시각적 피드백
    if (isGroupDragging) {
      // 드래그 중인 선들을 반투명하게 표시
      for (int i in draggedGroupLines) {
        if (i < lines.length) {
          final line = lines[i];
          final startScreen = _modelToScreen(line.start);
          final endScreen = _modelToScreen(line.end);

          canvas.drawLine(
            startScreen,
            endScreen,
            Paint()
              ..color = const Color(0xFF2196F3).withOpacity(0.5)
              ..strokeWidth = 3,
          );
        }
      }

      // 스냅 대상이 있으면 표시
      if (snapTargetPoint != null) {
        final snapScreen = _modelToScreen(snapTargetPoint!);

        // 스냅 대상 점을 강조
        canvas.drawCircle(
          snapScreen,
          12,
          Paint()
            ..color = const Color(0xFF4CAF50).withOpacity(0.3)
            ..style = PaintingStyle.fill,
        );

        canvas.drawCircle(
          snapScreen,
          8,
          Paint()
            ..color = const Color(0xFF4CAF50)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    // 거리측정 그리기
    _drawDistanceMeasurements(canvas);
  }

  void _drawArrow(Canvas canvas, Offset position, String direction) {
    // 미니멀 모던 디자인
    const double arrowLength = 16.0;
    const double arrowAngle = 0.5; // 화살표 각도 (라디안)

    // 방향키 두 번 누름 상태에 따라 색상 변경
    Color arrowColor;
    if (isDoubleDirectionPressed) {
      arrowColor = const Color(0xFF2196F3); // 파란색 계열 (Material Blue)
    } else if (pendingOpeningType == 'window') {
      arrowColor = const Color(0xFFFF7043);
    } else {
      arrowColor = const Color(0xFFE53935);
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

    // 텍스트 위치 계산 - 12픽셀 고정 거리
    final angle = math.atan2(dy, dx);
    final offset = 12.0;
    double nx, ny;

    // 회전이 없을 때는 기본 방식
    if (viewRotation.abs() < 0.01) {
      nx = -math.sin(angle) * offset;
      ny = math.cos(angle) * offset;
    } else {
      // 회전이 있을 때는 화면에서 보이는 선의 방향을 기준으로 계산
      // 화면 좌표계에서의 선의 방향
      final screenStartX =
          start.dx * math.cos(viewRotation) - start.dy * math.sin(viewRotation);
      final screenStartY =
          start.dx * math.sin(viewRotation) + start.dy * math.cos(viewRotation);
      final screenEndX =
          end.dx * math.cos(viewRotation) - end.dy * math.sin(viewRotation);
      final screenEndY =
          end.dx * math.sin(viewRotation) + end.dy * math.cos(viewRotation);

      // 화면에서의 선의 각도
      final screenAngle =
          math.atan2(screenEndY - screenStartY, screenEndX - screenStartX);

      // 화면 기준으로 수직 방향 오프셋 (12픽셀 고정)
      final screenNx = -math.sin(screenAngle) * offset;
      final screenNy = math.cos(screenAngle) * offset;

      // 모델 좌표계로 역변환
      final cos = math.cos(-viewRotation);
      final sin = math.sin(-viewRotation);
      nx = screenNx * cos - screenNy * sin;
      ny = screenNx * sin + screenNy * cos;
    }

    canvas.save();
    canvas.translate(midX + nx, midY + ny);

    // 텍스트 회전 - 화면 회전을 고려
    double textAngle = -angle - viewRotation;
    // 텍스트가 항상 읽기 쉬운 방향이 되도록 조정
    while (textAngle > math.pi / 2) {
      textAngle -= math.pi;
    }
    while (textAngle < -math.pi / 2) {
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

    // 화면 회전을 고려한 텍스트 회전
    canvas.rotate(-viewRotation);

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
    // 회전 변환 적용
    final cos = math.cos(viewRotation);
    final sin = math.sin(viewRotation);

    // 회전된 좌표
    final rotatedX = model.dx * cos - model.dy * sin;
    final rotatedY = model.dx * sin + model.dy * cos;

    return Offset(
      viewOffset.dx + rotatedX * viewScale,
      viewOffset.dy - rotatedY * viewScale,
    );
  }

  // 거리측정 그리기
  void _drawDistanceMeasurements(Canvas canvas) {
    for (int i = 0; i < distanceMeasurements.length; i++) {
      final measurement = distanceMeasurements[i];
      final point1Screen = _modelToScreen(measurement.point1);
      final point2Screen = _modelToScreen(measurement.point2);
      final isSelected = selectedMeasurementIndex == i;

      // 점선 그리기 - 선택 시 녹색
      final dashedLinePaint = Paint()
        ..color = isSelected ? const Color(0xFF4CAF50) : const Color(0xFFFF7043)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      _drawDashedLine(
          canvas, point1Screen, point2Screen, dashedLinePaint, 8, 4);

      // 양쪽 끝에 작은 원 그리기
      final endPointPaint = Paint()
        ..color = isSelected ? const Color(0xFF4CAF50) : const Color(0xFFFF7043)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(point1Screen, 4, endPointPaint);
      canvas.drawCircle(point2Screen, 4, endPointPaint);

      // 거리 텍스트 그리기
      final midPoint = Offset(
        (point1Screen.dx + point2Screen.dx) / 2,
        (point1Screen.dy + point2Screen.dy) / 2,
      );

      final distanceText = measurement.distance.toInt().toString();

      final textSpan = TextSpan(
        text: distanceText,
        style: TextStyle(
          color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFFFF7043),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          backgroundColor: const Color(0xFF1E1E1E),
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          midPoint.dx - textPainter.width / 2,
          midPoint.dy - textPainter.height / 2,
        ),
      );
    }

    // 첫 번째 선택된 선 하이라이트
    if (firstSelectedLineForDistance != null &&
        firstSelectedLineForDistance! >= 0 &&
        firstSelectedLineForDistance! < lines.length) {
      final selectedLine = lines[firstSelectedLineForDistance!];
      final startScreen = _modelToScreen(selectedLine.start);
      final endScreen = _modelToScreen(selectedLine.end);

      final highlightPaint = Paint()
        ..color = const Color(0xFFFF7043).withOpacity(0.5)
        ..strokeWidth = 8.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(startScreen, endScreen, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
