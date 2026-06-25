import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';

const List<String> kDefaultAvatarKeys = <String>[
  'person',
  'run',
  'strength',
  'yoga',
  'cycle',
];

IconData avatarIcon(String? avatarKey) {
  switch (avatarKey) {
    case 'run':
      return Icons.directions_run;
    case 'strength':
      return Icons.fitness_center;
    case 'yoga':
      return Icons.self_improvement;
    case 'cycle':
      return Icons.pedal_bike;
    default:
      return Icons.person;
  }
}

Color avatarColor(String? avatarKey) {
  switch (avatarKey) {
    case 'run':
      return const Color(0xFF4E8DFF);
    case 'strength':
      return const Color(0xFFFF6B4A);
    case 'yoga':
      return const Color(0xFF2BB673);
    case 'cycle':
      return const Color(0xFF8B5CF6);
    default:
      return Colors.grey;
  }
}

/// Decodes the base64-stored avatar photo. Returns null when empty/invalid.
Uint8List? decodeAvatarImage(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}

/// Renders a user's avatar: the uploaded photo when set, otherwise the chosen
/// default icon avatar.
class UserAvatar extends StatelessWidget {
  final String? avatarKey;
  final String? avatarImage;
  final double radius;

  const UserAvatar({
    super.key,
    required this.avatarKey,
    required this.avatarImage,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = decodeAvatarImage(avatarImage);
    if (bytes != null) {
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: avatarColor(avatarKey),
      child: Icon(
        avatarIcon(avatarKey),
        color: Colors.white,
        size: radius * 0.86,
      ),
    );
  }
}

/// Opens a full-screen, zoomable view of the profile picture (or the default
/// avatar when no photo is set).
void showFullScreenAvatar(
  BuildContext context, {
  String? avatarKey,
  String? avatarImage,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: _FullScreenAvatarView(
          avatarKey: avatarKey,
          avatarImage: avatarImage,
        ),
      ),
    ),
  );
}

class _FullScreenAvatarView extends StatelessWidget {
  final String? avatarKey;
  final String? avatarImage;

  const _FullScreenAvatarView({
    required this.avatarKey,
    required this.avatarImage,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = decodeAvatarImage(avatarImage);
    final content = bytes != null
        ? InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.memory(bytes, fit: BoxFit.contain),
          )
        : CircleAvatar(
            radius: 110,
            backgroundColor: avatarColor(avatarKey),
            child: Icon(avatarIcon(avatarKey), color: Colors.white, size: 120),
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(child: content),
    );
  }
}

/// The result of the avatar picker: either a default [avatarKey] or an uploaded
/// photo [avatarImage] (base64).
class AvatarSelection {
  final String? avatarKey;
  final String? avatarImage;

  const AvatarSelection({this.avatarKey, this.avatarImage});
}

/// Shows a bottom sheet to take a photo, pick one from the gallery, or choose a
/// default avatar. Returns null if dismissed.
Future<AvatarSelection?> showAvatarPickerSheet(
  BuildContext context, {
  String? currentKey,
}) {
  return showModalBottomSheet<AvatarSelection>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AvatarPickerSheet(currentKey: currentKey),
  );
}

class _AvatarPickerSheet extends StatefulWidget {
  final String? currentKey;

  const _AvatarPickerSheet({this.currentKey});

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      // Compressed avatar so it stores comfortably in the Firestore profile
      // document (1 MB limit) and uploads quickly.
      final file = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (file == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final bytes = await file.readAsBytes();
      final encoded = base64Encode(bytes);
      if (!mounted) return;
      Navigator.of(context).pop(AvatarSelection(avatarImage: encoded));
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load image: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload your own photo or pick a default avatar.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.photo_camera_rounded,
                      label: 'Camera',
                      onTap: () => _pick(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () => _pick(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'OR PICK AN AVATAR',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: kDefaultAvatarKeys.map((avatar) {
                  final selected = widget.currentKey == avatar;
                  return GestureDetector(
                    onTap: () => Navigator.of(
                      context,
                    ).pop(AvatarSelection(avatarKey: avatar)),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppTheme.primaryContainer
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: avatarColor(avatar),
                        child: Icon(
                          avatarIcon(avatar),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: AppTheme.primaryContainer, size: 26),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
