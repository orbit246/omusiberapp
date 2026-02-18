import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omusiber/backend/view/community_post_model.dart';
import 'package:omusiber/backend/community_repository.dart';

class PollWidget extends StatefulWidget {
  final String postId;
  final PollModel poll;

  const PollWidget({super.key, required this.postId, required this.poll});

  @override
  State<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends State<PollWidget> {
  late PollModel _poll;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _poll = widget.poll;
  }

  Future<void> _handleVote(String optionId) async {
    final isClosed = _poll.isClosed || DateTime.now().isAfter(_poll.closesAt);
    if (isClosed) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Bu oylama kapanmistir.")));
      }
      return;
    }

    setState(() => _isVoting = true);
    try {
      // Simulate repo call
      final updatedPoll = await CommunityRepository().votePoll(
        widget.postId,
        optionId,
      );
      if (mounted) {
        setState(() {
          _poll = updatedPoll;
          _isVoting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVoting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Oylama hatası: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVoted = _poll.userVotedOptionId != null;
    final isExpired = _poll.isClosed || DateTime.now().isAfter(_poll.closesAt);
    final totalVotes = _poll.totalVotes;
    final showResults = hasVoted || isExpired;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          Text(
            _poll.question,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),

          // Options
          ..._poll.options.map((option) {
            final isSelected = _poll.userVotedOptionId == option.id;
            final percentage = totalVotes > 0 ? option.votes / totalVotes : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: showResults
                  ? _buildResultBar(option, percentage, isSelected)
                  : _buildVoteButton(option),
            );
          }),

          // Footer
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              _buildFooterText(totalVotes, isExpired, hasVoted),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildFooterText(int totalVotes, bool isExpired, bool hasVoted) {
    if (isExpired) return "$totalVotes oy • Süre doldu";
    if (hasVoted) return "$totalVotes oy • Oylandı";

    final diff = _poll.closesAt.difference(DateTime.now());
    if (diff.inDays > 0) return "${diff.inDays} gün kaldı";
    if (diff.inHours > 0) return "${diff.inHours} saat kaldı";
    if (diff.inMinutes > 0) return "${diff.inMinutes} dakika kaldı";
    return "Süre dolmak üzere";
  }

  Widget _buildVoteButton(PollOption option) {
    return InkWell(
      onTap: _isVoting ? null : () => _handleVote(option.id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.text,
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultBar(
    PollOption option,
    double percentage,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final percentageInt = (percentage * 100).toInt();

    return Stack(
      children: [
        // Background Bar (Progress)
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              height: 40,
              width: constraints.maxWidth * percentage,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            );
          },
        ),
        // Content
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    Icons.check_circle,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              Expanded(
                child: Text(
                  "${option.text} (${option.votes})",
                  style: GoogleFonts.inter(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                "$percentageInt%",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
