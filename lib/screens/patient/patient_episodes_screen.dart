import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../tremor_pipeline.dart';
import '../../widgets/shared/shared_widgets.dart';

// ============================================================
// EPISODE HISTORY SCREEN
// Shows real detected tremor + dyskinesia episodes from
// tremorPipeline.episodes — live data from processing team
// ============================================================

class PatientEpisodesScreen extends StatelessWidget {
  const PatientEpisodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pipeline = Provider.of<TremorPipeline>(context);
    final episodes = pipeline.episodes;

    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE8),
                              appBar: AppBar(
        backgroundColor: const Color(0xFF0F3D24),
        foregroundColor: Colors.white,
        title: const Text('Symptom episodes',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F3D24), Color(0xFF1A6B3E)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
      ),
      body: episodes.isEmpty
          ? _EmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // Explainer
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.teal50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.teal100, width: 0.5),
                  ),
                  child: const Text(
                    'These are moments your wristband detected a symptom. '
                    'They are automatically recorded — you don\'t need to do anything.',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.teal700, height: 1.4),
                  ),
                ),

                // Today's episodes
                _EpisodeGroup(
                  label: 'Today',
                  episodes: episodes
                      .where((e) => _isToday(e.detectedAt))
                      .toList(),
                ),

                // Yesterday
                _EpisodeGroup(
                  label: 'Yesterday',
                  episodes: episodes
                      .where((e) => _isYesterday(e.detectedAt))
                      .toList(),
                ),

                // Earlier
                _EpisodeGroup(
                  label: 'Earlier',
                  episodes: episodes
                      .where((e) =>
                          !_isToday(e.detectedAt) &&
                          !_isYesterday(e.detectedAt))
                      .toList(),
                ),
              ],
            ),
    );
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
  }

  bool _isYesterday(DateTime dt) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day;
  }
}

class _EpisodeGroup extends StatelessWidget {
  final String label;
  final List<DetectedEpisode> episodes;
  const _EpisodeGroup({required this.label, required this.episodes});

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: label),
        ...episodes.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EpisodeTile(episode: e),
            )),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final DetectedEpisode episode;
  const _EpisodeTile({required this.episode});

  Color get _color {
    if (episode.severityLevel >= 3) return AppTheme.red400;
    if (episode.severityLevel >= 2) return const Color(0xFFE07B30);
    if (episode.severityLevel >= 1) return AppTheme.amber400;
    return AppTheme.teal500;
  }

  Color get _bgColor {
    if (episode.severityLevel >= 3) return AppTheme.red50;
    if (episode.severityLevel >= 2) return const Color(0xFFFAEEDA);
    if (episode.severityLevel >= 1) return AppTheme.amber50;
    return AppTheme.teal50;
  }

  IconData get _icon {
    return episode.symptomType == 'Tremor'
        ? Icons.vibration_rounded
        : Icons.directions_run_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.symptomType,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  _timeLabel(episode.detectedAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.neutral400),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              episode.severityLabel,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _color),
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 2) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago · ${_clock(dt)}';
    return _clock(dt);
  }

  String _clock(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.teal50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppTheme.teal500, size: 36),
            ),
            const SizedBox(height: 20),
            const Text('No episodes detected',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neutral900)),
            const SizedBox(height: 8),
            const Text(
              'Your wristband is monitoring. Any detected tremor or '
              'dyskinesia episodes will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.neutral500,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

const neutral400 = Color(0xFF888780);