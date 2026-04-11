import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/design/tokens.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/error_mapper.dart';
import '../../../core/router/router.dart';
import '../../../core/storage/session.dart';

class CreateRoomPage extends StatefulWidget {
  final LatLng? initialLocation;

  const CreateRoomPage({super.key, this.initialLocation});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  bool _loading = false;
  final _nameController = TextEditingController();
  final _placeController = TextEditingController();
  String _gameRule = 'TAIWAN_MAHJONG';
  bool _isPublic = true;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room name')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final location =
          _selectedLocation ?? await LocationService.instance.getCurrentPosition();
      final payload = {
        'name': name,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'isPublic': _isPublic,
        'gameRule': _gameRule,
      };
      final placeName = _placeController.text.trim();
      if (placeName.isNotEmpty) {
        payload['placeName'] = placeName;
      }

      final result = await ApiClient.post('/api/v1/rooms', payload);
      // Backend returns {"room": {...}}
      final room = result['room'] as Map<String, dynamic>?;
      final roomId = room?['id'] as String?;
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pop();
      if (roomId != null) {
        context.push(AppRoutes.room(roomId));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapApiError(e, fallback: 'Failed to create room.'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapApiError(e, fallback: 'Failed to create room.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Session.instance;
    final displayName = session.userName ?? 'You';
    final initials = session.avatarInitials;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Room'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: AppRadius.lg,
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your location will be shared',
                            style: AppTypography.labelLarge
                                .copyWith(color: AppColors.primary)),
                        Text(
                          _selectedLocation == null
                              ? 'Players within 5 km can see and join your room'
                              : 'Using your selected map position for this room',
                          style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primary.withOpacity(0.7)),
                        ),
                        if (_selectedLocation != null)
                          Text(
                            '${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                            style: AppTypography.labelSmall
                                .copyWith(color: AppColors.primary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Room name input
            Text('Room Name', style: AppTypography.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Coffee shop near MRT',
                prefixIcon: Icon(Icons.edit_rounded,
                    color: AppColors.textMuted, size: 20),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: AppSpacing.md),

            Text('Place Name (Optional)', style: AppTypography.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _placeController,
              decoration: const InputDecoration(
                hintText: 'e.g. Taipei Main Station',
                prefixIcon: Icon(Icons.place_rounded,
                    color: AppColors.textMuted, size: 20),
              ),
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: AppSpacing.md),

            Text('Game Rule', style: AppTypography.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              value: _gameRule,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.casino_rounded,
                    color: AppColors.textMuted, size: 20),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'TAIWAN_MAHJONG', child: Text('Taiwan Mahjong')),
                DropdownMenuItem(
                    value: 'THREE_PLAYER', child: Text('Three Player')),
                DropdownMenuItem(
                    value: 'NATIONAL_STANDARD', child: Text('National Standard')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _gameRule = v);
              },
            ),

            const SizedBox(height: AppSpacing.sm),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
              title: Text('Public Room', style: AppTypography.labelLarge),
              subtitle: Text(
                _isPublic
                    ? 'Visible to nearby players'
                    : 'Only available by direct room entry',
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              activeColor: AppColors.primary,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Room preview
            Text('Room Preview', style: AppTypography.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lg,
                border: Border.all(color: AppColors.divider),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: AppRadius.md,
                        ),
                        child: const Icon(Icons.table_restaurant_rounded,
                            color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName,
                              style: AppTypography.headlineMedium),
                          Text('Host · Waiting for players',
                              style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: List.generate(4, (i) {
                      final isMe = i == 0;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: isMe
                                  ? AppColors.secondary.withOpacity(0.1)
                                  : AppColors.surfaceVariant,
                              borderRadius: AppRadius.md,
                              border: Border.all(
                                color: isMe
                                    ? AppColors.secondary.withOpacity(0.3)
                                    : AppColors.divider,
                              ),
                            ),
                            child: Center(
                              child: isMe
                                  ? Text(initials,
                                      style: AppTypography.labelLarge
                                          .copyWith(
                                              color: AppColors.secondary))
                                  : const Icon(Icons.person_add_rounded,
                                      size: 20,
                                      color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            ElevatedButton.icon(
              onPressed: _loading ? null : _createRoom,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_rounded),
              label: Text(_loading ? 'Creating...' : 'Open Room'),
            ),
          ],
        ),
      ),
    );
  }
}
