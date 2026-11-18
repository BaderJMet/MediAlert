import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'adherence_log.dart';
import 'ice_profile.dart';
import 'medication.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum HealthReportRange { lastWeek, lastMonth }

class HealthReportPage extends StatefulWidget {
  final IceProfile profile;
  final List<AdherenceRecord> records;

  const HealthReportPage({
    super.key,
    required this.profile,
    required this.records,
  });

  @override
  State<HealthReportPage> createState() => _HealthReportPageState();
}

class _HealthReportPageState extends State<HealthReportPage> {
  HealthReportRange _selectedRange = HealthReportRange.lastWeek;

  List<AdherenceRecord> get _filteredRecords {
    final now = DateTime.now();
    final start = _selectedRange == HealthReportRange.lastWeek
        ? now.subtract(const Duration(days: 7))
        : now.subtract(const Duration(days: 30));

    final filtered = widget.records
        .where((record) => record.scheduledDate.isAfter(start))
        .toList();

    filtered.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    return filtered;
  }

  int get _takenCount =>
      _filteredRecords.where((r) => r.status == DoseStatus.taken).length;

  int get _missedCount =>
      _filteredRecords.where((r) => r.status == DoseStatus.missed).length;

  int get _totalCount => _filteredRecords.length;

  double get _adherencePercent {
    if (_totalCount == 0) return 0;
    return (_takenCount / _totalCount) * 100;
  }

  String _rangeLabel(HealthReportRange range) {
    return range == HealthReportRange.lastWeek ? 'Last Week' : 'Last Month';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('MMM d, yyyy - h:mm a').format(date);
  }

