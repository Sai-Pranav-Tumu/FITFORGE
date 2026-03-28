import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class Q2Age extends StatefulWidget {
  final VoidCallback onNext;
  final int step;
  final int total;

  const Q2Age({super.key, required this.onNext, required this.step, required this.total});

  @override
  State<Q2Age> createState() => _Q2AgeState();
}

class _Q2AgeState extends State<Q2Age> {
  int _selectedAge = 25; // Default age
  late FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController(initialItem: _selectedAge - 15);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer.withOpacity(0.2),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(
            'Q${widget.step} OF ${widget.total}',
            style: const TextStyle(
              color: AppTheme.primaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'How old are you?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Age is a key factor in determining your target heart rate.',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        
        Expanded(
          child: Center(
            child: SizedBox(
              height: 250,
              width: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Custom Selection Highlight
                  Container(
                    height: 60,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryContainer.withOpacity(0.5), width: 2),
                    ),
                  ),
                  ListWheelScrollView.useDelegate(
                    controller: _scrollController,
                    itemExtent: 60,
                    physics: const FixedExtentScrollPhysics(),
                    perspective: 0.005,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedAge = 15 + index;
                      });
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 80 - 15 + 1, // 15 to 80
                      builder: (context, index) {
                        final age = 15 + index;
                        final isSelected = age == _selectedAge;
                        return Center(
                          child: Text(
                            age.toString(),
                            style: TextStyle(
                              fontSize: isSelected ? 36 : 28,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Next Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: widget.onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryContainer,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              elevation: 8,
              shadowColor: AppTheme.primaryContainer.withOpacity(0.5),
            ),
            child: const Text('Next →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
