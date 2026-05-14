import 'package:flutter/material.dart';
import 'common_ui.dart';

class UmpireApplicationsPanel extends StatelessWidget {
  const UmpireApplicationsPanel({
    super.key,
    required this.assignedUmpireId,
    required this.applications,
    required this.onAssign,
    required this.onReject,
    required this.userCache,
  });

  final String assignedUmpireId;
  final Map<String, String> applications;
  final Future<void> Function(String umpireId) onAssign;
  final Future<void> Function(String umpireId) onReject;
  final Map<String, String> userCache;

  String _umpireName(String umpireId) => userCache[umpireId] ?? umpireId;

  @override
  Widget build(BuildContext context) {
    final entries = applications.entries.toList()
      ..sort((a, b) => _umpireName(a.key).compareTo(_umpireName(b.key)));

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: 'Umpire Applications', count: entries.length),
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
              UmpireApplicationTile(
                umpireId: entry.key,
                status: assignedUmpireId == entry.key ? 'assigned' : entry.value,
                onAssign: () => onAssign(entry.key),
                onReject: () => onReject(entry.key),
                umpireName: _umpireName(entry.key),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class UmpireApplicationTile extends StatelessWidget {
  const UmpireApplicationTile({
    super.key,
    required this.umpireId,
    required this.status,
    required this.onAssign,
    required this.onReject,
    required this.umpireName,
  });

  final String umpireId;
  final String status;
  final Future<void> Function() onAssign;
  final Future<void> Function() onReject;
  final String umpireName;

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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sports_outlined, color: Color(0xFF1565C0), size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CompactTournamentTitle(
                  title: umpireName,
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

class UmpireApplicationStatus extends StatelessWidget {
  const UmpireApplicationStatus({super.key, required this.status});
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.blueGrey))),
        ],
      ),
    );
  }
}