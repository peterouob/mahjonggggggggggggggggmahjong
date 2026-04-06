import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/tokens.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/router.dart';
import '../../../core/storage/session.dart';

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  bool _loading = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
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
      final location = await LocationService.instance.getCurrentPosition();
      final result = await ApiClient.post('/api/v1/rooms', {
        'name': name,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'isPublic': true,
      });
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
        SnackBar(content: Text('Failed to create room: ${e.body}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
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
                          'Players within 5 km can see and join your room',
                          style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primary.withOpacity(0.7)),
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