  Widget _buildSummaryTile(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(BuildContext context) {
    final profile = widget.profile;

    final items = [
      ('Full Name', profile.fullName.isEmpty ? 'Not set' : profile.fullName),
      ('Date of Birth', _formatDate(profile.dateOfBirth)),
      ('Gender', profile.gender.isEmpty ? 'Not set' : profile.gender),
      ('Blood Type', profile.bloodType.isEmpty ? 'Not set' : profile.bloodType),
      ('Height', profile.height.isEmpty ? 'Not set' : '${profile.height} cm'),
      ('Weight', profile.weight.isEmpty ? 'Not set' : '${profile.weight} kg'),
      (
        'Chronic Conditions',
        profile.chronicConditions.isEmpty
            ? 'Not set'
            : profile.chronicConditions,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Summary',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      item.$1,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(BuildContext context) {
    if (_totalCount == 0) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Theme.of(context).colorScheme.surfaceVariant,
          ),
        ),
        child: Text(
          'No adherence data for this period',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adherence Breakdown',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 48,
                sectionsSpace: 4,
                sections: [
                  PieChartSectionData(
                    value: _takenCount.toDouble(),
                    color: Colors.teal,
                    radius: 64,
                    title: _takenCount == 0 ? '' : 'Taken\n$_takenCount',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  PieChartSectionData(
                    value: _missedCount.toDouble(),
                    color: Colors.red,
                    radius: 64,
                    title: _missedCount == 0 ? '' : 'Missed\n$_missedCount',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Taken', Colors.teal),
              const SizedBox(width: 16),
              _buildLegendItem('Missed', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRecordList(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Medication Adherence Records',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 14),
          if (_filteredRecords.isEmpty)
            Text(
              'No records found for ${_rangeLabel(_selectedRange).toLowerCase()}.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            )
          else
            ..._filteredRecords.map((record) {
              final isTaken = record.status == DoseStatus.taken;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isTaken
                      ? Colors.teal.withOpacity(0.08)
                      : Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isTaken
                        ? Colors.teal.withOpacity(0.18)
                        : Colors.red.withOpacity(0.18),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isTaken
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: isTaken ? Colors.teal : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.medicationName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${record.dosage} - ${_formatDateTime(record.scheduledDate)}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      isTaken ? 'Taken' : 'Missed',
                      style: TextStyle(
                        color: isTaken ? Colors.teal : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final records = _filteredRecords;
    final profile = widget.profile;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Health Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Period: ${_rangeLabel(_selectedRange)}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 20),

          pw.Text(
            'Patient Summary',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _pdfInfoRow(
            'Full Name',
            profile.fullName.isEmpty ? 'Not set' : profile.fullName,
          ),
          _pdfInfoRow('Date of Birth', _formatDate(profile.dateOfBirth)),
          _pdfInfoRow(
            'Gender',
            profile.gender.isEmpty ? 'Not set' : profile.gender,
          ),
          _pdfInfoRow(
            'Blood Type',
            profile.bloodType.isEmpty ? 'Not set' : profile.bloodType,
          ),
          _pdfInfoRow(
            'Height',
            profile.height.isEmpty ? 'Not set' : '${profile.height} cm',
          ),
          _pdfInfoRow(
            'Weight',
            profile.weight.isEmpty ? 'Not set' : '${profile.weight} kg',
          ),
          _pdfInfoRow(
            'Chronic Conditions',
            profile.chronicConditions.isEmpty
                ? 'Not set'
                : profile.chronicConditions,
          ),

          pw.SizedBox(height: 20),
          pw.Text(
            'Adherence Summary',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _pdfInfoRow('Total Doses', '$_totalCount'),
          _pdfInfoRow('Taken', '$_takenCount'),
          _pdfInfoRow('Missed', '$_missedCount'),
          _pdfInfoRow(
            'Adherence Percentage',
            '${_adherencePercent.toStringAsFixed(1)}%',
          ),

          pw.SizedBox(height: 20),
          pw.Text(
            'Medication Adherence Records',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          if (records.isEmpty)
            pw.Text('No records found for this period.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.2),
                1: const pw.FlexColumnWidth(1.6),
                2: const pw.FlexColumnWidth(2.8),
                3: const pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _pdfTableCell('Medication', isHeader: true),
                    _pdfTableCell('Dosage', isHeader: true),
                    _pdfTableCell('Date / Time', isHeader: true),
                    _pdfTableCell('Status', isHeader: true),
                  ],
                ),
                ...records.map(
                  (record) => pw.TableRow(
                    children: [
                      _pdfTableCell(record.medicationName),
                      _pdfTableCell(record.dosage),
                      _pdfTableCell(_formatDateTime(record.scheduledDate)),
                      _pdfTableCell(
                        record.status == DoseStatus.taken ? 'Taken' : 'Missed',
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  pw.Widget _pdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adherenceText = '${_adherencePercent.toStringAsFixed(1)}%';

    return Scaffold(
      appBar: AppBar(title: const Text('Health Report'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          SegmentedButton<HealthReportRange>(
            segments: const [
              ButtonSegment(
                value: HealthReportRange.lastWeek,
                label: Text('Last Week'),
                icon: Icon(Icons.calendar_view_week_rounded),
              ),
              ButtonSegment(
                value: HealthReportRange.lastMonth,
                label: Text('Last Month'),
                icon: Icon(Icons.calendar_month_rounded),
              ),
            ],
            selected: {_selectedRange},
            onSelectionChanged: (selection) {
              setState(() => _selectedRange = selection.first);
            },
          ),
          const SizedBox(height: 16),
          _buildProfileInfo(context),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryTile(
                  context,
                  'Total Doses',
                  '$_totalCount',
                  Icons.medication_rounded,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryTile(
                  context,
                  'Adherence',
                  adherenceText,
                  Icons.pie_chart_rounded,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryTile(
                  context,
                  'Taken',
                  '$_takenCount',
                  Icons.check_circle_rounded,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryTile(
                  context,
                  'Missed',
                  '$_missedCount',
                  Icons.cancel_rounded,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPieChart(context),
          const SizedBox(height: 16),
          _buildRecordList(context),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Export PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
