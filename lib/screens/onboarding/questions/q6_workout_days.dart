import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class Q6WorkoutDays extends StatefulWidget {
  final VoidCallback onNext;
  final int step;
  final int total;

  const Q6WorkoutDays({super.key, required this.onNext, required this.step, required this.total});

  @override
  State<Q6WorkoutDays> createState() => _Q6WorkoutDaysState();
}

class _Q6WorkoutDaysState extends State<Q6WorkoutDays> {
  int? _selectedDays;

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
          'How many days per week can you workout?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select your ideal frequency.',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        
        // Wrap of chips 1-7 (Multi-select explicitly NOT allowed according to prompt)
        Wrap(
          spacing: 12,
          runSpacing: 16,
          children: List.generate(7, (index) {
            final days = index + 1;
            final isSelected = _selectedDays == days;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDays = days;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryContainer : colorScheme.surfaceContainerLow,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryContainer.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    days.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        
        const Spacer(),
        
        // Next Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _selectedDays != null ? widget.onNext : null,
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
