import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ai_chat_bot/providers/firebase_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:ai_chat_bot/providers/gemini.dart';
import 'package:ai_chat_bot/model/message.dart';

class TalkScreen extends ConsumerStatefulWidget {
  const TalkScreen({super.key});

  @override
  ConsumerState<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends ConsumerState<TalkScreen>
    with SingleTickerProviderStateMixin {
  bool isPause = false;
  late AnimationController _rotationController;
  late Timer _pulseTimer;
  double _pulseValue = 0.0;
  bool _isListening = false; // Used for UI state (connected to room)
  bool _isConnecting = false;

  Room? _room;
  EventsListener<RoomEvent>? _listener;

  // Temporary storage for credentials
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSttTts();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _pulseTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isListening) {
        setState(() {
          // Pulse faster and larger if AI is talking
          double speed = _isTalkingAI ? 25.0 : 300.0;
          double base =
              (sin(DateTime.now().millisecondsSinceEpoch / speed) + 1) / 2;
          _pulseValue = _isTalkingAI ? (0.5 + base * 0.5) : base;
        });
      }
    });

    // Initialize values from .env
    final envUrl = dotenv.env['LIVEKIT_URL'];
    final envToken = dotenv.env['TOKEN'];

    if (envUrl != null && envUrl.isNotEmpty) {
      _urlController.text = envUrl;
    }
    if (envToken != null && envToken.isNotEmpty) {
      _tokenController.text = envToken;
    }

    // Initialize default values for testing (can be removed or loaded from env)
    // _urlController.text = "";
    // _tokenController.text = "";
  }

  @override
  void dispose() {
    _disconnect();
    _rotationController.dispose();
    _pulseTimer.cancel();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _disconnect() async {
    if (_room != null) {
      await _room!.disconnect();
      _room = null;
    }
    if (_listener != null) {
      _listener!.dispose();
      _listener = null;
    }
    _stopStt();
    _flutterTts.stop();
    setState(() {
      _isTalkingAI = false;
    });
  }

  Future<void> _connectToRoom() async {
    if (_urlController.text.isEmpty || _tokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter LiveKit URL and Token')),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      // check permissions
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission required');
      }

      // Ensure STT is available now that we have permission
      if (!_sttAvailable) {
        debugPrint("STT not available, attempting to re-initialize...");
        await _initSttTts();
      }

      // Hardware speakerphone switching logic varies, removed for now
      // await LiveKitClient.enableSpeakerphone(true);

      _room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _listener = _room!.createListener();

      _listener!.on<RoomConnectedEvent>((event) {
        debugPrint('Room connected: ${event.room.name}');
        setState(() {
          _isListening = true;
          _isConnecting = false;
        });
        _logToFirebase("Voice Chat Started", true);
        _startStt();
      });

      _listener!.on<RoomDisconnectedEvent>((event) {
        debugPrint('Room disconnected');
        setState(() {
          _isListening = false;
          _isConnecting = false;
        });
        _logToFirebase("Voice Chat Ended", false);
      });

      _listener!.on<DataReceivedEvent>((event) {
        // If we receive data messages (e.g. transcriptions), we can log them
        String decoded = String.fromCharCodes(event.data);
        _logToFirebase("Data received: $decoded", false);
      });

      await _room!.connect(_urlController.text, _tokenController.text);

      // Publish local microphone
      // Commented out to prevent conflict with SpeechToText (local AI)
      // await _room!.localParticipant!.setMicrophoneEnabled(true);
    } catch (e) {
      debugPrint('Failed to connect: $e');
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Connection failed: $e')));
      }
    }
  }

  void _logToFirebase(String text, bool isUser) {
    if (!mounted) return;
    final firebaseService = ref.read(firebaseChatServiceProvider);

    // We create a "System" type message effectively, but using our Message model
    // You might want to distinguish these in the UI later
    final message = Message(
      message: text,
      isUser: isUser,
      createdAt: DateTime.now(),
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    firebaseService.saveMessage(message);
    ref.invalidate(allChatsProvider);
  }

  // --- Gemini & Voice Logic ---

  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _sttAvailable = false;
  bool _isTalkingAI = false;

  Future<void> _initSttTts() async {
    try {
      _sttAvailable = await _speechToText.initialize(
        onStatus: (status) => debugPrint('STT Status: $status'),
        onError: (e) => debugPrint('STT Error: $e'),
      );
      debugPrint("STT Initialized: $_sttAvailable");

      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        if (mounted) setState(() => _isTalkingAI = true);
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _isTalkingAI = false);
          // Resume listening after AI finishes speaking
          if (_isListening) _startStt();
        }
      });

      _flutterTts.setErrorHandler((msg) {
        if (mounted) setState(() => _isTalkingAI = false);
      });
    } catch (e) {
      debugPrint("Error initializing Speech/TTS: $e");
    }
  }

  void _startStt() async {
    if (!_sttAvailable) {
      debugPrint("STT not available, trying to initialize...");
      await _initSttTts();
    }

    if (_sttAvailable && !_speechToText.isListening && !_isTalkingAI) {
      debugPrint("Starting STT listen...");
      _speechToText
          .listen(
            onResult: _onSpeechResult,
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 3),
            partialResults: false,
            cancelOnError: true,
            listenMode: ListenMode.dictation,
          )
          .then((_) => debugPrint("STT listen call completed"));
    } else {
      debugPrint(
        "Skipped STT start. Available: $_sttAvailable, Listening: ${_speechToText.isListening}, TalkingAI: $_isTalkingAI",
      );
    }
  }

  void _stopStt() {
    _speechToText.stop();
  }

  void _onSpeechResult(dynamic result) async {
    // result is SpeechRecognitionResult
    if (result.finalResult) {
      final text = result.recognizedWords;
      if (text.isNotEmpty) {
        debugPrint("User said: $text");
        _logToFirebase(text, true);
        await _processGeminiResponse(text);
      }

      // If we processed a final result, we wait for TTS to finish before listening again
      // The TTS completion handler will trigger _startStt
    }
  }

  Future<void> _processGeminiResponse(String text) async {
    try {
      final gemini = ref.read(geminiServiceProvider);
      // Send to Gemini
      final response = await gemini.sendMessage(text);
      _logToFirebase(response, false);

      // Speak response
      await _flutterTts.speak(response);
    } catch (e) {
      debugPrint("Gemini Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI Error: $e')));
      }
      // If error, resume listening anyway
      if (_isListening) _startStt();
    }
  }

  void _onMicPressed() {
    if (_isListening) {
      // Disconnect
      _disconnect();
      setState(() {
        _isListening = false;
      });
    } else {
      // Check for credentials from env or text controllers
      if (_urlController.text.isNotEmpty && _tokenController.text.isNotEmpty) {
        _connectToRoom();
      } else {
        // Show dialog to enter credentials first if not set
        _showConnectionDialog();
      }
    }
  }

  void _showConnectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect to LiveKit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'LiveKit URL',
                hintText: 'wss://...',
              ),
            ),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(labelText: 'Token'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _connectToRoom();
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Talk with AI',
          style: TextStyle(fontSize: 36, color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 14, 14, 14),
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(color: Color.fromARGB(255, 14, 14, 14)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color.fromARGB(255, 2, 34, 91),
              ),
              child: Text(
                _isListening
                    ? 'Connected. Listening...'
                    : 'Tap the mic to connect',
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            SizedBox(
              height: 300,
              width: 300,
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WireSpherePainter(
                      rotationY: _rotationController.value * 2 * pi,
                      rotationX: sin(_rotationController.value * 2 * pi) * 0.3,
                      pulse: _pulseValue,
                      isListening: _isListening,
                    ),
                    size: const Size(300, 300),
                  );
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        isPause = !isPause;
                        // Mute/Unmute local track if connected
                        if (_room != null && _room!.localParticipant != null) {
                          _room!.localParticipant!.setMicrophoneEnabled(
                            !isPause,
                          );
                        }
                      });
                    },
                    child: CircleAvatar(
                      maxRadius: 30,
                      backgroundColor: Colors.grey.shade900,
                      child: Icon(
                        (isPause) ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              const Color.fromARGB(255, 255, 234, 0),
                              const Color(0xFFFF0000),
                            ],
                          ),
                        ),
                        child: IconButton(
                          onPressed: _isConnecting ? null : _onMicPressed,
                          icon: _isConnecting
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Icon(
                                  _isListening
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded,
                                  size: 36,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      _disconnect();
                      Navigator.pop(context);
                    },
                    child: CircleAvatar(
                      maxRadius: 30,
                      backgroundColor: Colors.grey.shade900,
                      child: const Icon(Icons.cancel, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WireSpherePainter extends CustomPainter {
  final double rotationY;
  final double rotationX;
  final double pulse;
  final bool isListening;

  WireSpherePainter({
    required this.rotationY,
    required this.rotationX,
    required this.pulse,
    required this.isListening,
  });

  List<Offset> projectPoint(
    double x,
    double y,
    double z,
    double rotY,
    double rotX,
    Offset center,
    double scale,
  ) {
    // Apply rotations
    double rotatedX = x * cos(rotY) - z * sin(rotY);
    double rotatedZ = x * sin(rotY) + z * cos(rotY);
    double rotatedY = y * cos(rotX) - rotatedZ * sin(rotX);
    rotatedZ = y * sin(rotX) + rotatedZ * cos(rotX);

    // Project to 2D
    double screenX = center.dx + rotatedX * scale;
    double screenY = center.dy + rotatedY * scale;

    return [Offset(screenX, screenY), Offset(rotatedZ, 0)]; // Z for depth
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.8;
    const int segments = 640;
    const int rings = 480;

    // Gradient colors
    final gradientColor1 = const Color.fromARGB(255, 255, 234, 0); // Yellow
    final gradientColor2 = const Color(0xFFFF0000); // Red

    final glowPaint = Paint()
      ..color = isListening
          ? (const Color(0xFF0088FF)).withValues(alpha: 0.3)
          : const Color(0xFFFFAA00).withValues(alpha: 0.2)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Generate sphere vertices with 10x higher density
    List<List<Offset>> spherePoints = [];
    List<List<double>> depthMap = [];

    for (int ring = 0; ring <= rings; ring++) {
      List<Offset> ringPoints = [];
      List<double> ringDepths = [];
      final phi = (ring / rings) * pi;

      for (int seg = 0; seg < segments; seg++) {
        final theta = (seg / segments) * 2 * pi + rotationY;

        // Keep sphere shape regular, no deformation
        final x = radius * sin(phi) * cos(theta);
        final y = radius * cos(phi);
        final z = radius * sin(phi) * sin(theta);

        final projected = projectPoint(
          x,
          y,
          z,
          rotationY,
          rotationX,
          center,
          1.0,
        );
        ringPoints.add(projected[0]);
        ringDepths.add(projected[1].dx);
      }

      spherePoints.add(ringPoints);
      depthMap.add(ringDepths);
    }

    // Draw edge highlight glow
    canvas.drawCircle(center, radius * 0.98, glowPaint);

    // Draw all dots with gradient or listening color
    for (int ring = 0; ring < spherePoints.length; ring += 10) {
      // Sample every 10th ring for performance
      for (int seg = 0; seg < spherePoints[ring].length; seg += 10) {
        // Sample every 10th segment
        final point = spherePoints[ring][seg];
        final depth = depthMap[ring][seg];

        // Only draw dots on front hemisphere
        if (depth > -radius * 0.3) {
          // Vary dot size and opacity based on depth
          final depthFactor = (depth + radius) / (2 * radius);
          final opacity = 0.2 + depthFactor * 0.8;
          final dotSize = 0.8 + depthFactor * 1.2;

          if (isListening) {
            // Use blue color when listening
            final dotPaint = Paint()
              ..color =
                  (Color.lerp(
                            const Color(0xFF0088FF),
                            const Color(0xFF00FFFF),
                            pulse,
                          ) ??
                          const Color(0xFF0088FF))
                      .withValues(alpha: opacity)
              ..style = PaintingStyle.fill
              ..isAntiAlias = true;

            canvas.drawCircle(point, dotSize, dotPaint);
          } else {
            // Use gradient when idle
            final dotPaint = Paint()
              ..shader =
                  RadialGradient(
                    colors: [gradientColor1, gradientColor2],
                    stops: const [0.0, 1.0],
                  ).createShader(
                    Rect.fromCircle(center: point, radius: dotSize * 2),
                  )
              ..style = PaintingStyle.fill
              ..isAntiAlias = true;

            canvas.drawCircle(point, dotSize, dotPaint);
          }
        }
      }
    }

    // Draw enhanced pulsing reactive points when listening with blue gradient
    if (isListening) {
      for (int ring = 0; ring < spherePoints.length; ring += 15) {
        for (int seg = 0; seg < spherePoints[ring].length; seg += 15) {
          final point = spherePoints[ring][seg];
          final depth = depthMap[ring][seg];

          if (depth > 0) {
            final pulseSize = 2.0 + pulse * 5;

            // Blue pulse gradient
            final pulsePaint = Paint()
              ..shader =
                  RadialGradient(
                    colors: [
                      const Color(0xFF00FFFF).withValues(alpha: pulse * 0.8),
                      const Color(0xFF0088FF).withValues(alpha: pulse * 0.4),
                    ],
                    stops: const [0.0, 1.0],
                  ).createShader(
                    Rect.fromCircle(center: point, radius: pulseSize * 2),
                  )
              ..style = PaintingStyle.fill
              ..isAntiAlias = true;

            canvas.drawCircle(point, pulseSize, pulsePaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(WireSpherePainter oldDelegate) => true;
}
