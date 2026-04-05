import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FitForge Privacy Policy',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: March 31, 2026',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This policy explains what FitForge stores, what stays on your device, how your account works, and how you can delete your data.',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              for (final section in _policySections) ...[
                _PolicySectionCard(section: section),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySectionCard extends StatelessWidget {
  const _PolicySectionCard({required this.section});

  final _PolicySection section;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final paragraph in section.paragraphs) ...[
            Text(
              paragraph,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PolicySection {
  const _PolicySection({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;
}

const List<_PolicySection> _policySections = <_PolicySection>[
  _PolicySection(
    title: 'What We Collect',
    paragraphs: <String>[
      'FitForge stores the account information needed to create and maintain your profile. This includes your email address, your sign-in provider, your FitForge user ID, and the name you choose or confirm inside the app.',
      'FitForge also stores profile details that personalize your workouts and nutrition experience, including age, gender, height, weight, occupation, sitting time, fitness goal, workout availability, equipment access, joint sensitivity, dietary preference, and similar fitness-preference settings.',
    ],
  ),
  _PolicySection(
    title: 'What Stays On Your Device',
    paragraphs: <String>[
      'Hydration reminder settings, water logs, saved diet plans, and nutrition meal history are stored locally on your device. FitForge uses this local information to personalize reminders and progress screens.',
      'The exercise library download is content only. It is not tied to your identity and is not treated as personal data.',
    ],
  ),
  _PolicySection(
    title: 'How We Use Data',
    paragraphs: <String>[
      'We use your profile data to create a FitForge account, sign you in securely, save your onboarding choices, personalize workouts, and keep your settings available when you return.',
      'We use local nutrition and hydration data to show daily and monthly summaries, meal history, water progress, and saved plans directly inside the app.',
    ],
  ),
  _PolicySection(
    title: 'Service Providers',
    paragraphs: <String>[
      'FitForge uses Firebase Authentication for sign-in, Google Sign-In when you choose that option, and Cloud Firestore to store your FitForge profile. These providers process data on our behalf so the app can function.',
      'FitForge does not sell your personal data and does not share your personal data with advertisers.',
    ],
  ),
  _PolicySection(
    title: 'Notifications',
    paragraphs: <String>[
      'If you enable hydration reminders, FitForge schedules local notifications on your device. These reminders are approximate and can be turned off at any time from the notification settings inside the app.',
    ],
  ),
  _PolicySection(
    title: 'Retention And Deletion',
    paragraphs: <String>[
      'You can delete your account at any time from Profile > Delete Account. This permanently deletes your FitForge authentication account and your synced FitForge profile stored in Cloud Firestore.',
      'When you delete your account from inside the app, FitForge also clears your local nutrition meal history, saved diet plan, hydration reminder settings, and water-tracking data from the device.',
      'Non-personal files such as the downloaded exercise library may remain on the device because they are not tied to your identity.',
    ],
  ),
  _PolicySection(
    title: 'Questions',
    paragraphs: <String>[
      'For privacy questions or manual deletion requests when you cannot access the app, use the support contact published on the FitForge website or Google Play listing.',
    ],
  ),
];
