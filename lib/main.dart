import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const LineDrawerApp());
}

class LineDrawerApp extends StatelessWidget {
  const LineDrawerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HV LAB Drawer',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF212830),
      ),
      home: const LineDrawerScreen(),
    );
  }
}

class Line {
  Offset start;
  Offset end;
  String? openingType; // "window" only
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
      connectedPoints: connectedPoints != null ? Map.from(connectedPoints!) : null,
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
  List<Map<String, dynamic>> linesHistory = [];
  Offset currentPoint = const Offset(0, 0);
  double viewScale = 0.3;
  Offset viewOffset = const Offset(500, 500);
  int selectedLineIndex = -1;
  bool diagonalMode = false;
  Offset? diagonalStart;
  Map<String, dynamic>? diagonalStartInfo;
  String? pendingOpeningType;
  String? arrowDirection;
  
  // 팬/줌 관련 변수
  Offset? panStartOffset;
  double? zoomStartScale;
  Offset? dragStartPos;
  
  // 마우스 호버 관련 변수
  Offset? hoveredPoint;
  Offset? mousePosition;
  int? hoveredLineIndex;
  
  // 인라인 입력 관련 변수
  bool showInlineInput = false;
  String inlineDirection = "";
  TextEditingController inlineController = TextEditingController();
  FocusNode inlineFocus = FocusNode();
  bool isProcessingInput = false; // 중복 처리 방지용 플래그 추가
  
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 포커스 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    inlineController.dispose();
    inlineFocus.dispose();
    super.dispose();
  }

  void saveState() {
    linesHistory.add({
      'lines': lines.map((line) => line.copy()).toList(),
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
      lines = (lastState['lines'] as List<Line>).map((line) => line.copy()).toList();
      currentPoint = lastState['currentPoint'] as Offset;
    });
  }

  void reset() {
    if (lines.isEmpty && viewScale == 0.3 && viewOffset == const Offset(500, 500)) return;
    
    saveState();
    setState(() {
      lines.clear();
      currentPoint = const Offset(0, 0);
      selectedLineIndex = -1;
      viewScale = 0.3;
      viewOffset = const Offset(500, 500);
    });
  }

  void onDirectionKey(String direction) {
    setState(() {
      // 새로운 방향키를 눌렀을 때
      if (!showInlineInput) {
        // 처음 시작할 때는 빈 값으로 시작
        inlineController.clear();
      }
      // 방향이 바뀌어도 입력값은 유지 (else if 블록 제거)
      
      arrowDirection = direction;
      inlineDirection = direction;
      showInlineInput = true;
      isProcessingInput = false; // 플래그 초기화
      // pendingOpeningType은 유지됨
    });
    
    // 포커스 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      inlineFocus.requestFocus();
      // 커서를 끝으로 이동
      inlineController.selection = TextSelection.fromPosition(
        TextPosition(offset: inlineController.text.length),
      );
    });
  }

  void confirmInlineInput() {
    if (isProcessingInput) return; // 이미 처리 중이면 무시
    
    final distance = double.tryParse(inlineController.text);
    if (distance == null || distance <= 0) {
      print('Invalid distance: ${inlineController.text}'); // 디버그
      return;
    }
    
    isProcessingInput = true; // 처리 시작
    
    // 선이 선택된 상태에서 숫자를 입력한 경우
    if (selectedLineIndex >= 0 && arrowDirection == null) {
      print('Modifying line $selectedLineIndex to length $distance'); // 디버그
      saveState();
      modifyLineLength(selectedLineIndex, distance);
      setState(() {
        showInlineInput = false;
        isProcessingInput = false; // 플래그 초기화
        // selectedLineIndex는 유지 (선택 상태 유지)
      });
      
      // 포커스를 메인 포커스 노드로 되돌리기
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
      return;
    }
    
    // 일반적인 방향키 입력
    Offset newPoint;
    switch (inlineDirection) {
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
        isProcessingInput = false;
        return;
    }

    saveState();
    
    setState(() {
      lines.add(Line(
        start: currentPoint,
        end: newPoint,
        openingType: pendingOpeningType,
      ));
      currentPoint = newPoint;
      pendingOpeningType = null;
      showInlineInput = false;
      arrowDirection = null;
      isProcessingInput = false; // 플래그 초기화
    });
    
    // 포커스를 메인 포커스 노드로 되돌리기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void cancelInlineInput() {
    setState(() {
      showInlineInput = false;
      arrowDirection = null;
      isProcessingInput = false;
      inlineController.clear(); // 입력값 초기화
    });
    
    // 포커스를 메인 포커스 노드로 되돌리기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void modifyLineLength(int index, double newLength) {
    if (index < 0 || index >= lines.length) return;
    
    final line = lines[index];
    final dx = line.end.dx - line.start.dx;
    final dy = line.end.dy - line.start.dy;
    final oldLen = math.sqrt(dx * dx + dy * dy);
    
    if (oldLen == 0) return;
    
    // 단위 벡터 계산
    final unitX = dx / oldLen;
    final unitY = dy / oldLen;
    
    // 새로운 끝점 계산
    final newEnd = Offset(
      line.start.dx + newLength * unitX,
      line.start.dy + newLength * unitY,
    );
    
    setState(() {
      if (line.isDiagonal) {
        // 대각선은 단순히 끝점만 변경
        line.end = newEnd;
      } else {
        // 일반 선: 연결된 선들도 함께 이동
        final oldEnd = line.end;
        final shift = Offset(
          newEnd.dx - line.end.dx,
          newEnd.dy - line.end.dy,
        );
        
        // 현재 선의 끝점 업데이트
        line.end = newEnd;
        
        // 연결된 모든 선과 점들을 이동시키기 위한 재귀 함수
        void moveConnectedElements(Offset oldPoint, Offset newPoint, Set<int> visitedLines) {
          final pointShift = Offset(
            newPoint.dx - oldPoint.dx,
            newPoint.dy - oldPoint.dy,
          );
          
          for (int i = 0; i < lines.length; i++) {
            if (visitedLines.contains(i)) continue;
            
            final currentLine = lines[i];
            
            if (currentLine.isDiagonal) {
              // 대각선 처리
              if (currentLine.connectedPoints != null) {
                final startInfo = currentLine.connectedPoints!['start'] as List<int>;
                final endInfo = currentLine.connectedPoints!['end'] as List<int>;
                
                // 대각선의 시작점이 이동하는 점과 같은 경우
                if ((currentLine.start.dx - oldPoint.dx).abs() < 0.01 &&
                    (currentLine.start.dy - oldPoint.dy).abs() < 0.01) {
                  currentLine.start = newPoint;
                }
                
                // 대각선의 끝점이 이동하는 점과 같은 경우
                if ((currentLine.end.dx - oldPoint.dx).abs() < 0.01 &&
                    (currentLine.end.dy - oldPoint.dy).abs() < 0.01) {
                  currentLine.end = newPoint;
                }
              }
            } else {
              // 일반 선: 시작점이 이동하는 점과 같으면
              if ((currentLine.start.dx - oldPoint.dx).abs() < 0.01 &&
                  (currentLine.start.dy - oldPoint.dy).abs() < 0.01) {
                visitedLines.add(i);
                
                // 전체 선을 이동
                currentLine.start = newPoint;
                final newEndPoint = Offset(
                  currentLine.end.dx + pointShift.dx,
                  currentLine.end.dy + pointShift.dy,
                );
                final oldEndPoint = currentLine.end;
                currentLine.end = newEndPoint;
                
                // 재귀적으로 연결된 선들 이동
                moveConnectedElements(oldEndPoint, newEndPoint, visitedLines);
              }
            }
          }
          
          // 현재 점이 이동하는 점이었다면 업데이트
          if ((currentPoint.dx - oldPoint.dx).abs() < 0.01 &&
              (currentPoint.dy - oldPoint.dy).abs() < 0.01) {
            currentPoint = newPoint;
          }
        }
        
        // 선택된 선의 끝점에서 시작하는 모든 연결된 요소들 이동
        final visitedLines = <int>{index};
        moveConnectedElements(oldEnd, newEnd, visitedLines);
      }
    });
  }

  void deleteSelectedLine() {
    if (selectedLineIndex < 0 || selectedLineIndex >= lines.length) return;
    
    saveState();
    
    setState(() {
      final selectedLine = lines[selectedLineIndex];
      final isDiagonal = selectedLine.isDiagonal;
      
      if (!isDiagonal && selectedLineIndex > 0) {
        currentPoint = selectedLine.start;
      }
      
      lines.removeAt(selectedLineIndex);
      
      // 대각선 연결 정보 업데이트
      for (final line in lines) {
        if (line.isDiagonal && line.connectedPoints != null) {
          final startInfo = line.connectedPoints!['start'] as List<int>;
          final endInfo = line.connectedPoints!['end'] as List<int>;
          
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
      
      selectedLineIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true, // autofocus 추가
        includeSemantics: false, // 추가
        onKey: (RawKeyEvent event) {
          if (event is RawKeyDownEvent) {
            // 인라인 입력 중일 때
            if (showInlineInput) {
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                cancelInlineInput();
                return;
              } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                confirmInlineInput();
                return;
              } else if (event.logicalKey == LogicalKeyboardKey.keyW) {
                final currentText = inlineController.text; // 현재 텍스트 저장
                setState(() {
                  // 이미 창문 모드면 취소, 아니면 창문 모드로
                  pendingOpeningType = pendingOpeningType == 'window' ? null : 'window';
                });
                // 텍스트 복원
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
                // 선택된 선의 길이 수정 중이 아닐 때만 방향 변경
                if (selectedLineIndex < 0 || arrowDirection != null) {
                  // 다른 방향키를 누르면 방향 변경
                  String newDirection = '';
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) newDirection = 'Up';
                  else if (event.logicalKey == LogicalKeyboardKey.arrowDown) newDirection = 'Down';
                  else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) newDirection = 'Left';
                  else if (event.logicalKey == LogicalKeyboardKey.arrowRight) newDirection = 'Right';
                  
                  setState(() {
                    inlineDirection = newDirection;
                    arrowDirection = newDirection;
                    // 방향이 바뀌어도 입력값 유지 (텍스트 초기화 부분 제거)
                  });
                  
                  // 포커스 유지
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    inlineFocus.requestFocus();
                    // 커서를 텍스트 끝으로 이동
                    inlineController.selection = TextSelection.fromPosition(
                      TextPosition(offset: inlineController.text.length),
                    );
                  });
                }
                return;
              }
              // 다른 키는 TextField가 처리하도록 함
              return;
            }
            
            // 일반 키 처리
            if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyZ) {
              undo();
            } else if (event.logicalKey == LogicalKeyboardKey.delete ||
                       event.logicalKey == LogicalKeyboardKey.backspace) {
              if (selectedLineIndex >= 0) {
                deleteSelectedLine();
              } else {
                undo();
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (pendingOpeningType != null) {
                // W/D가 이미 눌렸으면 바로 인라인 입력 시작
                onDirectionKey('Up');
              } else {
                onDirectionKey('Up');
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              if (pendingOpeningType != null) {
                onDirectionKey('Down');
              } else {
                onDirectionKey('Down');
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              if (pendingOpeningType != null) {
                onDirectionKey('Left');
              } else {
                onDirectionKey('Left');
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              if (pendingOpeningType != null) {
                onDirectionKey('Right');
              } else {
                onDirectionKey('Right');
              }
            } else if (event.logicalKey == LogicalKeyboardKey.keyW) {
              setState(() {
                // 이미 창문 모드면 취소, 아니면 창문 모드로
                pendingOpeningType = pendingOpeningType == 'window' ? null : 'window';
              });
            } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
              setState(() {
                diagonalMode = !diagonalMode;
                diagonalStart = null;
                diagonalStartInfo = null;
                hoveredPoint = null; // 호버 상태 초기화
                hoveredLineIndex = null; // 선 호버 상태 초기화
                print('대각선 모드: $diagonalMode'); // 디버그
              });
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              if (showInlineInput) {
                // 입력창이 열려있으면 먼저 닫기
                cancelInlineInput();
              } else {
                // 입력창이 없을 때는 모든 모드 취소
                setState(() {
                  pendingOpeningType = null;
                  selectedLineIndex = -1;
                  diagonalMode = false;
                  diagonalStart = null;
                  diagonalStartInfo = null;
                  hoveredPoint = null;
                  hoveredLineIndex = null;
                });
              }
            } else if (event.logicalKey == LogicalKeyboardKey.equal && 
                       (event.isControlPressed || event.isMetaPressed)) {
              // Ctrl/Cmd + = : 확대
              setState(() {
                viewScale = (viewScale * 1.2).clamp(0.1, 5.0);
              });
            } else if (event.logicalKey == LogicalKeyboardKey.minus && 
                       (event.isControlPressed || event.isMetaPressed)) {
              // Ctrl/Cmd + - : 축소
              setState(() {
                viewScale = (viewScale * 0.8).clamp(0.1, 5.0);
              });
            } else if (event.logicalKey == LogicalKeyboardKey.digit0 && 
                       (event.isControlPressed || event.isMetaPressed)) {
              // Ctrl/Cmd + 0 : 뷰 리셋
              setState(() {
                viewScale = 0.3;
                viewOffset = const Offset(500, 500);
              });
            } else if (event.logicalKey == LogicalKeyboardKey.tab) {
              if (lines.isEmpty) return;
              
              if (showInlineInput) {
                // 입력창이 열려있으면 닫기
                cancelInlineInput();
              }
              
              // 다음 선 선택
              setState(() {
                selectedLineIndex = (selectedLineIndex + 1) % lines.length;
              });
            } else if (event.character != null && 
                      int.tryParse(event.character!) != null &&
                      selectedLineIndex >= 0 &&
                      !showInlineInput) { // showInlineInput이 false일 때만
              // 선이 선택된 상태에서 숫자 입력 시
              print('Number pressed: ${event.character}, selectedLineIndex: $selectedLineIndex'); // 디버그
              // 입력창이 없으면 인라인 입력창 표시
              print('Showing inline input for line modification'); // 디버그
              setState(() {
                showInlineInput = true;
                inlineController.text = event.character!;
                // 선택된 선의 방향 자동 설정
                final line = lines[selectedLineIndex];
                final dx = line.end.dx - line.start.dx;
                final dy = line.end.dy - line.start.dy;
                
                if (dx.abs() > dy.abs()) {
                  inlineDirection = dx > 0 ? 'Right' : 'Left';
                } else {
                  inlineDirection = dy > 0 ? 'Up' : 'Down';
                }
                arrowDirection = null; // 화살표는 표시하지 않음
              });
              
              // 포커스 설정 및 커서를 끝으로 이동
              WidgetsBinding.instance.addPostFrameCallback((_) {
                inlineFocus.requestFocus();
                // 커서를 텍스트 끝으로 이동
                inlineController.selection = TextSelection.fromPosition(
                  TextPosition(offset: inlineController.text.length),
                );
              });
            }
          }
        },
        child: Column(
          children: [
            // 상단 버튼들
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: reset,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('초기화'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF424242), // Grey 800
                    ),
                  ),
                  // 줌 레벨 표시
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${(viewScale * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        viewScale = 0.3;
                        viewOffset = const Offset(500, 500);
                      });
                    },
                    icon: const Icon(Icons.center_focus_strong, size: 20),
                    label: const Text('뷰 리셋'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF616161), // Grey 700
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: undo,
                    icon: const Icon(Icons.undo, size: 20),
                    label: const Text('되돌리기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F), // Red 700
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: saveToDXF,
                    icon: const Icon(Icons.save, size: 20),
                    label: const Text('저장'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF388E3C), // Green 700
                    ),
                  ),
                ],
              ),
            ),
            
            // 상태 표시
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _getStatusText(),
                style: const TextStyle(color: Color(0xFFE53935)), // Material Red 600
              ),
            ),
            
            // 캔버스
            Expanded(
              child: Stack(
                children: [
                  Listener(
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        // 마우스 휠로 확대/축소
                        setState(() {
                          final delta = pointerSignal.scrollDelta.dy;
                          final scaleFactor = delta > 0 ? 0.9 : 1.1;
                          
                          // 마우스 위치를 중심으로 확대/축소
                          final pointerPos = pointerSignal.localPosition;
                          final beforeScale = viewScale;
                          viewScale = (viewScale * scaleFactor).clamp(0.1, 5.0);
                          
                          // 마우스 위치가 고정되도록 오프셋 조정
                          final scaleChange = viewScale / beforeScale;
                          viewOffset = Offset(
                            pointerPos.dx - (pointerPos.dx - viewOffset.dx) * scaleChange,
                            pointerPos.dy - (pointerPos.dy - viewOffset.dy) * scaleChange,
                          );
                        });
                      }
                    },
                    child: GestureDetector(
                      onScaleStart: (details) {
                        // 터치 또는 마우스 드래그 시작
                        panStartOffset = viewOffset;
                        zoomStartScale = viewScale;
                        dragStartPos = details.focalPoint;
                      },
                      onScaleUpdate: (details) {
                        setState(() {
                          if (details.scale != 1.0) {
                            // 핀치 줌 (터치스크린)
                            viewScale = (zoomStartScale! * details.scale).clamp(0.1, 5.0);
                            
                            // 핀치 중심점 기준으로 오프셋 조정
                            final scaleChange = viewScale / zoomStartScale!;
                            viewOffset = Offset(
                              details.focalPoint.dx - (details.focalPoint.dx - panStartOffset!.dx) * scaleChange,
                              details.focalPoint.dy - (details.focalPoint.dy - panStartOffset!.dy) * scaleChange,
                            );
                          } else {
                            // 팬 (드래그)
                            viewOffset = Offset(
                              panStartOffset!.dx + (details.focalPoint.dx - dragStartPos!.dx),
                              panStartOffset!.dy + (details.focalPoint.dy - dragStartPos!.dy),
                            );
                          }
                        });
                      },
                      onTapUp: (details) {
                        _handleTap(details.localPosition);
                        // 캔버스 클릭 시 포커스 복원
                        _focusNode.requestFocus();
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.basic, // 기본 화살표 커서
                        onHover: (event) {
                          // 항상 꼭지점 근처 확인 (대각선 모드와 무관)
                          final hovered = _findEndpointNear(event.localPosition);
                          final newHoveredPoint = hovered?['point'] as Offset?;
                          
                          // 선 호버 확인
                          final newHoveredLineIndex = _findLineNear(event.localPosition);
                          
                          // 상태가 변경된 경우에만 setState 호출
                          if (newHoveredPoint != hoveredPoint || newHoveredLineIndex != hoveredLineIndex) {
                            setState(() {
                              mousePosition = event.localPosition;
                              hoveredPoint = newHoveredPoint;
                              hoveredLineIndex = newHoveredLineIndex;
                            });
                          }
                        },
                        onExit: (_) {
                          // 마우스가 나가면 호버 상태 초기화
                          setState(() {
                            hoveredPoint = null;
                            mousePosition = null;
                            hoveredLineIndex = null;
                          });
                        },
                        child: CustomPaint(
                          painter: LinesPainter(
                            lines: lines,
                            currentPoint: currentPoint,
                            viewScale: viewScale,
                            viewOffset: viewOffset,
                            selectedLineIndex: selectedLineIndex,
                            arrowDirection: arrowDirection,
                            diagonalMode: diagonalMode,
                            diagonalStart: diagonalStart,
                            pendingOpeningType: pendingOpeningType,
                            hoveredPoint: hoveredPoint,
                            hoveredLineIndex: hoveredLineIndex,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                  // 인라인 입력
                  if (showInlineInput)
                    Positioned(
                      left: _getInlineInputPosition().dx,
                      top: _getInlineInputPosition().dy,
                      child: Container(
                        width: 60, // 60픽셀로 변경
                        height: pendingOpeningType != null ? 40 : 30, // 창문 모드 40픽셀, 일반 30픽셀
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: pendingOpeningType == 'window' 
                              ? const Color(0xFFFF7043) // Deep Orange 400 (창문용 붉은 계열)
                              : selectedLineIndex >= 0
                                ? const Color(0xFF388E3C) // Green 700 (선택됨)
                                : const Color(0xFFE53935), // Red 600 (기본)
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (pendingOpeningType != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '창문',
                                  style: TextStyle(
                                    color: const Color(0xFFFF7043), // Deep Orange 400
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            if (selectedLineIndex >= 0 && arrowDirection == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '길이 수정',
                                  style: TextStyle(
                                    color: const Color(0xFF388E3C),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Center(
                                child: TextField(
                                  controller: inlineController,
                                  focusNode: inlineFocus,
                                  autofocus: true, // autofocus 추가
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    isDense: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), // 숫자와 소수점만 허용
                                  ],
                                  onSubmitted: (_) => confirmInlineInput(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // 방향키 버튼
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  IconButton(
                    onPressed: () => onDirectionKey('Up'),
                    icon: Icon(
                      Icons.arrow_upward, 
                      size: 32,
                      color: pendingOpeningType == 'window' 
                        ? const Color(0xFF0097A7)
                        : pendingOpeningType == 'door'
                          ? const Color(0xFFF57C00)
                          : null,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => onDirectionKey('Left'),
                        icon: Icon(
                          Icons.arrow_back, 
                          size: 32,
                          color: pendingOpeningType == 'window' 
                            ? const Color(0xFF0097A7)
                            : pendingOpeningType == 'door'
                              ? const Color(0xFFF57C00)
                              : null,
                        ),
                      ),
                      IconButton(
                        onPressed: () => onDirectionKey('Down'),
                        icon: Icon(
                          Icons.arrow_downward, 
                          size: 32,
                          color: pendingOpeningType == 'window' 
                            ? Colors.blue 
                            : pendingOpeningType == 'door'
                              ? Colors.orange
                              : null,
                        ),
                      ),
                      IconButton(
                        onPressed: () => onDirectionKey('Right'),
                        icon: Icon(
                          Icons.arrow_forward, 
                          size: 32,
                          color: pendingOpeningType == 'window' 
                            ? Colors.blue 
                            : pendingOpeningType == 'door'
                              ? Colors.orange
                              : null,
                        ),
                      ),
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

  String _getStatusText() {
    if (diagonalMode) {
      return diagonalStart == null 
        ? '대각선 모드: 첫 번째 점을 선택하세요'
        : '대각선 모드: 두 번째 점을 선택하세요';
    }
    
    if (selectedLineIndex >= 0) {
      return '선 ${selectedLineIndex + 1}/${lines.length} 선택됨 (숫자 입력으로 길이 수정)';
    }
    
    if (pendingOpeningType == 'window') {
      return '창문 모드: 방향키를 눌러주세요';
    }
    
    return '방향키로 선 그리기 | W:창문 | D:대각선 | Tab:선 선택 | Ctrl+Z:되돌리기 | 마우스휠:확대/축소';
  }

  void _handleTap(Offset position) {
    // 입력창이 열려있으면 닫기
    if (showInlineInput) {
      cancelInlineInput();
      // return 제거 - 계속 진행하여 선택 처리
    }
    
    if (diagonalMode) {
      _handleDiagonalClick(position);
      return;
    }
    
    // 끝점 찾기 - 호버된 점이 있으면 그것을 우선 사용
    final endpointInfo = hoveredPoint != null 
      ? {'point': hoveredPoint} 
      : _findEndpointNear(position);
      
    if (endpointInfo != null) {
      setState(() {
        currentPoint = endpointInfo['point'] as Offset;
      });
      return;
    }
    
    // 선 찾기
    final lineIndex = _findLineNear(position);
    if (lineIndex != null) {
      setState(() {
        selectedLineIndex = lineIndex;
      });
    } else {
      setState(() {
        selectedLineIndex = -1;
      });
    }
  }

  void _handleDiagonalClick(Offset position) {
    print('대각선 클릭: $position'); // 디버그
    
    // 호버된 점이 있으면 그것을 사용, 없으면 가장 가까운 끝점 찾기
    Offset? closestPoint = hoveredPoint;
    List<int>? closestInfo;
    
    if (closestPoint == null) {
      // 가장 가까운 끝점 찾기
      double minDist = double.infinity;
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        
        // 시작점 확인
        final startScreen = _modelToScreen(line.start);
        final dist1 = (position - startScreen).distance;
        print('시작점 거리: $dist1'); // 디버그
        if (dist1 < minDist && dist1 < 50) {
          minDist = dist1;
          closestPoint = line.start;
          closestInfo = [i, 0]; // 0 = start
        }
        
        // 끝점 확인
        final endScreen = _modelToScreen(line.end);
        final dist2 = (position - endScreen).distance;
        print('끝점 거리: $dist2'); // 디버그
        if (dist2 < minDist && dist2 < 50) {
          minDist = dist2;
          closestPoint = line.end;
          closestInfo = [i, 1]; // 1 = end
        }
      }
    } else {
      // 호버된 점의 정보 찾기
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.start == closestPoint) {
          closestInfo = [i, 0];
          break;
        } else if (line.end == closestPoint) {
          closestInfo = [i, 1];
          break;
        }
      }
    }
    
    if (closestPoint == null) {
      print('끝점을 찾을 수 없음'); // 디버그
      return;
    }
    
    print('가장 가까운 점 찾음: $closestPoint'); // 디버그
    
    setState(() {
      if (diagonalStart == null) {
        // 첫 번째 점 선택
        diagonalStart = closestPoint;
        diagonalStartInfo = {
          'start': closestInfo,
          'end': null,
        };
        print('첫 번째 점 선택됨'); // 디버그
      } else {
        // 두 번째 점 선택 - 대각선 생성
        print('두 번째 점 선택됨 - 대각선 생성'); // 디버그
        saveState();
        
        lines.add(Line(
          start: diagonalStart!,
          end: closestPoint!,
          isDiagonal: true,
          connectedPoints: {
            'start': diagonalStartInfo!['start'],
            'end': closestInfo,
          },
        ));
        
        // 대각선 길이 계산
        final dist = (closestPoint! - diagonalStart!).distance;
        print('대각선 길이: $dist'); // 디버그
        
        // 모드 종료
        diagonalMode = false;
        diagonalStart = null;
        diagonalStartInfo = null;
      }
    });
  }

  Map<String, dynamic>? _findEndpointNear(Offset position) {
    const tolerance = 20.0; // 호버 감지를 위해 증가
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
    const tolerance = 12.0; // 호버를 위해 증가
    
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

  double _pointToLineDistance(Offset p, Offset a, Offset b) {
    final lineLen = (b - a).distance;
    if (lineLen == 0) return (p - a).distance;
    
    final t = ((p - a).dx * (b - a).dx + (p - a).dy * (b - a).dy) / (lineLen * lineLen);
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

  Offset _getInlineInputPosition() {
    // 선이 선택된 상태에서 길이 수정
    if (selectedLineIndex >= 0 && selectedLineIndex < lines.length && arrowDirection == null) {
      final line = lines[selectedLineIndex];
      final startScreen = _modelToScreen(line.start);
      final endScreen = _modelToScreen(line.end);
      final midX = (startScreen.dx + endScreen.dx) / 2;
      final midY = (startScreen.dy + endScreen.dy) / 2;
      return Offset(midX - 30, midY - 60); // 중앙 위에 표시 (너비 60의 절반인 30)
    }
    
    // 일반 방향키 입력
    final currentScreen = _modelToScreen(currentPoint);
    return Offset(
      currentScreen.dx + 10,
      currentScreen.dy - (pendingOpeningType != null ? 50 : 40), // 높이에 맞춰 조정
    );
  }

  void showModifyLengthDialog() async {
    if (showInlineInput) return; // 인라인 입력창이 열려있으면 무시
    
    final controller = TextEditingController();
    final newLength = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF212830),
        title: const Text(
          '길이 수정',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: '새 길이 (mm)',
            labelStyle: const TextStyle(color: Colors.white70),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE53935), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.of(context).pop(value);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
    
    if (newLength != null && selectedLineIndex >= 0) {
      saveState();
      modifyLineLength(selectedLineIndex, newLength);
    }
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
      // DXF 내용 생성
      final dxfContent = generateDXF();
      
      // 파일 저장 대화상자 열기
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'DXF 파일 저장',
        fileName: 'drawing_${DateTime.now().millisecondsSinceEpoch}.dxf',
        type: FileType.custom,
        allowedExtensions: ['dxf'],
      );

      if (outputFile != null) {
        // 파일 저장
        final file = File(outputFile);
        await file.writeAsString(dxfContent);
        
        // 성공 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('파일이 저장되었습니다: ${file.path}'),
            backgroundColor: const Color(0xFF388E3C),
          ),
        );
      }
    } catch (e) {
      print('저장 에러: $e'); // 디버그용
      
      // UnimplementedError나 다른 에러 발생 시 클립보드에 복사
      try {
        await Clipboard.setData(ClipboardData(text: generateDXF()));
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('파일 저장이 지원되지 않아 DXF 내용이 클립보드에 복사되었습니다.\n텍스트 편집기에 붙여넣어 .dxf 파일로 저장하세요.'),
            backgroundColor: Color(0xFF0097A7),
            duration: Duration(seconds: 5),
          ),
        );
      } catch (e2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e2'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    }
  }

  String generateDXF() {
    final buffer = StringBuffer();
    
    // DXF 헤더
    buffer.writeln('0');
    buffer.writeln('SECTION');
    buffer.writeln('2');
    buffer.writeln('HEADER');
    buffer.writeln('9');
    buffer.writeln('\$ACADVER');
    buffer.writeln('1');
    buffer.writeln('AC1015'); // AutoCAD 2000 format
    buffer.writeln('0');
    buffer.writeln('ENDSEC');
    
    // ENTITIES 섹션
    buffer.writeln('0');
    buffer.writeln('SECTION');
    buffer.writeln('2');
    buffer.writeln('ENTITIES');
    
    // 각 선을 DXF 엔티티로 변환
    for (final line in lines) {
      if (line.openingType == 'window') {
        // 창문 - 점선으로 표현
        _addLine(buffer, line, 'WINDOW');
        // 이중선 추가
        final angle = math.atan2(line.end.dy - line.start.dy, line.end.dx - line.start.dx);
        final offset = 5.0;
        final nx = offset * math.sin(angle);
        final ny = -offset * math.cos(angle);
        
        final parallelLine1 = Line(
          start: Offset(line.start.dx + nx, line.start.dy + ny),
          end: Offset(line.end.dx + nx, line.end.dy + ny),
        );
        _addLine(buffer, parallelLine1, 'WINDOW');
        
        final parallelLine2 = Line(
          start: Offset(line.start.dx - nx, line.start.dy - ny),
          end: Offset(line.end.dx - nx, line.end.dy - ny),
        );
        _addLine(buffer, parallelLine2, 'WINDOW');
      } else {
        // 일반 선 및 대각선 모두 WALL로
        _addLine(buffer, line, 'WALL');
      }
    }
    
    buffer.writeln('0');
    buffer.writeln('ENDSEC');
    buffer.writeln('0');
    buffer.writeln('EOF');
    
    return buffer.toString();
  }

  void _addLine(StringBuffer buffer, Line line, String layer) {
    buffer.writeln('0');
    buffer.writeln('LINE');
    buffer.writeln('8'); // Layer
    buffer.writeln(layer);
    buffer.writeln('10'); // Start X
    buffer.writeln(line.start.dx.toStringAsFixed(2));
    buffer.writeln('20'); // Start Y
    buffer.writeln(line.start.dy.toStringAsFixed(2));
    buffer.writeln('30'); // Start Z
    buffer.writeln('0.0');
    buffer.writeln('11'); // End X
    buffer.writeln(line.end.dx.toStringAsFixed(2));
    buffer.writeln('21'); // End Y
    buffer.writeln(line.end.dy.toStringAsFixed(2));
    buffer.writeln('31'); // End Z
    buffer.writeln('0.0');
  }
}

class DistanceDialog extends StatefulWidget {
  final String direction;
  final String defaultValue;
  final String? initialOpeningType;
  final Function(String) onDirectionChanged;

  const DistanceDialog({
    Key? key,
    required this.direction,
    required this.defaultValue,
    this.initialOpeningType,
    required this.onDirectionChanged,
  }) : super(key: key);

  @override
  State<DistanceDialog> createState() => _DistanceDialogState();
}

class _DistanceDialogState extends State<DistanceDialog> {
  late TextEditingController controller;
  String? openingType;
  late String currentDirection;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.defaultValue);
    openingType = widget.initialOpeningType;
    currentDirection = widget.direction;
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.keyW) {
            setState(() {
              openingType = 'window';
            });
          } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
            setState(() {
              openingType = 'door';
            });
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                     event.logicalKey == LogicalKeyboardKey.arrowDown ||
                     event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                     event.logicalKey == LogicalKeyboardKey.arrowRight) {
            String newDirection = '';
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) newDirection = 'Up';
            else if (event.logicalKey == LogicalKeyboardKey.arrowDown) newDirection = 'Down';
            else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) newDirection = 'Left';
            else if (event.logicalKey == LogicalKeyboardKey.arrowRight) newDirection = 'Right';
            
            widget.onDirectionChanged(newDirection);
          }
        }
      },
      child: AlertDialog(
        title: Text(
          '$currentDirection${openingType != null ? ' - ${openingType == 'window' ? '창문' : '문'}' : ''}',
          style: TextStyle(
            color: openingType == 'window' 
              ? Colors.blue 
              : openingType == 'door' 
                ? Colors.orange 
                : null,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              onSubmitted: (_) => _confirm(),
              decoration: const InputDecoration(
                labelText: '거리 (mm)',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'W:창문 D:문',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: _confirm,
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _confirm() {
    final value = double.tryParse(controller.text);
    if (value != null) {
      Navigator.of(context).pop(value);
    }
  }
}

class LinesPainter extends CustomPainter {
  final List<Line> lines;
  final Offset currentPoint;
  final double viewScale;
  final Offset viewOffset;
  final int selectedLineIndex;
  final String? arrowDirection;
  final bool diagonalMode;
  final Offset? diagonalStart;
  final String? pendingOpeningType;
  final Offset? hoveredPoint;
  final int? hoveredLineIndex;

  LinesPainter({
    required this.lines,
    required this.currentPoint,
    required this.viewScale,
    required this.viewOffset,
    required this.selectedLineIndex,
    this.arrowDirection,
    required this.diagonalMode,
    this.diagonalStart,
    this.pendingOpeningType,
    this.hoveredPoint,
    this.hoveredLineIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 먼저 모든 선 그리기
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final start = _modelToScreen(line.start);
      final end = _modelToScreen(line.end);
      
      final paint = Paint()
        ..strokeWidth = i == selectedLineIndex ? 3 : 2
        ..color = i == selectedLineIndex 
          ? const Color(0xFF4CAF50) // Material Green 500
          : Colors.white;
      
      if (line.openingType == 'window') {
        // 호버 효과가 있는 경우 - 창문에만 적용
        if (i == hoveredLineIndex && i != selectedLineIndex) { // 선택되지 않은 경우에만 호버 효과
          final hoverPaint = Paint()
            ..strokeWidth = 5
            ..color = const Color(0xFF00ACC1).withOpacity(0.5)
            ..strokeCap = StrokeCap.round;
          _drawDashedLine(canvas, start, end, hoverPaint, 5, 5);
        }
        
        // 창문 - 점선
        paint.color = i == selectedLineIndex 
          ? const Color(0xFF4CAF50) // 선택된 경우 녹색
          : const Color(0xFF00ACC1); // Cyan 600
        paint.strokeWidth = i == selectedLineIndex ? 3 : 3;
        _drawDashedLine(canvas, start, end, paint, 5, 5);
        
        // 이중선
        final angle = math.atan2(line.end.dy - line.start.dy, line.end.dx - line.start.dx);
        final offset = 5 * viewScale;
        final nx = offset * math.sin(angle);
        final ny = -offset * math.cos(angle);
        
        final doublePaint = Paint()
          ..color = i == selectedLineIndex 
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
        if (i == hoveredLineIndex && i != selectedLineIndex) {
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
        } else if (i == selectedLineIndex) {
          // 선택된 경우 녹색 유지
          paint.strokeWidth = 3;
          paint.color = const Color(0xFF4CAF50);
        }
        
        canvas.drawLine(start, end, paint);
      }
    }
    
    // 2. 모든 치수 표시 (선 위에 그려짐)
    for (final line in lines) {
      _drawDimension(canvas, line);
    }
    
    // 현재 점 그리기
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
          ..color = const Color(0xFFE53935) // Material Red 600
          ..style = PaintingStyle.fill,
      );
    }
    
    // 끝점들 표시 부분 제거 (회색 점들 제거)
    
    // 대각선 모드에서 선택된 점
    if (diagonalMode && diagonalStart != null) {
      final startScreen = _modelToScreen(diagonalStart!);
      
      // 펄스 효과를 위한 외부 원
      canvas.drawCircle(
        startScreen,
        10,
        Paint()
          ..color = Colors.green.withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );
      
      // 메인 원
      canvas.drawCircle(
        startScreen,
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      
      // 테두리
      canvas.drawCircle(
        startScreen,
        6,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    
    // 호버된 점 표시 (대각선 모드와 무관)
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
    Color arrowColor = const Color(0xFFE53935); // Material Red 600 (점과 동일)
    if (pendingOpeningType == 'window') {
      arrowColor = const Color(0xFFFF7043); // Deep Orange 400 (창문용 붉은 계열)
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
          endPoint.dy + arrowLength * math.cos(arrowAngle) * 0.6,
        );
        rightWing = Offset(
          endPoint.dx + arrowLength * math.sin(arrowAngle),
          endPoint.dy + arrowLength * math.cos(arrowAngle) * 0.6,
        );
        break;
        
      case 'Down':
        endPoint = Offset(position.dx, position.dy + arrowLength);
        leftWing = Offset(
          endPoint.dx - arrowLength * math.sin(arrowAngle),
          endPoint.dy - arrowLength * math.cos(arrowAngle) * 0.6,
        );
        rightWing = Offset(
          endPoint.dx + arrowLength * math.sin(arrowAngle),
          endPoint.dy - arrowLength * math.cos(arrowAngle) * 0.6,
        );
        break;
        
      case 'Left':
        endPoint = Offset(position.dx - arrowLength, position.dy);
        leftWing = Offset(
          endPoint.dx + arrowLength * math.cos(arrowAngle) * 0.6,
          endPoint.dy - arrowLength * math.sin(arrowAngle),
        );
        rightWing = Offset(
          endPoint.dx + arrowLength * math.cos(arrowAngle) * 0.6,
          endPoint.dy + arrowLength * math.sin(arrowAngle),
        );
        break;
        
      case 'Right':
        endPoint = Offset(position.dx + arrowLength, position.dy);
        leftWing = Offset(
          endPoint.dx - arrowLength * math.cos(arrowAngle) * 0.6,
          endPoint.dy - arrowLength * math.sin(arrowAngle),
        );
        rightWing = Offset(
          endPoint.dx - arrowLength * math.cos(arrowAngle) * 0.6,
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
          color: Color(0xFFFFB300), // Amber 600
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

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint, double dashWidth, double dashSpace) {
    final distance = (end - start).distance;
    final dx = (end.dx - start.dx) / distance;
    final dy = (end.dy - start.dy) / distance;
    
    double currentDistance = 0;
    while (currentDistance < distance) {
      final dashEnd = currentDistance + dashWidth;
      if (dashEnd > distance) {
        canvas.drawLine(
          Offset(start.dx + dx * currentDistance, start.dy + dy * currentDistance),
          end,
          paint,
        );
      } else {
        canvas.drawLine(
          Offset(start.dx + dx * currentDistance, start.dy + dy * currentDistance),
          Offset(start.dx + dx * dashEnd, start.dy + dy * dashEnd),
          paint,
        );
      }
      currentDistance += dashWidth + dashSpace;
    }
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