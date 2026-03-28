import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class GeneratingScreen extends StatefulWidget {
  const GeneratingScreen({super.key});

  @override
  State<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends State<GeneratingScreen> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _sequenceSteps();
  }

  void _sequenceSteps() async {
    // Step 1 showing calculating BMI
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _currentStep = 1);

    // Step 2 selecting exercises
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _currentStep = 2);

    // Step 3 generating schedule
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _currentStep = 3);

    // Final navigation
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    context.go('/home');
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF131313), // Strict full dark background as requested
      body: Stack(
        children: [
          // Ambient Glow Blobs
          Positioned(
            top: -size.width * 0.2,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryContainer.withOpacity(0.1),
                    blurRadius: 120,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.2,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.5,
              height: size.width * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.tertiary.withOpacity(0.05), // Using tertiary for the ambient glow
                    blurRadius: 100,
                     spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // Center Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer rotating ring
                          AnimatedBuilder(
                            animation: _rotationController,
                            builder: (_, child) {
                              return Transform.rotate(
                                angle: _rotationController.value * 2 * pi,
                                child: CustomPaint(
                                  size: const Size(200, 200),
                                  painter: _RingPainter(colorScheme.surfaceContainerHighest, AppTheme.primaryContainer),
                                ),
                              );
                            },
                          ),
                          // Inner circle
                          Container(
                            width: 192,
                            height: 192,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.surfaceContainerHigh,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryContainer.withOpacity(0.15),
                                  blurRadius: 60,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.psychology, // Material Symbols psychology equivalent
                                size: 80,
                                color: AppTheme.primaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    Text(
                      'Building Your Plan...',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 24,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Analyzing biomechanics and lifestyle data to forge your ideal routine',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // 3 loading steps
                    _buildStepRow(
                      context,
                      text: "Calculating your BMI",
                      isCompleted: _currentStep >= 1,
                      isProcessing: _currentStep == 0,
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      context,
                      text: "Selecting optimal exercises",
                      isCompleted: _currentStep >= 2,
                      isProcessing: _currentStep == 1,
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      context,
                      text: "Generating weekly schedule...",
                      isCompleted: _currentStep >= 3,
                      isProcessing: _currentStep == 2,
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
          
          // Powered by AI pill
          Positioned(
            left: 0, right: 0, bottom: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer.withOpacity(0.1),
                    border: Border.all(color: AppTheme.primaryContainer.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppTheme.primaryContainer, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'POWERED BY AI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryContainer,
                          letterSpacing: 1.0,
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(BuildContext context, {required String text, required bool isCompleted, required bool isProcessing}) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Animate opacity based on state
    final double opacity = isCompleted || isProcessing ? 1.0 : 0.0;
    
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted 
                    ? AppTheme.tertiary.withOpacity(0.2) 
                    : AppTheme.primaryContainer.withOpacity(0.2),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: AppTheme.tertiary)
                  : (isProcessing 
                      ? const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryContainer),
                        )
                      : const SizedBox()),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCompleted || isProcessing ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color trackColor;
  final Color progressColor;

  _RingPainter(this.trackColor, this.progressColor);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // 180 degrees arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // start at top
      pi,      // 180 degrees in radians
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => false;
}
