import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../data/wards_catalog.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_card.dart';
import '../widgets/ns_outline_button.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_text_field.dart';
import '../widgets/ns_user_avatar.dart';

/// Citizen profile & preferences screen covering:
/// - US-09: Display name (3–40 chars, profanity-checked), JPEG/PNG <= 5MB
///   circular-cropped avatar, and reset to default icon.
/// - US-10: Home ward dropdown with landmarks and multi-select notification
///   channels (Push, SMS, Email).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.profileService,
    this.imagePicker,
    this.showWardPreferences = true,
  });

  final ProfileService? profileService;
  final ImagePicker? imagePicker;
  final bool showWardPreferences;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  ProfileService get _service => widget.profileService ?? ProfileService.instance;
  ImagePicker get _picker => widget.imagePicker ?? ImagePicker();

  int? _selectedWard;
  Set<NotificationChannel> _selectedChannels = {NotificationChannel.push};
  bool _savingName = false;
  bool _savingPhoto = false;
  bool _savingPreferences = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _syncFromProfile(_service.notifier.value);
    _service.loadProfile().then((profile) {
      if (!mounted) return;
      _syncFromProfile(profile);
    });
  }

  void _syncFromProfile(UserProfile? profile) {
    if (profile == null) return;
    if (!_initialized || _nameController.text.isEmpty) {
      _nameController.text = profile.displayName;
    }
    setState(() {
      _selectedWard = profile.homeWard ?? _selectedWard;
      _selectedChannels = Set<NotificationChannel>.from(
        profile.notificationChannels,
      );
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAndCropPhoto() async {
    if (_savingPhoto) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: NsColors.of(context).surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              subtitle: const Text('JPEG or PNG up to 5 MB'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              subtitle: const Text('JPEG or PNG up to 5 MB'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      final fileError = Validators.validateAvatarFile(
        fileName: picked.name.isNotEmpty ? picked.name : picked.path,
        byteLength: bytes.length,
      );
      if (fileError != null) {
        _showSnack(fileError);
        return;
      }

      if (!mounted) return;
      final croppedBytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute<Uint8List>(
          fullscreenDialog: true,
          builder: (_) => _AvatarCropPage(imageBytes: bytes),
        ),
      );
      if (croppedBytes == null || !mounted) return;

      setState(() => _savingPhoto = true);
      await _service.saveAvatarBytes(croppedBytes);
      if (!mounted) return;
      _showSnack('Profile photo updated.');
    } catch (_) {
      _showSnack('Could not update profile photo. Please try again.');
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _resetAvatar() async {
    if (_savingPhoto) return;
    setState(() => _savingPhoto = true);
    try {
      await _service.resetAvatar();
      _showSnack('Avatar reset to default icon.');
    } catch (_) {
      _showSnack('Could not reset avatar.');
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _saveDisplayName() async {
    if (_savingName) return;
    FocusScope.of(context).unfocus();
    if (!(_nameFormKey.currentState?.validate() ?? false)) return;

    setState(() => _savingName = true);
    try {
      await _service.updateDisplayName(_nameController.text);
      _showSnack('Display name updated across your profile, posts, and comments.');
    } on ArgumentError catch (e) {
      _showSnack('${e.message}');
    } catch (_) {
      _showSnack('Could not update display name.');
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _savePreferences() async {
    if (_savingPreferences) return;
    if (_selectedWard == null) {
      _showSnack('Please select your home ward.');
      return;
    }

    setState(() => _savingPreferences = true);
    try {
      final ward = WardsCatalog.byNumber(_selectedWard);
      await _service.updatePreferences(
        homeWard: _selectedWard,
        homeMunicipality:
            ward?.municipality ?? 'Kathmandu Metropolitan City',
        notificationChannels: _selectedChannels,
      );
      _showSnack('Home ward and notification preferences saved.');
    } catch (_) {
      _showSnack('Could not save preferences.');
    } finally {
      if (mounted) setState(() => _savingPreferences = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile & Settings')),
      body: NsBackground(
        child: SafeArea(
          top: false,
          child: ValueListenableBuilder<UserProfile?>(
            valueListenable: _service.notifier,
            builder: (context, profile, _) {
              final hasCustomAvatar = profile?.hasCustomAvatar == true;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                children: [
                  NsCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Profile Photo & Display Name',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: tokens.heading,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Updates appear immediately across your public posts and comments.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.muted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            NsUserAvatar(profile: profile, size: 76),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  NsPrimaryButton(
                                    label: hasCustomAvatar
                                        ? 'Change photo'
                                        : 'Upload photo',
                                    icon: Icons.camera_alt_rounded,
                                    isLoading: _savingPhoto,
                                    onPressed: _pickAndCropPhoto,
                                  ),
                                  const SizedBox(height: 8),
                                  NsOutlineButton(
                                    label: 'Reset avatar',
                                    icon: Icons.refresh_rounded,
                                    onPressed:
                                        hasCustomAvatar && !_savingPhoto
                                        ? _resetAvatar
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Form(
                          key: _nameFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              NsTextField(
                                controller: _nameController,
                                label: 'Display name',
                                hint: '3 to 40 characters',
                                icon: Icons.person_outline_rounded,
                                validator: Validators.displayName,
                                maxLength: 40,
                              ),
                              const SizedBox(height: 12),
                              NsPrimaryButton(
                                label: 'Save display name',
                                icon: Icons.check_rounded,
                                isLoading: _savingName,
                                onPressed: _saveDisplayName,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.showWardPreferences) ...[
                    const SizedBox(height: 16),
                    NsCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Home Ward & Notifications',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: tokens.heading,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your home feed defaults to reports from this ward.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.muted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            key: const Key('home-ward-dropdown'),
                            initialValue: _selectedWard,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Home Ward',
                              prefixIcon: const Icon(Icons.location_on_rounded),
                              filled: true,
                              fillColor: tokens.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            hint: const Text('Select your municipal ward'),
                            items: [
                              for (final ward in WardsCatalog.kathmanduWards)
                                DropdownMenuItem<int>(
                                  value: ward.wardNumber,
                                  child: Text(
                                    ward.dropdownLabel,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedWard = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Preferred notification channels',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: tokens.heading,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final channel in NotificationChannel.values)
                            Material(
                              type: MaterialType.transparency,
                              child: CheckboxListTile(
                                key: Key('channel-checkbox-${channel.key}'),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(
                                  channel.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.ink,
                                  ),
                                ),
                                value: _selectedChannels.contains(channel),
                                activeColor: AppColors.primary,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedChannels.add(channel);
                                    } else {
                                      _selectedChannels.remove(channel);
                                    }
                                  });
                                },
                              ),
                            ),
                          const SizedBox(height: 12),
                          NsPrimaryButton(
                            label: 'Save preferences',
                            icon: Icons.notifications_active_rounded,
                            isLoading: _savingPreferences,
                            onPressed: _savePreferences,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AvatarCropPage extends StatefulWidget {
  const _AvatarCropPage({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<_AvatarCropPage> {
  final _cropController = CropController();
  bool _cropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Profile Photo'),
        actions: [
          TextButton(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _cropController.crop();
                  },
            child: _cropping
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
      body: Crop(
        controller: _cropController,
        image: widget.imageBytes,
        withCircleUi: true,
        aspectRatio: 1,
        onCropped: (result) {
          if (!mounted) return;
          switch (result) {
            case CropSuccess(:final croppedImage):
              Navigator.of(context).pop(croppedImage);
            case CropFailure():
              setState(() => _cropping = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not crop this image.')),
              );
          }
        },
      ),
    );
  }
}
