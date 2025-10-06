import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProviderAvailabilityScreen extends StatefulWidget {
  const ProviderAvailabilityScreen({super.key});

  @override
  State<ProviderAvailabilityScreen> createState() => _ProviderAvailabilityScreenState();
}

class _ProviderAvailabilityScreenState extends State<ProviderAvailabilityScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _isAvailableNow = true;

  // days config: enabled + start/end times
  final List<String> _days = const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  late List<bool> _enabled;
  late List<TimeOfDay> _startTimes;
  late List<TimeOfDay> _endTimes;

  @override
  void initState() {
    super.initState();
    _enabled = List<bool>.filled(7, true);
    _startTimes = List<TimeOfDay>.generate(7, (_) => const TimeOfDay(hour: 9, minute: 0));
    _endTimes = List<TimeOfDay>.generate(7, (_) => const TimeOfDay(hour: 18, minute: 0));
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('availability')
          .doc('settings')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _isAvailableNow = (data['isAvailableNow'] as bool?) ?? true;
          final days = (data['days'] as List?) ?? [];
          if (days.length == 7) {
            for (int i = 0; i < 7; i++) {
              final d = days[i] as Map<String, dynamic>;
              _enabled[i] = (d['enabled'] as bool?) ?? true;
              _startTimes[i] = _parseHHmm(d['start'] as String?);
              _endTimes[i] = _parseHHmm(d['end'] as String?);
            }
          }
        });
      }
    } catch (_) {
      // keep defaults
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TimeOfDay _parseHHmm(String? s) {
    if (s == null || !s.contains(':')) return const TimeOfDay(hour: 9, minute: 0);
    final parts = s.split(':');
    final h = int.tryParse(parts[0]) ?? 9;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h, minute: m);
    }

  String _format(TimeOfDay t) => t.hour.toString().padLeft(2,'0')+":"+t.minute.toString().padLeft(2,'0');

  Future<void> _pickTime(int index, bool isStart) async {
    final initial = isStart ? _startTimes[index] : _endTimes[index];
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTimes[index] = picked;
        } else {
          _endTimes[index] = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final days = List.generate(7, (i) => {
            'enabled': _enabled[i],
            'start': _format(_startTimes[i]),
            'end': _format(_endTimes[i]),
          });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('availability')
          .doc('settings')
          .set({
        'isAvailableNow': _isAvailableNow,
        'days': days,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Availability saved'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Availability'),
        backgroundColor: Colors.deepPurple,
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  value: _isAvailableNow,
                  onChanged: (v) => setState(() => _isAvailableNow = v),
                  title: const Text('Available Now'),
                  subtitle: const Text('Toggle to accept bookings for now'),
                ),
                const SizedBox(height: 8),
                const Text('Weekly Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                for (int i = 0; i < 7; i++) _dayRow(i),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                )
              ],
            ),
    );
  }

  Widget _dayRow(int i) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(_days[i], style: const TextStyle(fontWeight: FontWeight.w600))),
                Switch(value: _enabled[i], onChanged: (v) => setState(() => _enabled[i] = v)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _enabled[i] ? () => _pickTime(i, true) : null,
                    icon: const Icon(Icons.schedule),
                    label: Text('Start ${_format(_startTimes[i])}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _enabled[i] ? () => _pickTime(i, false) : null,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text('End ${_format(_endTimes[i])}'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
