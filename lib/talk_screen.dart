import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';


class TalkScreen extends StatefulWidget {
  const TalkScreen({super.key});

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> with SingleTickerProviderStateMixin {
  bool isPause = false;
  late AnimationController _rotationController;
  late Timer _pulseTimer;
  double _pulseValue = 0.0;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _pulseTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isListening) {
        setState(() {
          _pulseValue = (sin(DateTime.now().millisecondsSinceEpoch / 300.0) + 1) / 2;
        });
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseTimer.cancel();
    super.dispose();
  }

  void _startListening() {
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
      _pulseValue = 0.0;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Talk with AI',
          style: TextStyle(
            fontSize: 36,
            color: Colors.white
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 14, 14, 14),
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 14, 14, 14),
        ),
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
                'Go ahead, I\'m listening💡',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
            // SizedBox(
            //   height: 300,
            //   child: ModelViewer(
            //     src: 'assets/images/3d_sphere.glb',
            //     alt: "3D sphere",
            //     autoRotate: true,
            //     cameraControls: true,
            //   ),
            // ),
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
                      });
                    },
                    child: CircleAvatar(
                      maxRadius: 30,
                      backgroundColor: Colors.grey.shade900,
                      child: Icon(
                        (isPause)? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                      )
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
                              Color.fromARGB(255, 255, 234, 0),
                              Color(0xFFFF0000),
                            ]
                          ),
                        ),
                        child: IconButton(
                          onPressed: () {
                            _startListening();
                            setState(() {
                              isPause = false;
                            });
                            // TODO: Implement voice input
                            Future.delayed(const Duration(seconds: 3), () {
                              _stopListening();
                            });
                          },
                          icon: Icon(
                            Icons.mic_rounded,
                            size: 36,
                            color: Colors.white,
                          )
                        ),
                      ),
                      SizedBox(height: 40,)
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: CircleAvatar(
                      maxRadius: 30,
                      backgroundColor: Colors.grey.shade900,
                      child: Icon(
                        Icons.cancel,
                        color: Colors.white,
                      )
                    ),
                  ),
                ],
              ),
            )
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

  List<Offset> projectPoint(double x, double y, double z, double rotY, double rotX, Offset center, double scale) {
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
          ? (const Color(0xFF0088FF)).withOpacity(0.3)
          : const Color(0xFFFFAA00).withOpacity(0.2)
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

        final projected = projectPoint(x, y, z, rotationY, rotationX, center, 1.0);
        ringPoints.add(projected[0]);
        ringDepths.add(projected[1].dx);
      }

      spherePoints.add(ringPoints);
      depthMap.add(ringDepths);
    }

    // Draw edge highlight glow
    canvas.drawCircle(center, radius * 0.98, glowPaint);

    // Draw all dots with gradient or listening color
    for (int ring = 0; ring < spherePoints.length; ring += 10) { // Sample every 10th ring for performance
      for (int seg = 0; seg < spherePoints[ring].length; seg += 10) { // Sample every 10th segment
        final point = spherePoints[ring][seg];
        final depth = depthMap[ring][seg];
        
        // Only draw dots on front hemisphere
        if (depth > -radius * 0.3) {
          // Vary dot size and opacity based on depth
          final depthFactor = (depth + radius) / (2 * radius);
          final dotSize = 0.8 + depthFactor * 1.2;
          final opacity = 0.2 + depthFactor * 0.8;
          
          if (isListening) {
            // Use blue color when listening
            final dotPaint = Paint()
              ..color = (Color.lerp(const Color(0xFF0088FF), const Color(0xFF00FFFF), pulse) ?? const Color(0xFF0088FF))
                  .withOpacity(opacity)
              ..style = PaintingStyle.fill
              ..isAntiAlias = true;
            
            canvas.drawCircle(point, dotSize, dotPaint);
          } else {
            // Use gradient when idle
            final dotPaint = Paint()
              ..shader = RadialGradient(
                colors: [gradientColor1, gradientColor2],
                stops: const [0.0, 1.0],
              ).createShader(Rect.fromCircle(center: point, radius: dotSize * 2))
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
              ..shader = RadialGradient(
                colors: [
                  const Color(0xFF00FFFF).withOpacity(pulse * 0.8),
                  const Color(0xFF0088FF).withOpacity(pulse * 0.4),
                ],
                stops: const [0.0, 1.0],
              ).createShader(Rect.fromCircle(center: point, radius: pulseSize * 2))
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