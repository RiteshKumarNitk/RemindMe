import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/vital_entry.dart';

/// Screen for logging and viewing vital signs.
/// Allows tracking BP, blood sugar, weight, temperature, and heart rate.
class VitalsLogScreen extends StatefulWidget {
  const VitalsLogScreen({super.key});

  @override
  State<VitalsLogScreen> createState() => _VitalsLogScreenState();
}

class _VitalsLogScreenState extends State<VitalsLogScreen> {
  VitalType _selectedType = VitalType.bloodPressure;
  List<VitalEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = <VitalEntry>[];
    final keys = prefs.getKeys().where((k) => k.startsWith('vital_'));
    for (final key in keys) {
      final data = prefs.getStringList(key);
      if (data != null && data.length >= 4) {
        entries.add(VitalEntry(
          id: int.tryParse(data[0]),
          type: VitalType.values.firstWhere(
            (t) => t.name == data[1],
            orElse: () => VitalType.bloodPressure,
          ),
          value: double.tryParse(data[2]) ?? 0,
          value2: data.length > 3 ? double.tryParse(data[3]) : null,
          recordedAt: data.length > 4
              ? DateTime.tryParse(data[4]) ?? DateTime.now()
              : DateTime.now(),
          notes: data.length > 5 ? data[5] : null,
        ));
      }
    }
    entries.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _saveEntry(VitalEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final id = DateTime.now().millisecondsSinceEpoch;
    final data = [
      id.toString(),
      entry.type.name,
      entry.value.toString(),
      entry.value2?.toString() ?? '',
      entry.recordedAt.toIso8601String(),
      entry.notes ?? '',
    ];
    await prefs.setStringList('vital_$id', data);
    await _loadEntries();
  }

  Future<void> _deleteEntry(int index) async {
    final entry = _entries[index];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vital_${entry.id}');
    await _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _entries.where((e) => e.type == _selectedType).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vitals Log'),
        actions: [
          IconButton(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Type selector
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final type in VitalType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(type.displayName),
                      selected: _selectedType == type,
                      onSelected: (_) =>
                          setState(() => _selectedType = type),
                    ),
                  ),
              ],
            ),
          ),

          // Chart area
          if (filtered.length >= 2)
            SizedBox(
              height: 180,
              child: _VitalChart(
                entries: filtered,
                type: _selectedType,
              ),
            ),

          // Entries list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 56,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_selectedType.displayName.toLowerCase()} entries yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => _showAddDialog(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add First Reading'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      return _VitalTile(
                        entry: entry,
                        onDelete: () => _deleteEntry(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddVitalSheet(
        type: _selectedType,
        onSave: (entry) {
          _saveEntry(entry);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

// ─── Add Vital Sheet ────────────────────────────────────────────────────────

class _AddVitalSheet extends StatefulWidget {
  const _AddVitalSheet({required this.type, required this.onSave});

  final VitalType type;
  final ValueChanged<VitalEntry> onSave;

  @override
  State<_AddVitalSheet> createState() => _AddVitalSheetState();
}

class _AddVitalSheetState extends State<_AddVitalSheet> {
  late TextEditingController _controller1;
  late TextEditingController _controller2;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _controller1 = TextEditingController();
    _controller2 = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBP = widget.type == VitalType.bloodPressure;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add ${widget.type.displayName}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller1,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: theme.textTheme.headlineSmall,
                  decoration: InputDecoration(
                    labelText: isBP ? 'Systolic' : widget.type.displayName,
                    suffixText: widget.type.unit,
                  ),
                ),
              ),
              if (isBP) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '/',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller2,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.headlineSmall,
                    decoration: const InputDecoration(
                      labelText: 'Diastolic',
                      suffixText: 'mmHg',
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g. After walking',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () {
                final v1 = double.tryParse(_controller1.text);
                if (v1 == null) return;
                final v2 = isBP ? double.tryParse(_controller2.text) : null;
                widget.onSave(VitalEntry(
                  type: widget.type,
                  value: v1,
                  value2: v2,
                  recordedAt: DateTime.now(),
                  notes: _notesController.text.isNotEmpty
                      ? _notesController.text
                      : null,
                ));
              },
              child: const Text('Save Reading'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vital Tile ─────────────────────────────────────────────────────────────

class _VitalTile extends StatelessWidget {
  const _VitalTile({required this.entry, required this.onDelete});

  final VitalEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, String label) = switch (entry.status) {
      VitalStatus.normal => (theme.successColor, 'Normal'),
      VitalStatus.elevated => (theme.pendingColor, 'Elevated'),
      VitalStatus.high => (theme.missedColor, 'High'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Value
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.displayValue,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                entry.type.unit,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const Spacer(),
          // Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppDateUtils.timeLabel(
                  entry.recordedAt,
                  'en',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                AppDateUtils.dateLabel(entry.recordedAt, 'en'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: theme.colorScheme.outline,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Simple Line Chart ──────────────────────────────────────────────────────

class _VitalChart extends StatelessWidget {
  const _VitalChart({required this.entries, required this.type});

  final List<VitalEntry> entries;
  final VitalType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Show last 20 entries
    final data = entries.take(20).toList().reversed.toList();
    if (data.isEmpty) return const SizedBox.shrink();

    final values = data.map((e) => e.value).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                type.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${data.length} readings',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _LineChartPainter(
                values: values,
                minVal: minVal,
                maxVal: maxVal,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.minVal,
    required this.maxVal,
    required this.color,
  });

  final List<double> values;
  final double minVal;
  final double maxVal;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final range = maxVal - minVal;
    final step = size.width / (values.length - 1);

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < values.length; i++) {
      final x = i * step;
      final y = range > 0
          ? size.height - ((values[i] - minVal) / range) * size.height
          : size.height / 2;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var i = 0; i < values.length; i++) {
      final x = i * step;
      final y = range > 0
          ? size.height - ((values[i] - minVal) / range) * size.height
          : size.height / 2;
      canvas.drawCircle(
        Offset(x, y),
        3,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => true;
}
