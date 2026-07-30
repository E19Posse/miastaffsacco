import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:unicons/unicons.dart';
import '../../widgets/app_svg_icon.dart';

class GovernanceScreen extends StatefulWidget {
  const GovernanceScreen({super.key});
  @override
  State<GovernanceScreen> createState() => _GovernanceScreenState();
}

class _GovernanceScreenState extends State<GovernanceScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabs;

  bool          _loading = true;
  String?       _error;
  List<dynamic> _proposals  = [];
  List<dynamic> _meetings   = [];
  List<dynamic> _board      = [];
  String?       _votingId; // proposal ID currently being voted on

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getGovernance();
      setState(() {
        _proposals = data['proposals'] as List<dynamic>? ?? [];
        _meetings  = data['meetings']  as List<dynamic>? ?? [];
        _board     = data['board']     as List<dynamic>? ?? [];
        _loading   = false;
      });
    } catch (e) {
      setState(() { _error = ApiService.extractError(e); _loading = false; });
    }
  }

  Future<void> _vote(int proposalId, String vote) async {
    setState(() => _votingId = '$proposalId');
    try {
      await _api.castVote(proposalId, vote);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiService.extractError(e)),
          backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _votingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: c.card, shape: BoxShape.circle,
                  border: Border.all(color: c.border),
                ),
                child: Icon(UniconsLine.angle_left, color: c.textPrimary, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Governance', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
            IconButton(icon: const Icon(UniconsLine.sync, color: AppColors.emeraldDeep), onPressed: _load),
          ]),
        ),
        TabBar(
          controller: _tabs,
          labelColor: AppColors.emeraldDeep,
          unselectedLabelColor: c.textSecondary,
          indicatorColor: AppColors.emeraldDeep,
          tabs: const [
            Tab(text: 'Proposals'),
            Tab(text: 'Meetings'),
            Tab(text: 'Board'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldDeep))
              : _error != null
                  ? _ErrorState(error: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _ProposalsTab(
                          proposals: _proposals,
                          votingId: _votingId,
                          onVote: _vote,
                        ),
                        _MeetingsTab(meetings: _meetings),
                        _BoardTab(board: _board),
                      ],
                    ),
        ),
      ])),
    );
  }
}

// ── Proposals Tab ─────────────────────────────────────────────────────────────

class _ProposalsTab extends StatelessWidget {
  final List<dynamic> proposals;
  final String?       votingId;
  final Future<void> Function(int, String) onVote;
  const _ProposalsTab({
    required this.proposals,
    required this.votingId,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    if (proposals.isEmpty) {
      return _EmptyTab(icon: Icons.how_to_vote_outlined, iconSvg: AppSvgIcons.vote, text: 'No proposals available');
    }
    return RefreshIndicator(
      onRefresh: () async {},
      color: AppColors.emeraldDeep,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: proposals.length,
        itemBuilder: (_, i) => _ProposalCard(
          proposal: proposals[i],
          hasVoted: proposals[i]['has_voted'] as bool? ?? false,
          isVoting: votingId == '${proposals[i]['id']}',
          onVote:   onVote,
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final dynamic  proposal;
  final bool     hasVoted;
  final bool     isVoting;
  final Future<void> Function(int, String) onVote;
  const _ProposalCard({
    required this.proposal,
    required this.hasVoted,
    required this.isVoting,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final status  = proposal['status'] as String? ?? '';
    final isOpen  = status == 'Open';

    final forVotes      = int.tryParse('${proposal['votes_for']     ?? 0}') ?? 0;
    final againstVotes  = int.tryParse('${proposal['votes_against'] ?? 0}') ?? 0;
    final abstainVotes  = int.tryParse('${proposal['votes_abstain'] ?? 0}') ?? 0;
    final totalVotes    = forVotes + againstVotes + abstainVotes;

    Color statusColor;
    switch (status) {
      case 'Passed':   statusColor = AppColors.emeraldMid; break;
      case 'Rejected': statusColor = AppColors.danger;   break;
      case 'Closed':   statusColor = c.textSecondary;   break;
      default:         statusColor = AppColors.emeraldDeep;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(proposal['title'] as String? ?? '',
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        if (proposal['description'] != null) ...[
          const SizedBox(height: 8),
          Text(proposal['description'] as String,
              style: TextStyle(color: c.textSecondary, fontSize: 12),
              maxLines: 3, overflow: TextOverflow.ellipsis),
        ],

        const SizedBox(height: 14),
        // Vote bar
        if (totalVotes > 0) ...[
          _VoteBar(
            forV:     forVotes,
            against:  againstVotes,
            abstain:  abstainVotes,
            total:    totalVotes,
            c:        c,
          ),
          const SizedBox(height: 12),
        ],

        // Voting buttons or result
        if (isOpen && !hasVoted) ...[
          if (isVoting)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(color: AppColors.emeraldDeep, strokeWidth: 2),
            ))
          else
            Row(children: [
              _VoteBtn(label: 'For',     color: AppColors.emeraldMid, onTap: () => onVote(int.parse('${proposal['id']}'), 'For')),
              const SizedBox(width: 8),
              _VoteBtn(label: 'Against', color: AppColors.danger,   onTap: () => onVote(int.parse('${proposal['id']}'), 'Against')),
              const SizedBox(width: 8),
              _VoteBtn(label: 'Abstain', color: c.textSecondary,   onTap: () => onVote(int.parse('${proposal['id']}'), 'Abstain')),
            ]),
        ] else if (isOpen && hasVoted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.emeraldMid,
              borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(UniconsLine.check_circle, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text('Vote recorded', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),

        if (proposal['resolution'] != null) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: c.border),
          const SizedBox(height: 10),
          Text('Resolution', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(proposal['resolution'] as String,
              style: TextStyle(color: c.textPrimary, fontSize: 12)),
        ],
      ]),
    );
  }
}

class _VoteBar extends StatelessWidget {
  final int forV, against, abstain, total;
  final AppColorScheme c;
  const _VoteBar({required this.forV, required this.against, required this.abstain,
      required this.total, required this.c});

  @override
  Widget build(BuildContext context) {
    final forPct     = forV     / total;
    final againstPct = against  / total;
    final abstainPct = abstain  / total;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(children: [
          if (forPct > 0)     Expanded(flex: (forPct * 100).round(),
              child: Container(height: 8, color: AppColors.emeraldMid)),
          if (againstPct > 0) Expanded(flex: (againstPct * 100).round(),
              child: Container(height: 8, color: AppColors.danger)),
          if (abstainPct > 0) Expanded(flex: (abstainPct * 100).round(),
              child: Container(height: 8, color: c.textHint)),
        ]),
      ),
      const SizedBox(height: 6),
      Row(children: [
        _VoteCount(color: AppColors.emeraldMid, label: 'For', count: forV),
        const SizedBox(width: 12),
        _VoteCount(color: AppColors.danger, label: 'Against', count: against),
        const SizedBox(width: 12),
        _VoteCount(color: c.textHint, label: 'Abstain', count: abstain),
      ]),
    ]);
  }
}

