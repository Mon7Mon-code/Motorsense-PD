import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// ============================================================
// SHARED WIDGETS — used in both patient and clinician portals
// ============================================================

// --- Section header -----------------------------------------
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// --- App card shell -----------------------------------------
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  const AppCard({super.key, required this.child, this.padding,
      this.backgroundColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.neutral200, width: 0.5),
          ),
          padding: padding ?? Sp.cardPad,
          child: child,
        ),
      ),
    );
  }
}

// --- Status pill badge ---------------------------------------
class StatusPill extends StatelessWidget {
  final String flag;
  const StatusPill({super.key, required this.flag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.statusBg(flag),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        AppTheme.statusLabel(flag),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.statusColor(flag),
        ),
      ),
    );
  }
}

// --- Device status indicator --------------------------------
class DeviceStatusBar extends StatelessWidget {
  final bool isConnected;
  final int batteryPercent;
  final DateTime? lastSync;
  final bool isPatientView; // simplified for patients

  const DeviceStatusBar({
    super.key,
    required this.isConnected,
    required this.batteryPercent,
    this.lastSync,
    this.isPatientView = false,
  });

  @override
  Widget build(BuildContext context) {
    final batteryColor = batteryPercent > 30
        ? AppTheme.teal500
        : batteryPercent > 15
            ? AppTheme.amber400
            : AppTheme.red400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isConnected ? AppTheme.teal50 : AppTheme.neutral100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConnected ? AppTheme.teal100 : AppTheme.neutral200,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.watch_rounded : Icons.watch_off_outlined,
            size: 16,
            color: isConnected ? AppTheme.teal600 : AppTheme.neutral500,
          ),
          const SizedBox(width: 6),
          Text(
            isPatientView
                ? (isConnected ? 'Device active' : 'Device not connected')
                : (isConnected ? 'Connected' : 'Offline'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isConnected ? AppTheme.teal700 : AppTheme.neutral500,
            ),
          ),
          if (isConnected) ...[
            const SizedBox(width: 10),
            const SizedBox(
              height: 12, child: VerticalDivider(width: 1, thickness: 0.5)),
            const SizedBox(width: 10),
            Icon(Icons.battery_std_rounded, size: 14, color: AppTheme.neutral300),
            const SizedBox(width: 3),
            Text(
              batteryPercent > 0 ? '$batteryPercent%' : 'Battery unknown',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.neutral400),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Metric tile (for clinician dashboard) ------------------
class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;
  final IconData? icon;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppTheme.neutral300),
            const SizedBox(height: 8),
          ],
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.neutral500,
                  letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: AppTheme.monoLarge
                      .copyWith(color: valueColor ?? AppTheme.neutral900)),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(unit!,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.neutral500)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// --- Score bar (symptom severity) ---------------------------
class ScoreBar extends StatelessWidget {
  final String label;
  final double score; // 0.0–4.0
  final bool showLabel; // patient gets text, clinician gets number
  const ScoreBar({
    super.key,
    required this.label,
    required this.score,
    this.showLabel = true,
  });

  Color get _barColor {
    if (score < 1.0) return AppTheme.teal500;
    if (score < 2.0) return AppTheme.amber400;
    if (score < 3.0) return const Color(0xFFE07B30);
    return AppTheme.red400;
  }

  String get _textLabel {
    if (score < 0.5) return 'None';
    if (score < 1.5) return 'Mild';
    if (score < 2.5) return 'Moderate';
    if (score < 3.5) return 'Notable';
    return 'Severe';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.neutral700)),
            Text(
              showLabel ? _textLabel : score.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _barColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 4.0,
            minHeight: 6,
            backgroundColor: AppTheme.neutral100,
            valueColor: AlwaysStoppedAnimation<Color>(_barColor),
          ),
        ),
      ],
    );
  }
}

// --- Section divider with label -----------------------------
class LabelledDivider extends StatelessWidget {
  final String label;
  const LabelledDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.neutral400,
                  letterSpacing: 0.5)),
        ),
        const Expanded(child: Divider()),
      ]),
    );
  }
}
