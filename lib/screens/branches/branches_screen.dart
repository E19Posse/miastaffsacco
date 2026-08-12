import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_state_views.dart';
import 'package:unicons/unicons.dart';

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});
  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  final _api = ApiService();
  List<dynamic> _branches = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getBranches();
      if (mounted) setState(() { _branches = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = ApiService.extractError(e); _loading = false; });
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
            Expanded(child: Text('Our Branches', style: GoogleFonts.sora(
                fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary))),
          ]),
        ),
        Expanded(child: _loading
          ? const LoadingStateView()
          : _error != null
              ? ErrorStateView(message: _error, onRetry: _load)
              : RefreshIndicator(
                  color: AppColors.emeraldDeep,
                  onRefresh: _load,
                  child: _branches.isEmpty
                      ? _emptyState(c)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemCount: _branches.length,
                          itemBuilder: (_, i) =>
                              _BranchCard(branch: _branches[i] as Map<String, dynamic>),
                        ),
                ),
        ),
      ])),
    );
  }

  Widget _emptyState(AppColorScheme c) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(UniconsLine.map_marker_slash, size: 64, color: c.textHint),
      const SizedBox(height: 12),
      Text('No branches configured',
          style: TextStyle(color: c.textSecondary, fontSize: 15)),
    ]),
  );
}

class _BranchCard extends StatelessWidget {
  final Map<String, dynamic> branch;
  const _BranchCard({required this.branch});

  Future<void> _launchTel(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final c       = context.colors;
    final name    = branch['name'] as String? ?? '—';
    final address = branch['address'] as String? ?? '';
    final phone   = branch['phone'] as String? ?? '';
    final email   = branch['email'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.emeraldDeep,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(UniconsLine.map_marker, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),

        if (address.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(UniconsLine.map_marker, color: c.textHint, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(address,
                  style: TextStyle(color: c.textSecondary, fontSize: 13)),
            ),
          ]),
        ],

        if (phone.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _launchTel(phone),
            child: Row(children: [
              Icon(UniconsLine.phone, color: AppColors.emeraldDeep, size: 16),
              const SizedBox(width: 6),
              Text(phone,
                  style: const TextStyle(
                      color: AppColors.emeraldDeep,
                      fontSize: 13, fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline)),
            ]),
          ),
        ],

        if (email.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _launchEmail(email),
            child: Row(children: [
              Icon(UniconsLine.envelope, color: AppColors.gold, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(email,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 13, fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