class _VoteCount extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _VoteCount({required this.color, required this.label, required this.count});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text('$label: $count',
        style: TextStyle(color: context.colors.textSecondary, fontSize: 11)),
  ]);
}

class _VoteBtn extends StatelessWidget {
  final String label;
  final Color  color;
  final VoidCallback onTap;
  const _VoteBtn({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
      ),
    ));
  }
}

// ── Meetings Tab ──────────────────────────────────────────────────────────────

class _MeetingsTab extends StatelessWidget {
  final List<dynamic> meetings;
  const _MeetingsTab({required this.meetings});

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty) {
      return _EmptyTab(icon: UniconsLine.calendar_alt, text: 'No meetings scheduled');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meetings.length,
      itemBuilder: (_, i) => _MeetingCard(meeting: meetings[i]),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final dynamic meeting;
  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final fmt     = DateFormat('dd MMM yyyy');
    DateTime? meetDate;
    try {
      final raw = meeting['meeting_date'] as String?;
      if (raw != null) meetDate = DateTime.tryParse(raw);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(UniconsLine.calendar_alt, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(meeting['title'] as String? ?? '',
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            if (meetDate != null)
              Text(fmt.format(meetDate),
                  style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ])),
        ]),
        if (meeting['agenda'] != null) ...[
          const SizedBox(height: 12),
          Text('Agenda', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(meeting['agenda'] as String,
              style: TextStyle(color: c.textPrimary, fontSize: 12)),
        ],
        if (meeting['resolution'] != null) ...[
          const SizedBox(height: 10),
          Divider(height: 1, color: c.border),
          const SizedBox(height: 10),
          Text('Resolutions', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(meeting['resolution'] as String,
              style: TextStyle(color: c.textPrimary, fontSize: 12)),
        ],
      ]),
    );
  }
}

// ── Board Tab ─────────────────────────────────────────────────────────────────

class _BoardTab extends StatelessWidget {
  final List<dynamic> board;
  const _BoardTab({required this.board});

  @override
  Widget build(BuildContext context) {
    if (board.isEmpty) {
      return _EmptyTab(icon: UniconsLine.users_alt, text: 'No board members found');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: board.length,
      itemBuilder: (_, i) => _BoardCard(member: board[i]),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final dynamic member;
  const _BoardCard({required this.member});

  String _initials(String? name) {
    if (name == null || name.isEmpty) return 'BM';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final name   = member['member_name'] as String? ?? member['name'] as String? ?? 'Board Member';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: AppColors.emeraldMid,
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(_initials(name),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          Text(member['role'] as String? ?? '',
              style: TextStyle(color: AppColors.emeraldDeep, fontSize: 12, fontWeight: FontWeight.w600)),
          if (member['committee'] != null)
            Text(member['committee'] as String,
                style: TextStyle(color: c.textSecondary, fontSize: 11)),
        ])),
        if (member['term_end'] != null)
          Text('Until ${member['term_end']}',
              style: TextStyle(color: c.textHint, fontSize: 10)),
      ]),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String?  iconSvg;
  final String   text;
  const _EmptyTab({required this.icon, this.iconSvg, required this.text});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      iconSvg != null
          ? AppSvgIcon(iconSvg!, size: 64, color: c.textHint)
          : Icon(icon, size: 64, color: c.textHint),
      const SizedBox(height: 12),
      Text(text, style: TextStyle(color: c.textSecondary, fontSize: 14)),
    ]));
  }
}

class _ErrorState extends StatelessWidget {
  final String       error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(UniconsLine.exclamation_circle, size: 56, color: AppColors.danger),
      const SizedBox(height: 12),
      Text(error, textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary)),
      const SizedBox(height: 16),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
  ));
}
