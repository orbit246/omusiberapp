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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PollHeader(question: _poll.question),
          const SizedBox(height: 14),
          ..._poll.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = _poll.userVotedOptionId == option.id;
            final percentage = totalVotes > 0 ? option.votes / totalVotes : 0.0;
            final optionColor = _optionColor(index);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: showResults
                  ? _buildResultBar(option, percentage, isSelected, optionColor)
                  : _buildVoteButton(option, optionColor),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _buildFooterText(totalVotes, isExpired, hasVoted),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
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

  Widget _buildVoteButton(PollOption option, Color optionColor) {
    return InkWell(
      onTap: _isVoting ? null : () => _handleVote(option.id),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        constraints: const BoxConstraints(minHeight: 50),
        decoration: BoxDecoration(
          color: optionColor.withValues(alpha: 0.14),
          border: Border.all(color: optionColor.withValues(alpha: 0.58)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: optionColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _SelectionDot(color: optionColor, isSelected: false),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                option.text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
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
    Color optionColor,
  ) {
    final percentageInt = (percentage * 100).toInt();

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: percentage.clamp(0, 1),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            optionColor.withValues(alpha: 0.5),
                            optionColor.withValues(alpha: 0.22),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: optionColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? optionColor.withValues(alpha: 0.9)
                        : optionColor.withValues(alpha: 0.5),
                    width: isSelected ? 1.8 : 1.1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _SelectionDot(color: optionColor, isSelected: isSelected),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        option.text,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: optionColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: optionColor.withValues(alpha: 0.38),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          "$percentageInt% • ${option.votes}",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: optionColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _optionColor(int index) {
    const colors = [
      Color(0xFF2563EB),
      Color(0xFF10B981),
      Color(0xFFF97316),
      Color(0xFFA855F7),
      Color(0xFFE11D48),
    ];
    return colors[index % colors.length];
  }
}

class _PollHeader extends StatelessWidget {
  const _PollHeader({required this.question});

  final String question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.primary.withValues(alpha: 0.34)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.poll_rounded, size: 16, color: cs.primary)],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            question,
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              height: 1.25,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.color, required this.isSelected});

  final Color color;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? color : Colors.transparent,
        border: Border.all(
          color: isSelected ? color : color.withValues(alpha: 0.72),
          width: 1.7,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
          : null,
    );
  }
}
