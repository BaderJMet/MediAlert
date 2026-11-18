import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'adherence_log.dart';
import 'medication.dart';

class HistoryPage extends StatefulWidget {
  final List<AdherenceRecord> records;

  const HistoryPage({super.key, required this.records});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _filter = 'All';
  final List<String> _filters = ['All', 'Taken', 'Missed'];

  List<AdherenceRecord> get _filtered {
    if (_filter == 'Taken') {
      return widget.records.where((r) => r.status == DoseStatus.taken).toList();
    } else if (_filter == 'Missed') {
      return widget.records
          .where((r) => r.status == DoseStatus.missed)
          .toList();
    }
    return widget.records;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterChips(),
        Expanded(child: _filtered.isEmpty ? _buildEmptyState() : _buildList()),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: _filters.map((f) {
          final active = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: active ? Colors.indigo : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? Colors.indigo
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    color: active
                        ? Theme.of(context).cardColor
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList() {
    final reversed = _filtered.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: reversed.length,
      itemBuilder: (context, index) {
        final record = reversed[index];
        final isTaken = record.status == DoseStatus.taken;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.surfaceVariant,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isTaken
                    ? Colors.teal.withOpacity(0.10)
                    : Colors.red.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isTaken ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isTaken ? Colors.teal : Colors.red,
                size: 22,
              ),
            ),
            title: Text(
              record.medicationName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              '${record.dosage}\n'
              '${DateFormat('MMM d, yyyy').format(record.scheduledDate)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.5,
              ),
            ),

            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isTaken
                        ? Colors.teal.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isTaken ? 'Taken' : 'Missed',
                    style: TextStyle(
                      color: isTaken ? Colors.teal : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (record.confirmedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(record.confirmedAt!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No records yet',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Confirm or miss a dose to see it here',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
