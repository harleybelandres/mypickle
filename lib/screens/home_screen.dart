import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/category_model.dart';
import '../models/match_model.dart';
import '../models/tournament_model.dart';
import '../models/user_model.dart';
import '../providers/tournament_provider.dart';
import '../services/auth_service.dart';
import '../services/local_db_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  final _searchController = TextEditingController();
  var _selectedIndex = 0;
  var _isRefreshing = false;
  var _searchQuery = '';

  UserModel? get _currentUser => _auth.getCurrentUser();
  bool get _isAdmin => _currentUser?.role == 'admin';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    try {
      final provider = Provider.of<TournamentProvider>(context, listen: false);
      await provider.fetchApprovedTournaments();
      if (_isAdmin) {
        await provider.fetchPendingTournaments();
      }
      final user = _currentUser;
      if (user != null) {
        await provider.fetchCreatedTournaments(user.id);
        await provider.fetchUmpires();
        if (!_isAdmin) {
          await provider.fetchRegisteredTournaments(user.id);
          if (user.role == 'umpire') {
            await provider.fetchUmpiredTournaments(user.id);
            await provider.fetchAssignedMatches(user.id);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Home', 'Dashboard', 'Profile'];
    final user = _currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isRefreshing ? null : _refresh,
            icon: AnimatedRotation(
              turns: _isRefreshing ? 1 : 0,
              duration: const Duration(milliseconds: 650),
              child: const Icon(Icons.refresh_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: !_isAdmin && _selectedIndex == 0
          ? FloatingActionButton.extended(
              tooltip: 'Create tournament',
              onPressed: () =>
                  Navigator.pushNamed(context, '/create-tournament'),
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      body: Consumer<TournamentProvider>(
        builder: (context, provider, _) {
          final pages = [
            _TournamentHomeTab(
              tournaments: provider.tournaments,
              searchController: _searchController,
              searchQuery: _searchQuery,
              onSearchChanged: (value) {
                setState(() => _searchQuery = value);
              },
              onRefresh: _refresh,
            ),
            _DashboardTab(
              user: user,
              isAdmin: _isAdmin,
              provider: provider,
              onRefresh: _refresh,
              onBrowseHome: () => setState(() => _selectedIndex = 0),
            ),
            _ProfileTab(user: user, isAdmin: _isAdmin, onLogout: _logout),
          ];

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: KeyedSubtree(
              key: ValueKey(_selectedIndex),
              child: pages[_selectedIndex],
            ),
          );
        },
      ),
    );
  }
}

class _TournamentHomeTab extends StatelessWidget {
  const _TournamentHomeTab({
    required this.tournaments,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  final List<TournamentModel> tournaments;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final filtered = _filterTournaments(tournaments, searchQuery);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const _AnimatedIn(
            child: _HeroPanel(
              title: 'Find approved tournaments',
              message:
                  'Browse active pickleball events, categories, slots, and locations.',
              icon: Icons.sports_tennis,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search tournaments',
              hintText: 'Title, address, date, category, skill level',
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: 'Approved Tournaments', count: filtered.length),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: filtered.isEmpty
                ? const _EmptyState(
                    key: ValueKey('no-approved'),
                    title: 'No tournaments found',
                    message:
                        'Try another title, address, date, category, or skill.',
                    icon: Icons.event_busy_outlined,
                  )
                : Column(
                    key: const ValueKey('approved-list'),
                    children: [
                      for (var i = 0; i < filtered.length; i++) ...[
                        _AnimatedIn(
                          delay: 80 + (i * 45),
                          child: TournamentCard(tournament: filtered[i]),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static List<TournamentModel> _filterTournaments(
    List<TournamentModel> tournaments,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return tournaments;
    return tournaments.where((t) {
      final date = t.date.toLocal().toString().split(' ').first;
      final haystack = [
        t.name,
        t.location,
        date,
        for (final category in t.categories) category.name,
        for (final category in t.categories) category.skillLevel,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.user,
    required this.isAdmin,
    required this.provider,
    required this.onRefresh,
    required this.onBrowseHome,
  });

  final UserModel? user;
  final bool isAdmin;
  final TournamentProvider provider;
  final Future<void> Function() onRefresh;
  final VoidCallback onBrowseHome;

  @override
  Widget build(BuildContext context) {
    final approved = provider.tournaments;
    final pending = isAdmin
        ? provider.pendingTournaments
        : const <TournamentModel>[];
    if (isAdmin) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _SectionTitle(
              title: 'Tournaments Under Approval',
              count: pending.length,
            ),
            const SizedBox(height: 8),
            if (pending.isEmpty)
              const _EmptyState(
                title: 'No pending tournaments',
                message: 'New requests will appear here.',
                icon: Icons.task_alt_rounded,
              )
            else
              for (final tournament in pending) ...[
                PendingTournamentCard(tournament: tournament),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 14),
            _SectionTitle(
              title: 'Approved Tournaments',
              count: approved.length,
            ),
            const SizedBox(height: 8),
            if (approved.isEmpty)
              const _EmptyState(
                title: 'No approved tournaments',
                message: 'Approved tournaments will appear here.',
                icon: Icons.event_busy_outlined,
              )
            else
              for (final tournament in approved) ...[
                _AdminApprovedTournamentCard(tournament: tournament),
                const SizedBox(height: 8),
              ],
          ],
        ),
      );
    }

    final created = provider.createdTournaments;
    final registered = provider.registeredTournaments;
    final umpired = provider.umpiredTournaments;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _AnimatedIn(
            child: _DashboardHeader(
              name: user?.name ?? 'Player',
              role: user?.role ?? 'player',
              isAdmin: isAdmin,
            ),
          ),
          const SizedBox(height: 14),
          _SectionTitle(title: 'Created Tournaments', count: created.length),
          const SizedBox(height: 10),
          if (created.isEmpty)
            const _EmptyState(
              title: 'No created tournaments',
              message: 'Create a tournament to manage brackets and games.',
              icon: Icons.add_circle_outline,
            )
          else
            for (final tournament in created) ...[
              _CreatorTournamentCard(tournament: tournament),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'Registered Tournaments',
            count: registered.length,
          ),
          const SizedBox(height: 10),
          if (registered.isEmpty)
            const _EmptyState(
              title: 'No registrations yet',
              message: 'Register from tournament details on Home.',
              icon: Icons.how_to_reg_outlined,
            )
          else
            for (final tournament in registered) ...[
              TournamentCard(tournament: tournament),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 18),
          if (user?.role == 'umpire') ...[
            _SectionTitle(title: 'Umpire Tournaments', count: umpired.length),
            const SizedBox(height: 10),
            if (umpired.isEmpty)
              const _EmptyState(
                title: 'No umpire assignments',
                message: 'Apply as umpire from tournament details.',
                icon: Icons.sports_outlined,
              )
            else
              for (final tournament in umpired) ...[
                TournamentCard(tournament: tournament),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 18),
            _SectionTitle(
              title: 'Assigned Games',
              count: provider.matches.length,
            ),
            const SizedBox(height: 10),
            if (provider.matches.isEmpty)
              const _EmptyState(
                title: 'No assigned games',
                message: 'Assigned games will appear here.',
                icon: Icons.scoreboard_outlined,
              )
            else
              for (final match in provider.matches) ...[
                _MatchCard(
                  match: match,
                  canScore: true,
                  onScore: () => _showScoreSheet(context, provider, match),
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 18),
          ],
          const SizedBox(height: 18),
          _QuickActionCard(
            icon: Icons.add_circle_outline,
            title: 'Create tournament',
            message: 'Set registration dates and category divisions.',
            onTap: () => Navigator.pushNamed(context, '/create-tournament'),
          ),
          const SizedBox(height: 10),
          _QuickActionCard(
            icon: Icons.home_outlined,
            title: 'Browse home',
            message: 'Search approved tournaments.',
            onTap: onBrowseHome,
          ),
        ],
      ),
    );
  }

  Future<void> _showScoreSheet(
    BuildContext context,
    TournamentProvider provider,
    MatchModel match,
  ) async {
    final scoreAController = TextEditingController(
      text: match.scoreA == 0 ? '' : match.scoreA.toString(),
    );
    final scoreBController = TextEditingController(
      text: match.scoreB == 0 ? '' : match.scoreB.toString(),
    );
    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score game',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: scoreAController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _playerName(match.playerA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: scoreBController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _playerName(match.playerB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final scoreA =
                          int.tryParse(scoreAController.text.trim()) ?? -1;
                      final scoreB =
                          int.tryParse(scoreBController.text.trim()) ?? -1;
                      if (scoreA < 0 || scoreB < 0 || scoreA == scoreB) {
                        return;
                      }
                      Navigator.pop(context, {'a': scoreA, 'b': scoreB});
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save score'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result == null) return;
    await provider.updateScore(
      tournamentId: match.tournamentId,
      matchId: match.id,
      scoreA: result['a']!,
      scoreB: result['b']!,
      playerAId: match.playerA,
      playerBId: match.playerB,
    );
  }

  String _playerName(String playerId) {
    return LocalDbService.instance.getUserById(playerId)?.name ?? playerId;
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.user,
    required this.isAdmin,
    required this.onLogout,
  });

  final UserModel? user;
  final bool isAdmin;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _AnimatedIn(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF183A2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  child: Text(
                    _initials(user?.name ?? 'P'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Player',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'No email',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AnimatedIn(
          delay: 80,
          child: _Surface(
            child: Column(
              children: [
                _ProfileRow(
                  icon: Icons.badge_outlined,
                  label: 'Role',
                  value: (user?.role ?? 'player').toUpperCase(),
                ),
                const Divider(height: 22),
                _ProfileRow(
                  icon: Icons.key_outlined,
                  label: 'User ID',
                  value: user?.id ?? 'Not signed in',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _AnimatedIn(
          delay: 200,
          child: FilledButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class TournamentCard extends StatelessWidget {
  const TournamentCard({super.key, required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService().getCurrentUser();
    final dateText = tournament.date.toLocal().toString().split(' ').first;
    final players = tournament.categories.fold<int>(
      0,
      (sum, category) => sum + category.players.length,
    );
    final slots = tournament.categories.fold<int>(
      0,
      (sum, category) => sum + category.slots,
    );
    final isCreator = currentUser?.id == tournament.creatorId;
    final isAssignedUmpire =
        currentUser != null && tournament.umpireId == currentUser.id;
    final hasAssignedUmpire = tournament.umpireId.isNotEmpty;
    final umpireApplicationStatus = currentUser == null
        ? null
        : tournament.umpireApplications[currentUser.id];
    final canApplyAsUmpire =
        currentUser != null &&
        !isCreator &&
        !hasAssignedUmpire &&
        umpireApplicationStatus != 'pending' &&
        umpireApplicationStatus != 'approved';

    return InkWell(
      onTap: () => _showTournamentDetails(context, tournament),
      borderRadius: BorderRadius.circular(8),
      child: _Surface(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 8,
                    child: _TournamentCoverImage(tournament: tournament),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _StatusPill(status: tournament.status),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tournament.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DetailLine(
                    icon: Icons.place_outlined,
                    text: tournament.location,
                  ),
                  const SizedBox(height: 6),
                  _DetailLine(
                    icon: Icons.calendar_month_outlined,
                    text: dateText,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.category_outlined,
                        text: '${tournament.categories.length} categories',
                      ),
                      _InfoChip(
                        icon: Icons.groups_outlined,
                        text: '$players/$slots players',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: canApplyAsUmpire
                          ? () => _applyAsUmpire(context, tournament)
                          : null,
                      icon: const Icon(Icons.sports_outlined),
                      label: Text(
                        _applyAsUmpireLabel(
                          currentUser: currentUser,
                          isCreator: isCreator,
                          isAssignedUmpire: isAssignedUmpire,
                          hasAssignedUmpire: hasAssignedUmpire,
                          status: umpireApplicationStatus,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _applyAsUmpireLabel({
    required UserModel? currentUser,
    required bool isCreator,
    required bool isAssignedUmpire,
    required bool hasAssignedUmpire,
    required String? status,
  }) {
    if (currentUser == null) return 'Sign in to apply as umpire';
    if (isCreator) return 'Creator cannot apply';
    if (isAssignedUmpire) return 'Assigned umpire';
    if (hasAssignedUmpire) return 'Umpire assigned';
    if (status == 'pending') return 'Application pending';
    if (status == 'approved') return 'Application approved';
    if (status == 'rejected') return 'Apply again as umpire';
    return 'Apply as umpire';
  }

  static Future<void> _applyAsUmpire(
    BuildContext context,
    TournamentModel tournament,
  ) async {
    final currentUser = AuthService().getCurrentUser();
    if (currentUser == null) return;
    final provider = Provider.of<TournamentProvider>(context, listen: false);

    try {
      await provider.applyAsUmpire(
        tournamentId: tournament.id,
        umpireId: currentUser.id,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Umpire application submitted.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Application failed: $e')));
    }
  }

  static String _coverUrl(TournamentModel tournament) {
    final covers = [
      'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1599474924187-334a4ae5bd3c?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1542144582-1ba00456b5e3?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=900&q=80',
    ];
    final index = tournament.id.hashCode.abs() % covers.length;
    return covers[index];
  }

  static void _showTournamentDetails(
    BuildContext context,
    TournamentModel tournament,
  ) {
    final rootContext = context;
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final currentUser = AuthService().getCurrentUser();
    final isCreator = currentUser?.id == tournament.creatorId;
    final canRegister =
        currentUser != null && currentUser.role != 'admin' && !isCreator;
    var umpireApplicationStatus = currentUser == null
        ? null
        : tournament.umpireApplications[currentUser.id];
    final isAssignedUmpire =
        currentUser != null && tournament.umpireId == currentUser.id;
    final hasAssignedUmpire = tournament.umpireId.isNotEmpty;
    final unavailableLabel = currentUser?.role == 'admin'
        ? 'Players only'
        : isCreator
        ? 'Creator'
        : 'Login required';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final players = tournament.categories.fold<int>(
          0,
          (sum, category) => sum + category.players.length,
        );
        String? registeringCategory;
        var isApplyingAsUmpire = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> register(CategoryModel category) async {
              if (currentUser == null) return;
              final registrationDetails = await _showRegistrationFormSheet(
                context,
                category: category,
                currentUser: currentUser,
              );
              if (registrationDetails == null) return;

              setSheetState(() => registeringCategory = category.name);
              try {
                await provider.registerPlayer(
                  tournamentId: tournament.id,
                  playerId: currentUser.id,
                  categoryName: category.name,
                  registrationDetails: registrationDetails,
                );
                if (!rootContext.mounted) return;
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(content: Text('Registration completed.')),
                );
              } catch (e) {
                if (!rootContext.mounted) return;
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(content: Text('Registration failed: $e')),
                );
              } finally {
                if (context.mounted) {
                  setSheetState(() => registeringCategory = null);
                }
              }
            }

            Future<void> applyAsUmpire() async {
              if (currentUser == null) return;
              setSheetState(() => isApplyingAsUmpire = true);
              try {
                await provider.applyAsUmpire(
                  tournamentId: tournament.id,
                  umpireId: currentUser.id,
                );
                if (!rootContext.mounted) return;
                setSheetState(() => umpireApplicationStatus = 'pending');
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(
                    content: Text('Umpire application submitted.'),
                  ),
                );
              } catch (e) {
                if (!rootContext.mounted) return;
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  SnackBar(content: Text('Application failed: $e')),
                );
              } finally {
                if (context.mounted) {
                  setSheetState(() => isApplyingAsUmpire = false);
                }
              }
            }

            Future<void> viewGames() async {
              await provider.fetchMatchesByTournament(tournament.id);
              if (!rootContext.mounted) return;
              _showTournamentGamesSheet(
                rootContext,
                provider,
                currentUmpireId: currentUser?.id ?? '',
              );
            }

            Future<void> viewStats() async {
              await provider.fetchMatchesByTournament(tournament.id);
              if (!rootContext.mounted) return;
              _showTournamentStatsSheet(rootContext, provider.matches);
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 16 / 8,
                        child: _TournamentCoverImage(tournament: tournament),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tournament.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _DetailLine(
                      icon: Icons.place_outlined,
                      text: tournament.location,
                    ),
                    const SizedBox(height: 8),
                    _DetailLine(
                      icon: Icons.calendar_month_outlined,
                      text: tournament.date
                          .toLocal()
                          .toString()
                          .split(' ')
                          .first,
                    ),
                    const SizedBox(height: 8),
                    _DetailLine(
                      icon: Icons.groups_outlined,
                      text: '$players registered players',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: viewStats,
                        icon: const Icon(Icons.query_stats_outlined),
                        label: const Text('View tournament stats'),
                      ),
                    ),
                    if (currentUser != null) ...[
                      const SizedBox(height: 12),
                      _UmpireApplicationStatus(
                        status: isAssignedUmpire
                            ? 'assigned'
                            : umpireApplicationStatus,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              isApplyingAsUmpire ||
                                  isCreator ||
                                  hasAssignedUmpire ||
                                  isAssignedUmpire ||
                                  umpireApplicationStatus == 'pending' ||
                                  umpireApplicationStatus == 'approved'
                              ? null
                              : applyAsUmpire,
                          icon: isApplyingAsUmpire
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sports_outlined),
                          label: Text(
                            isApplyingAsUmpire
                                ? 'Applying...'
                                : _applyAsUmpireLabel(
                                    currentUser: currentUser,
                                    isCreator: isCreator,
                                    isAssignedUmpire: isAssignedUmpire,
                                    hasAssignedUmpire: hasAssignedUmpire,
                                    status: umpireApplicationStatus,
                                  ),
                          ),
                        ),
                      ),
                      if (isAssignedUmpire) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: viewGames,
                            icon: const Icon(Icons.scoreboard_outlined),
                            label: const Text('View tournament games'),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Register by category',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final category in tournament.categories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RegistrationCategoryTile(
                          categoryName: category.name,
                          skillLevel: category.skillLevel,
                          registered: category.players.length,
                          slots: category.slots,
                          alreadyRegistered:
                              currentUser != null &&
                              category.players.contains(currentUser.id),
                          canRegister: canRegister,
                          unavailableLabel: unavailableLabel,
                          isRegistering: registeringCategory == category.name,
                          onRegister: () => register(category),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<Map<String, dynamic>?> _showRegistrationFormSheet(
    BuildContext context, {
    required CategoryModel category,
    required UserModel currentUser,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return _TournamentRegistrationForm(
          category: category,
          currentUser: currentUser,
        );
      },
    );
  }

  static void _showTournamentStatsSheet(
    BuildContext context,
    List<MatchModel> matches,
  ) {
    final records = <String, Map<String, Map<String, List<int>>>>{};
    for (final match in matches.where((m) => m.status == 'completed')) {
      final category = match.categoryName.isEmpty
          ? 'General'
          : match.categoryName;
      final bracket = match.bracket.isEmpty ? 'Open' : match.bracket;
      final bucket = records
          .putIfAbsent(category, () => <String, Map<String, List<int>>>{})
          .putIfAbsent(bracket, () => <String, List<int>>{});
      for (final player in [match.playerA, match.playerB]) {
        if (player == 'BYE' || player.isEmpty) continue;
        bucket.putIfAbsent(player, () => [0, 0]);
        if (match.winner == player) {
          bucket[player]![0]++;
        } else {
          bucket[player]![1]++;
        }
      }
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tournament stats',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                if (records.isEmpty)
                  const _EmptyState(
                    title: 'No completed games',
                    message: 'Stats update after umpires submit scores.',
                    icon: Icons.query_stats_outlined,
                  )
                else
                  for (final category in records.entries) ...[
                    Text(
                      category.key,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final bracket in category.value.entries) ...[
                      Text(
                        'Bracket ${bracket.key}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      for (final player in bracket.value.entries)
                        _ProfileRow(
                          icon: Icons.person_outline,
                          label:
                              LocalDbService.instance
                                  .getUserById(player.key)
                                  ?.name ??
                              player.key,
                          value: '${player.value[0]}W ${player.value[1]}L',
                        ),
                      const SizedBox(height: 10),
                    ],
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TournamentCoverImage extends StatelessWidget {
  const _TournamentCoverImage({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    if (tournament.imagePath.startsWith('data:image')) {
      return Image.memory(
        base64Decode(tournament.imagePath.split(',').last),
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      TournamentCard._coverUrl(tournament),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFF183A2E),
          child: const Center(
            child: Icon(Icons.sports_tennis, color: Colors.white, size: 44),
          ),
        );
      },
    );
  }
}

class _TournamentRegistrationForm extends StatefulWidget {
  const _TournamentRegistrationForm({
    required this.category,
    required this.currentUser,
  });

  final CategoryModel category;
  final UserModel currentUser;

  @override
  State<_TournamentRegistrationForm> createState() =>
      _TournamentRegistrationFormState();
}

class _TournamentRegistrationFormState
    extends State<_TournamentRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  late final List<_RegistrationPlayerControllers> _players;
  var _showIdImageErrors = false;

  bool get _isDoubles => widget.category.name.toLowerCase().contains('double');

  @override
  void initState() {
    super.initState();
    _players = [
      _RegistrationPlayerControllers(name: widget.currentUser.name),
      if (widget.category.name.toLowerCase().contains('double'))
        _RegistrationPlayerControllers(),
    ];
  }

  @override
  void dispose() {
    for (final player in _players) {
      player.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Required';
    return null;
  }

  String? _ageValidator(String? value) {
    final required = _required(value);
    if (required != null) return required;
    final age = int.tryParse(value!.trim());
    if (age == null || age < 1 || age > 120) return 'Enter a valid age';
    return null;
  }

  Map<String, dynamic> _details() {
    return {
      'type': _isDoubles ? 'doubles' : 'singles',
      'players': [
        for (var i = 0; i < _players.length; i++)
          {
            'slot': i + 1,
            'name': _players[i].name.text.trim(),
            'address': _players[i].address.text.trim(),
            'club': _players[i].club.text.trim(),
            'age': int.tryParse(_players[i].age.text.trim()) ?? 0,
            'idImage': _players[i].idImagePath,
            'contactNumber': _players[i].contactNumber.text.trim(),
          },
      ],
    };
  }

  void _submit() {
    final ok = _formKey.currentState?.validate() ?? false;
    final hasAllIdImages = _players.every(
      (player) => player.idImagePath.isNotEmpty,
    );
    setState(() => _showIdImageErrors = !hasAllIdImages);
    if (!ok || !hasAllIdImages) return;
    Navigator.pop(context, _details());
  }

  Future<void> _pickIdImage(int index) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final extension = picked.name.split('.').last.toLowerCase();
    final mime = extension == 'jpg' || extension == 'jpeg'
        ? 'image/jpeg'
        : 'image/png';
    setState(() {
      _players[index].idImagePath = 'data:$mime;base64,${base64Encode(bytes)}';
      _showIdImageErrors = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Register for ${widget.category.name}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                _isDoubles
                    ? 'Enter details for both doubles players.'
                    : 'Enter your player details.',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _players.length; i++) ...[
                _RegistrationPlayerSection(
                  title: _isDoubles ? 'Player ${i + 1}' : 'Player details',
                  controllers: _players[i],
                  requiredValidator: _required,
                  ageValidator: _ageValidator,
                  showIdImageError:
                      _showIdImageErrors && _players[i].idImagePath.isEmpty,
                  onPickIdImage: () => _pickIdImage(i),
                ),
                const SizedBox(height: 14),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.how_to_reg_outlined),
                  label: const Text('Submit registration'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistrationPlayerControllers {
  _RegistrationPlayerControllers({String name = ''})
    : name = TextEditingController(text: name),
      address = TextEditingController(),
      club = TextEditingController(),
      age = TextEditingController(),
      contactNumber = TextEditingController();

  final TextEditingController name;
  final TextEditingController address;
  final TextEditingController club;
  final TextEditingController age;
  final TextEditingController contactNumber;
  String idImagePath = '';

  void dispose() {
    name.dispose();
    address.dispose();
    club.dispose();
    age.dispose();
    contactNumber.dispose();
  }
}

class _RegistrationPlayerSection extends StatelessWidget {
  const _RegistrationPlayerSection({
    required this.title,
    required this.controllers,
    required this.requiredValidator,
    required this.ageValidator,
    required this.showIdImageError,
    required this.onPickIdImage,
  });

  final String title;
  final _RegistrationPlayerControllers controllers;
  final FormFieldValidator<String> requiredValidator;
  final FormFieldValidator<String> ageValidator;
  final bool showIdImageError;
  final VoidCallback onPickIdImage;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controllers.name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: requiredValidator,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controllers.address,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(Icons.home_outlined),
            ),
            validator: requiredValidator,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controllers.club,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Club (optional)',
              prefixIcon: Icon(Icons.groups_outlined),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controllers.age,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  validator: ageValidator,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IdImagePicker(
                  imagePath: controllers.idImagePath,
                  showError: showIdImageError,
                  onPickImage: onPickIdImage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controllers.contactNumber,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Contact number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: requiredValidator,
          ),
        ],
      ),
    );
  }
}

class _IdImagePicker extends StatelessWidget {
  const _IdImagePicker({
    required this.imagePath,
    required this.showError,
    required this.onPickImage,
  });

  final String imagePath;
  final bool showError;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPickImage,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: showError
                ? const Color(0xFFD32F2F)
                : const Color(0xFFDDE7D9),
            width: showError ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              imagePath.isEmpty ? Icons.badge_outlined : Icons.check_circle,
              color: imagePath.isEmpty
                  ? Colors.black54
                  : const Color(0xFF2E7D32),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                imagePath.isEmpty ? 'ID image' : 'ID attached',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: showError ? const Color(0xFFD32F2F) : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatorTournamentCard extends StatelessWidget {
  const _CreatorTournamentCard({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final registrationClosed = now.isAfter(tournament.registrationEnd);
    final dateText = tournament.date.toLocal().toString().split(' ').first;

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Icons.manage_accounts_outlined,
                color: Color(0xFF7B1FA2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TournamentTitle(
                  title: tournament.name,
                  subtitle:
                      '${tournament.status.toUpperCase()} - $dateText - registration closes ${_shortDate(tournament.registrationEnd)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (registrationClosed)
            const Text(
              'Registration is closed. Create brackets before generating games.',
              style: TextStyle(color: Colors.black54),
            )
          else
            Text(
              'Registration is open until ${_shortDate(tournament.registrationEnd)}.',
              style: const TextStyle(color: Colors.black54),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showManageSheet(context, tournament),
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Manage tournament'),
            ),
          ),
        ],
      ),
    );
  }

  static String _shortDate(DateTime date) =>
      date.toLocal().toString().split(' ').first;

  static Future<void> _showManageSheet(
    BuildContext context,
    TournamentModel tournament,
  ) async {
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    await provider.fetchBrackets(tournament.id);
    await provider.fetchMatchesByTournament(tournament.id);
    await provider.fetchUmpires();
    if (!context.mounted) return;

    final brackets = <String, Map<String, List<String>>>{
      for (final entry in provider.brackets.entries)
        entry.key: {
          for (final bracket in entry.value.entries)
            bracket.key: List<String>.from(bracket.value),
        },
    };
    final playersPerBracket = <String, int>{
      for (final category in tournament.categories) category.name: 4,
    };
    var assignedUmpireId = tournament.umpireId;
    final umpireApplications = Map<String, String>.from(
      tournament.umpireApplications,
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> saveBrackets() async {
              await provider.saveBrackets(
                tournamentId: tournament.id,
                bracketsByCategory: brackets,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Brackets saved.')));
            }

            Future<void> generateGames() async {
              if (brackets.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Create brackets first.')),
                );
                return;
              }
              await provider.generateRoundRobinGames(
                tournamentId: tournament.id,
                bracketsByCategory: brackets,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Round-robin games generated.')),
              );
              Navigator.pop(sheetContext);
            }

            Future<void> scheduleGame() async {
              final scheduled = await _showScheduleGameSheet(
                context,
                tournament: tournament,
                brackets: brackets,
                umpires: provider.umpires,
              );
              if (scheduled == null) return;
              await provider.scheduleMatch(
                tournamentId: tournament.id,
                categoryName: scheduled['categoryName'] as String,
                bracket: scheduled['bracket'] as String,
                playerA: scheduled['playerA'] as String,
                playerB: scheduled['playerB'] as String,
                umpireId: scheduled['umpireId'] as String,
                courtNumber: scheduled['courtNumber'] as String,
              );
              setSheetState(() {});
            }

            Future<void> assignMatch(MatchModel match) async {
              final assignment = await _showAssignMatchSheet(
                context,
                match: match,
                umpires: provider.umpires,
              );
              if (assignment == null) return;
              await provider.updateMatchAssignment(
                tournamentId: tournament.id,
                matchId: match.id,
                umpireId: assignment['umpireId'] as String,
                courtNumber: assignment['courtNumber'] as String,
              );
              setSheetState(() {});
            }

            Future<void> assignTournamentUmpire(String umpireId) async {
              await provider.assignUmpire(
                tournamentId: tournament.id,
                umpireId: umpireId,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Umpire approved and assigned.')),
              );
              setSheetState(() {
                assignedUmpireId = umpireId;
                umpireApplications[umpireId] = 'approved';
              });
            }

            Future<void> rejectTournamentUmpire(String umpireId) async {
              await provider.rejectUmpireApplication(
                tournamentId: tournament.id,
                umpireId: umpireId,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Umpire application rejected.')),
              );
              setSheetState(() => umpireApplications[umpireId] = 'rejected');
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage ${tournament.name}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'After registration closes, create category brackets manually or automatically, then generate round-robin games.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    _UmpireApplicationsPanel(
                      assignedUmpireId: assignedUmpireId,
                      applications: umpireApplications,
                      onAssign: assignTournamentUmpire,
                      onReject: rejectTournamentUmpire,
                    ),
                    const SizedBox(height: 16),
                    for (final category in tournament.categories) ...[
                      _BracketCategoryManager(
                        category: category,
                        brackets: brackets[category.name] ?? const {},
                        playersPerBracket:
                            playersPerBracket[category.name] ?? 4,
                        onPlayersPerBracketChanged: (value) {
                          setSheetState(
                            () => playersPerBracket[category.name] = value,
                          );
                        },
                        onAutoCreate: () {
                          setSheetState(() {
                            brackets[category.name] = _autoBrackets(
                              category.players,
                              playersPerBracket[category.name] ?? 4,
                            );
                          });
                        },
                        onManualCreate: () async {
                          final manual = await _showManualBracketSheet(
                            context,
                            category,
                            brackets[category.name] ?? const {},
                          );
                          if (manual == null) return;
                          setSheetState(() => brackets[category.name] = manual);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: saveBrackets,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save brackets'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: generateGames,
                            icon: const Icon(Icons.playlist_add_check),
                            label: const Text('Generate games'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: scheduleGame,
                        icon: const Icon(Icons.add_task_outlined),
                        label: const Text('Schedule next game'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionTitle(
                      title: 'Tournament Games',
                      count: provider.matches.length,
                    ),
                    const SizedBox(height: 8),
                    if (provider.matches.isEmpty)
                      const _EmptyState(
                        title: 'No games yet',
                        message: 'Generate games or schedule the next game.',
                        icon: Icons.scoreboard_outlined,
                      )
                    else
                      for (final match in provider.matches) ...[
                        _MatchCard(
                          match: match,
                          trailing: TextButton.icon(
                            onPressed: () => assignMatch(match),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Assign'),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Map<String, List<String>> _autoBrackets(
    List<String> players,
    int playersPerBracket,
  ) {
    final size = playersPerBracket.clamp(2, 99);
    final result = <String, List<String>>{};
    for (var i = 0; i < players.length; i++) {
      final bracketIndex = i ~/ size;
      final name = String.fromCharCode(65 + bracketIndex);
      result.putIfAbsent(name, () => <String>[]).add(players[i]);
    }
    return result;
  }

  static Future<Map<String, List<String>>?> _showManualBracketSheet(
    BuildContext context,
    CategoryModel category,
    Map<String, List<String>> current,
  ) {
    final bracketController = TextEditingController(text: 'A');
    final selected = <String>{};
    final manual = <String, List<String>>{
      for (final entry in current.entries)
        entry.key: List<String>.from(entry.value),
    };

    return showModalBottomSheet<Map<String, List<String>>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void addSelected() {
              final bracket = bracketController.text.trim().toUpperCase();
              if (bracket.isEmpty || selected.isEmpty) return;
              manual.putIfAbsent(bracket, () => <String>[]);
              for (final player in selected) {
                for (final players in manual.values) {
                  players.remove(player);
                }
                manual[bracket]!.add(player);
              }
              setSheetState(selected.clear);
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual brackets - ${category.name}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bracketController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Bracket name',
                        prefixIcon: Icon(Icons.account_tree_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final player in category.players)
                      CheckboxListTile(
                        value: selected.contains(player),
                        onChanged: (value) {
                          setSheetState(() {
                            if (value ?? false) {
                              selected.add(player);
                            } else {
                              selected.remove(player);
                            }
                          });
                        },
                        title: Text(_playerName(player)),
                        subtitle: Text(_assignedBracket(manual, player)),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: addSelected,
                            icon: const Icon(Icons.add),
                            label: const Text('Add selected'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(context, manual),
                            icon: const Icon(Icons.check),
                            label: const Text('Done'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _assignedBracket(
    Map<String, List<String>> manual,
    String player,
  ) {
    for (final entry in manual.entries) {
      if (entry.value.contains(player)) return 'Bracket ${entry.key}';
    }
    return 'Unassigned';
  }

  static String _playerName(String playerId) {
    return LocalDbService.instance.getUserById(playerId)?.name ?? playerId;
  }

  static Future<Map<String, String>?> _showScheduleGameSheet(
    BuildContext context, {
    required TournamentModel tournament,
    required Map<String, Map<String, List<String>>> brackets,
    required List<UserModel> umpires,
  }) {
    final categories = brackets.keys.toList();
    var categoryName = categories.isNotEmpty ? categories.first : '';
    var bracketName =
        categoryName.isNotEmpty && brackets[categoryName]!.isNotEmpty
        ? brackets[categoryName]!.keys.first
        : '';
    var players = categoryName.isNotEmpty && bracketName.isNotEmpty
        ? brackets[categoryName]![bracketName] ?? <String>[]
        : <String>[];
    var playerA = players.isNotEmpty ? players.first : '';
    var playerB = players.length > 1 ? players[1] : '';
    var umpireId = umpires.isNotEmpty ? umpires.first.id : '';
    final courtController = TextEditingController(text: '1');

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updatePlayers() {
              players = categoryName.isNotEmpty && bracketName.isNotEmpty
                  ? brackets[categoryName]![bracketName] ?? <String>[]
                  : <String>[];
              playerA = players.isNotEmpty ? players.first : '';
              playerB = players.length > 1 ? players[1] : '';
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule next game',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: categoryName.isEmpty ? null : categoryName,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          categoryName = value;
                          bracketName = brackets[value]!.isNotEmpty
                              ? brackets[value]!.keys.first
                              : '';
                          updatePlayers();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: bracketName.isEmpty ? null : bracketName,
                      decoration: const InputDecoration(labelText: 'Bracket'),
                      items: (brackets[categoryName]?.keys ?? const <String>[])
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          bracketName = value;
                          updatePlayers();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: playerA.isEmpty ? null : playerA,
                            decoration: const InputDecoration(
                              labelText: 'Player A',
                            ),
                            items: players
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(_playerName(p)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setSheetState(() => playerA = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: playerB.isEmpty ? null : playerB,
                            decoration: const InputDecoration(
                              labelText: 'Player B',
                            ),
                            items: players
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(_playerName(p)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setSheetState(() => playerB = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: umpireId.isEmpty ? null : umpireId,
                      decoration: const InputDecoration(labelText: 'Umpire'),
                      items: umpires
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(u.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => umpireId = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: courtController,
                      decoration: const InputDecoration(
                        labelText: 'Court number',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            playerA.isEmpty ||
                                playerB.isEmpty ||
                                playerA == playerB
                            ? null
                            : () => Navigator.pop(context, {
                                'categoryName': categoryName,
                                'bracket': bracketName,
                                'playerA': playerA,
                                'playerB': playerB,
                                'umpireId': umpireId,
                                'courtNumber': courtController.text.trim(),
                              }),
                        icon: const Icon(Icons.add_task_outlined),
                        label: const Text('Schedule game'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<Map<String, String>?> _showAssignMatchSheet(
    BuildContext context, {
    required MatchModel match,
    required List<UserModel> umpires,
  }) {
    var umpireId = match.umpireId.isNotEmpty
        ? match.umpireId
        : (umpires.isNotEmpty ? umpires.first.id : '');
    final courtController = TextEditingController(text: match.courtNumber);

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign game',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: umpireId.isEmpty ? null : umpireId,
                      decoration: const InputDecoration(labelText: 'Umpire'),
                      items: umpires
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(u.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => umpireId = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: courtController,
                      decoration: const InputDecoration(
                        labelText: 'Court number',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, {
                          'umpireId': umpireId,
                          'courtNumber': courtController.text.trim(),
                        }),
                        icon: const Icon(Icons.check),
                        label: const Text('Save assignment'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _UmpireApplicationsPanel extends StatelessWidget {
  const _UmpireApplicationsPanel({
    required this.assignedUmpireId,
    required this.applications,
    required this.onAssign,
    required this.onReject,
  });

  final String assignedUmpireId;
  final Map<String, String> applications;
  final Future<void> Function(String umpireId) onAssign;
  final Future<void> Function(String umpireId) onReject;

  @override
  Widget build(BuildContext context) {
    final entries = applications.entries.toList()
      ..sort((a, b) => _umpireName(a.key).compareTo(_umpireName(b.key)));

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Umpire Applications', count: entries.length),
          const SizedBox(height: 8),
          if (assignedUmpireId.isNotEmpty)
            _InfoChip(
              icon: Icons.verified_outlined,
              text: 'Assigned: ${_umpireName(assignedUmpireId)}',
            ),
          if (assignedUmpireId.isNotEmpty) const SizedBox(height: 8),
          if (entries.isEmpty)
            const Text(
              'No umpire applications yet.',
              style: TextStyle(color: Colors.black54),
            )
          else
            for (final entry in entries) ...[
              _UmpireApplicationTile(
                umpireId: entry.key,
                status: assignedUmpireId == entry.key
                    ? 'assigned'
                    : entry.value,
                onAssign: () => onAssign(entry.key),
                onReject: () => onReject(entry.key),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  static String _umpireName(String umpireId) {
    return LocalDbService.instance.getUserById(umpireId)?.name ?? umpireId;
  }
}

class _UmpireApplicationTile extends StatelessWidget {
  const _UmpireApplicationTile({
    required this.umpireId,
    required this.status,
    required this.onAssign,
    required this.onReject,
  });

  final String umpireId;
  final String status;
  final Future<void> Function() onAssign;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';
    final isAssigned = status == 'assigned' || status == 'approved';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7D9)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Icons.sports_outlined,
                color: Color(0xFF1565C0),
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactTournamentTitle(
                  title:
                      LocalDbService.instance.getUserById(umpireId)?.name ??
                      umpireId,
                  subtitle: status.toUpperCase(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isRejected ? null : onReject,
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isAssigned ? null : onAssign,
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UmpireApplicationStatus extends StatelessWidget {
  const _UmpireApplicationStatus({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      'assigned' => 'You are assigned to this tournament.',
      'approved' => 'Your umpire application is approved.',
      'pending' => 'Your umpire application is pending creator approval.',
      'rejected' => 'Your umpire application was rejected.',
      _ => 'You have not applied as an umpire.',
    };

    return _InfoChip(icon: Icons.info_outline, text: text);
  }
}

void _showTournamentGamesSheet(
  BuildContext context,
  TournamentProvider provider, {
  required String currentUmpireId,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tournament Games',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (provider.matches.isEmpty)
                const _EmptyState(
                  title: 'No games yet',
                  message:
                      'Games will appear after the creator generates them.',
                  icon: Icons.scoreboard_outlined,
                )
              else
                for (final match in provider.matches) ...[
                  _MatchCard(
                    match: match,
                    canScore: match.umpireId == currentUmpireId,
                    onScore: () =>
                        _showScoreSheetForMatch(sheetContext, provider, match),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _showScoreSheetForMatch(
  BuildContext context,
  TournamentProvider provider,
  MatchModel match,
) async {
  final scoreAController = TextEditingController(
    text: match.scoreA == 0 ? '' : match.scoreA.toString(),
  );
  final scoreBController = TextEditingController(
    text: match.scoreB == 0 ? '' : match.scoreB.toString(),
  );
  final result = await showModalBottomSheet<Map<String, int>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Score game',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: scoreAController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _playerDisplayName(match.playerA),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: scoreBController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _playerDisplayName(match.playerB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final scoreA =
                        int.tryParse(scoreAController.text.trim()) ?? -1;
                    final scoreB =
                        int.tryParse(scoreBController.text.trim()) ?? -1;
                    if (scoreA < 0 || scoreB < 0 || scoreA == scoreB) return;
                    Navigator.pop(context, {'a': scoreA, 'b': scoreB});
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save score'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (result == null) return;
  await provider.updateScore(
    tournamentId: match.tournamentId,
    matchId: match.id,
    scoreA: result['a']!,
    scoreB: result['b']!,
    playerAId: match.playerA,
    playerBId: match.playerB,
  );
}

String _playerDisplayName(String playerId) {
  return LocalDbService.instance.getUserById(playerId)?.name ?? playerId;
}

class _BracketCategoryManager extends StatelessWidget {
  const _BracketCategoryManager({
    required this.category,
    required this.brackets,
    required this.playersPerBracket,
    required this.onPlayersPerBracketChanged,
    required this.onAutoCreate,
    required this.onManualCreate,
  });

  final CategoryModel category;
  final Map<String, List<String>> brackets;
  final int playersPerBracket;
  final ValueChanged<int> onPlayersPerBracketChanged;
  final VoidCallback onAutoCreate;
  final VoidCallback onManualCreate;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${category.players.length} registered players',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Players per bracket'),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  min: 2,
                  max: 12,
                  divisions: 10,
                  value: playersPerBracket.clamp(2, 12).toDouble(),
                  label: playersPerBracket.toString(),
                  onChanged: (value) =>
                      onPlayersPerBracketChanged(value.round()),
                ),
              ),
              Text(playersPerBracket.toString()),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: category.players.length < 2
                      ? null
                      : onManualCreate,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Manual'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: category.players.length < 2 ? null : onAutoCreate,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Auto'),
                ),
              ),
            ],
          ),
          if (brackets.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final entry in brackets.entries)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoChip(
                      icon: Icons.account_tree_outlined,
                      text:
                          'Bracket ${entry.key}: ${entry.value.length} players',
                    ),
                    if (entry.value.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.value
                            .map(
                              (playerId) =>
                                  LocalDbService.instance
                                      .getUserById(playerId)
                                      ?.name ??
                                  playerId,
                            )
                            .join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RegistrationCategoryTile extends StatelessWidget {
  const _RegistrationCategoryTile({
    required this.categoryName,
    required this.skillLevel,
    required this.registered,
    required this.slots,
    required this.alreadyRegistered,
    required this.canRegister,
    required this.unavailableLabel,
    required this.isRegistering,
    required this.onRegister,
  });

  final String categoryName;
  final String skillLevel;
  final int registered;
  final int slots;
  final bool alreadyRegistered;
  final bool canRegister;
  final String unavailableLabel;
  final bool isRegistering;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final isFull = registered >= slots;
    final disabled =
        !canRegister || alreadyRegistered || isFull || isRegistering;
    final label = alreadyRegistered
        ? 'Registered'
        : isFull
        ? 'Full'
        : canRegister
        ? 'Register'
        : unavailableLabel;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7D9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$skillLevel - $registered/$slots slots filled',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: disabled ? null : onRegister,
              icon: isRegistering
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.how_to_reg_outlined),
              label: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    this.canScore = false,
    this.onScore,
    this.trailing,
  });

  final MatchModel match;
  final bool canScore;
  final VoidCallback? onScore;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final playerA =
        LocalDbService.instance.getUserById(match.playerA)?.name ??
        match.playerA;
    final playerB =
        LocalDbService.instance.getUserById(match.playerB)?.name ??
        match.playerB;
    final umpire = match.umpireId.isEmpty
        ? 'No umpire'
        : LocalDbService.instance.getUserById(match.umpireId)?.name ??
              match.umpireId;
    final court = match.courtNumber.isEmpty
        ? 'No court'
        : 'Court ${match.courtNumber}';

    return _Surface(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Icons.scoreboard_outlined,
                color: Color(0xFF1565C0),
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactTournamentTitle(
                  title: '$playerA vs $playerB',
                  subtitle:
                      '${match.categoryName} - Bracket ${match.bracket} - $court - $umpire',
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.numbers_outlined,
                text: match.status == 'completed'
                    ? '${match.scoreA}-${match.scoreB}'
                    : 'Scheduled',
              ),
              _InfoChip(
                icon: Icons.check_circle_outline,
                text: match.winner.isEmpty
                    ? 'No winner'
                    : 'Winner: ${LocalDbService.instance.getUserById(match.winner)?.name ?? match.winner}',
              ),
            ],
          ),
          if (canScore && match.status != 'completed') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onScore,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Score game'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PendingTournamentCard extends StatelessWidget {
  const PendingTournamentCard({super.key, required this.tournament});

  final TournamentModel tournament;

  Future<void> _handleAction(
    BuildContext context,
    Future<void> Function() action,
    String message,
  ) async {
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final dateText = tournament.date.toLocal().toString().split(' ').first;

    return _Surface(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Icons.hourglass_top_rounded,
                color: Color(0xFF1565C0),
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactTournamentTitle(
                  title: tournament.name,
                  subtitle: '${tournament.location} - $dateText',
                ),
              ),
              const SizedBox(width: 8),
              const _AdminStatusLabel(
                text: 'Under approval',
                color: Color(0xFF1565C0),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () =>
                  TournamentCard._showTournamentDetails(context, tournament),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View details'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => _handleAction(
                    context,
                    () =>
                        provider.rejectTournament(tournamentId: tournament.id),
                    'Tournament rejected.',
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => _handleAction(
                    context,
                    () =>
                        provider.approveTournament(tournamentId: tournament.id),
                    'Tournament approved.',
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminApprovedTournamentCard extends StatelessWidget {
  const _AdminApprovedTournamentCard({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final dateText = tournament.date.toLocal().toString().split(' ').first;
    final players = tournament.categories.fold<int>(
      0,
      (sum, category) => sum + category.players.length,
    );
    final slots = tournament.categories.fold<int>(
      0,
      (sum, category) => sum + category.slots,
    );

    return InkWell(
      onTap: () => TournamentCard._showTournamentDetails(context, tournament),
      borderRadius: BorderRadius.circular(8),
      child: _Surface(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const _IconBadge(
              icon: Icons.verified_outlined,
              color: Color(0xFF2E7D32),
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CompactTournamentTitle(
                title: tournament.name,
                subtitle:
                    '${tournament.location} - $dateText - ${tournament.categories.length} categories - $players/$slots players',
              ),
            ),
            const SizedBox(width: 8),
            const _AdminStatusLabel(text: 'Approved', color: Color(0xFF2E7D32)),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF183A2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.name,
    required this.role,
    required this.isAdmin,
  });

  final String name;
  final String role;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return _HeroPanel(
      title: name,
      message: '${role.toUpperCase()} workspace',
      icon: isAdmin ? Icons.admin_panel_settings_outlined : Icons.person,
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: _Surface(
        child: Row(
          children: [
            _IconBadge(icon: icon, color: const Color(0xFF2E7D32)),
            const SizedBox(width: 12),
            Expanded(
              child: _TournamentTitle(title: title, subtitle: message),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _TournamentTitle extends StatelessWidget {
  const _TournamentTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.black54, height: 1.25),
        ),
      ],
    );
  }
}

class _CompactTournamentTitle extends StatelessWidget {
  const _CompactTournamentTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7D9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.black54),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF2E7D32),
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _AdminStatusLabel extends StatelessWidget {
  const _AdminStatusLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color, this.size = 46});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: size <= 38 ? 20 : 24),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDE7D9)),
        ),
        child: child,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Icon(icon, size: 42, color: Colors.black38),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedIn extends StatelessWidget {
  const _AnimatedIn({required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final delayed = delay == 0 ? value : (value * 1.18 - 0.18).clamp(0, 1);
        return Opacity(
          opacity: delayed.toDouble(),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - delayed.toDouble())),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
