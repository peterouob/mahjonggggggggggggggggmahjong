import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/friend_model.dart';
import '../../../data/models/models.dart' show PlayerStatus;
import '../../../mock/mock_data.dart' show kMockMode;
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/status_badge.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  List<Friend> _friends = [];
  List<FriendRequest> _requests = [];
  bool _loading = false;
  String? _error;
  String _search = '';

  List<Friend> get _filtered => _friends
      .where((f) => f.name.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  List<Friend> get _online =>
      _filtered.where((f) => f.status != PlayerStatus.offline).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (kMockMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _friends = _mockFriends();
        _requests = [];
        _loading = false;
      });
      return;
    }

    try {
      final results = await Future.wait([
        ApiClient.get('/api/v1/friends'),
        ApiClient.get('/api/v1/friends/requests'),
      ]);
      if (!mounted) return;
      setState(() {
        // Backend wraps lists: {"friends": [...]} and {"requests": [...]}
        final friendsRaw = (results[0] as Map<String, dynamic>)['friends'] as List<dynamic>? ?? [];
        final requestsRaw = (results[1] as Map<String, dynamic>)['requests'] as List<dynamic>? ?? [];
        _friends = friendsRaw
            .map((j) => Friend.fromJson(j as Map<String, dynamic>))
            .toList();
        _requests = requestsRaw
            .map((j) => FriendRequest.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Friend> _mockFriends() => [
        const Friend(
          id: 'f1',
          userId: 'mock-u1',
          userName: 'Alice Wong',
          isOnline: true,
          isPlaying: false,
          distanceKm: 0.4,
          rating: 1920,
        ),
        const Friend(
          id: 'f2',
          userId: 'mock-u2',
          userName: 'Bob Lee',
          isOnline: true,
          isPlaying: false,
          distanceKm: 0.6,
          rating: 1750,
        ),
        const Friend(
          id: 'f3',
          userId: 'mock-u4',
          userName: 'Frank Yip',
          isOnline: true,
          isPlaying: true,
          distanceKm: 1.5,
          rating: 2010,
        ),
        const Friend(
          id: 'f4',
          userId: 'mock-u5',
          userName: 'Kenny Wu',
          isOnline: false,
          isPlaying: false,
          distanceKm: 3.2,
          rating: 1630,
        ),
      ];

  Future<void> _acceptRequest(FriendRequest req) async {
    try {
      await ApiClient.put('/api/v1/friends/requests/${req.id}/accept', {});
      _load(); // Refresh both lists
    } catch (e) {
      _snack('Failed to accept: $e');
    }
  }

  Future<void> _rejectRequest(FriendRequest req) async {
    try {
      await ApiClient.put('/api/v1/friends/requests/${req.id}/reject', {});
      setState(() => _requests.remove(req));
    } catch (e) {
      _snack('Failed to reject: $e');
    }
  }

  Future<void> _removeFriend(Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Remove ${friend.name} from your friends?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove',
                  style: TextStyle(color: AppColors.full))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/api/v1/friends/${friend.id}');
      setState(() => _friends.remove(friend));
    } catch (e) {
      _snack('Failed to remove: $e');
    }
  }

  Future<void> _sendFriendRequest(String targetUsername) async {
    try {
      await ApiClient.post('/api/v1/friends/requests', {
        'toUsername': targetUsername,
      });
      _snack('Friend request sent!');
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            color: AppColors.primary,
            onPressed: () => _showAddFriend(context),
            tooltip: 'Add Friend',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : Column(
                  children: [
                    // ── Search ───────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(
                          hintText: 'Search friends...',
                          prefixIcon: Icon(Icons.search_rounded,
                              color: AppColors.textMuted, size: 20),
                        ),
                      ),
                    ),

                    // ── Pending requests banner ───────────────────────
                    if (_requests.isNotEmpty)
                      _RequestsBanner(
                        requests: _requests,
                        onAccept: _acceptRequest,
                        onReject: _rejectRequest,
                      ),

                    // ── Online now ────────────────────────────────────
                    if (_online.isNotEmpty) ...[
                      _SectionHeader(
                        label: 'Online Now',
                        count: _online.length,
                        color: AppColors.online,
                      ),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: 8),
                          itemCount: _online.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (ctx, i) =>
                              _OnlineAvatar(friend: _online[i]),
                        ),
                      ),
                    ],

                    // ── All friends list ──────────────────────────────
                    Expanded(
                      child: _filtered.isEmpty
                          ? _EmptyState(
                              hasSearch: _search.isNotEmpty,
                              onAdd: () => _showAddFriend(context),
                            )
                          : ListView(
                              padding: const EdgeInsets.only(top: 8),
                              children: [
                                if (_online.isNotEmpty)
                                  _SectionHeader(
                                    label: 'All Friends',
                                    count: _filtered.length,
                                  ),
                                ..._filtered.map(
                                  (f) => _FriendTile(
                                    friend: f,
                                    onRemove: () => _removeFriend(f),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }

  void _showAddFriend(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: AppRadius.full),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Add Friend', style: AppTypography.headlineLarge),
            const SizedBox(height: AppSpacing.sm),
            Text('Enter their username to send a friend request',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter username...',
                prefixIcon: Icon(Icons.person_search_rounded,
                    color: AppColors.textMuted, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () {
                final username = ctrl.text.trim();
                if (username.isEmpty) return;
                Navigator.pop(context);
                _sendFriendRequest(username);
              },
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text('Could not load friends', style: AppTypography.headlineMedium),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onAdd;
  const _EmptyState({required this.hasSearch, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline_rounded,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            hasSearch ? 'No results' : 'No friends yet',
            style: AppTypography.headlineMedium,
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add a Friend'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestsBanner extends StatelessWidget {
  final List<FriendRequest> requests;
  final ValueChanged<FriendRequest> onAccept;
  final ValueChanged<FriendRequest> onReject;

  const _RequestsBanner(
      {required this.requests,
      required this.onAccept,
      required this.onReject});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showRequests(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.08),
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${requests.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${requests.length} pending friend request${requests.length > 1 ? 's' : ''}',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.secondary),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.secondary),
          ],
        ),
      ),
    );
  }

  void _showRequests(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider, borderRadius: AppRadius.full),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child:
                Text('Friend Requests', style: AppTypography.headlineMedium),
          ),
          const SizedBox(height: 8),
          ...requests.map(
            (req) => ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(req.fromAvatar,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              title: Text(req.fromUserName,
                  style: AppTypography.headlineMedium),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_rounded,
                        color: AppColors.online),
                    onPressed: () {
                      Navigator.pop(context);
                      onAccept(req);
                    },
                    tooltip: 'Accept',
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded,
                        color: AppColors.full),
                    onPressed: () {
                      Navigator.pop(context);
                      onReject(req);
                    },
                    tooltip: 'Reject',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color? color;

  const _SectionHeader({required this.label, required this.count, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          Text(label, style: AppTypography.labelLarge),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (color ?? AppColors.textMuted).withOpacity(0.12),
              borderRadius: AppRadius.full,
            ),
            child: Text(
              '$count',
              style: AppTypography.labelSmall.copyWith(
                color: color ?? AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineAvatar extends StatelessWidget {
  final Friend friend;
  const _OnlineAvatar({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppAvatar(
          initials: friend.avatar,
          size: 52,
          backgroundColor: AppColors.friendMarker,
          showOnlineDot: true,
          isOnline: friend.status == PlayerStatus.online,
          isPlaying: friend.status == PlayerStatus.playing,
        ),
        const SizedBox(height: 4),
        Text(
          friend.name.split(' ').first,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  final Friend friend;
  final VoidCallback onRemove;

  const _FriendTile({required this.friend, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 4),
      leading: AppAvatar(
        initials: friend.avatar,
        size: 48,
        backgroundColor: friend.status == PlayerStatus.offline
            ? AppColors.textMuted
            : AppColors.friendMarker,
        showOnlineDot: true,
        isOnline: friend.status == PlayerStatus.online,
        isPlaying: friend.status == PlayerStatus.playing,
      ),
      title: Text(friend.name, style: AppTypography.headlineMedium),
      subtitle: Row(
        children: [
          PlayerStatusDot(status: friend.status),
          if (friend.status != PlayerStatus.offline) ...[
            const SizedBox(width: 10),
            const Icon(Icons.location_on_rounded,
                size: 12, color: AppColors.textMuted),
            const SizedBox(width: 3),
            Text('${friend.distanceKm.toStringAsFixed(1)} km',
                style: AppTypography.labelSmall),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (friend.rating != null) ...[
            Icon(Icons.star_rounded, size: 14, color: AppColors.waiting),
            const SizedBox(width: 3),
            Text('${friend.rating}', style: AppTypography.labelSmall),
            const SizedBox(width: 8),
          ],
          if (friend.status != PlayerStatus.offline)
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.table_restaurant_rounded,
                    color: AppColors.primary, size: 18),
              ),
            ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textMuted, size: 20),
            onSelected: (v) {
              if (v == 'remove') onRemove();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.person_remove_rounded,
                        color: AppColors.full, size: 18),
                    SizedBox(width: 10),
                    Text('Remove Friend',
                        style: TextStyle(color: AppColors.full)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
