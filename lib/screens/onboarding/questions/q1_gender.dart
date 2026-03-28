import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class Q1Gender extends StatefulWidget {
  final VoidCallback onNext;
  final int step;
  final int total;

  const Q1Gender({super.key, required this.onNext, required this.step, required this.total});

  @override
  State<Q1Gender> createState() => _Q1GenderState();
}

class _Q1GenderState extends State<Q1Gender> {
  String? _selected;

  final List<Map<String, String>> _options = [
    {'title': 'Male', 'emoji': '♂️'},
    {'title': 'Female', 'emoji': '♀️'},
    {'title': 'Other', 'emoji': '⚧'},
  ];

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
          'What is your biological sex?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This helps us calculate your metabolism and caloric needs accurately.',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        
        Expanded(
          child: ListView.separated(
            itemCount: _options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final opt = _options[index];
              final isSelected = _selected == opt['title'];
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selected = opt['title'];
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryContainer.withOpacity(0.05) : colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(
                        color: isSelected ? AppTheme.primaryContainer : Colors.transparent,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        opt['emoji']!,
                        style: TextStyle(
                          fontSize: 28,
                          color: isSelected ? null : Colors.grey, // Assuming emoji can scale grayscale but often we just rely on opacity
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          opt['title']!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryContainer : colorScheme.outline,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        // Next Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _selected != null ? widget.onNext : null,
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
