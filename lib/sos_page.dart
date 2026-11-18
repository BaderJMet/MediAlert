import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ice_profile.dart';

class SosPage extends StatefulWidget {
  final IceProfile profile;
  const SosPage({super.key, required this.profile});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  bool _isCalling = false;

  Future<void> _makeCall(String phone) async {
    final cleanedPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: cleanedPhone);

    final launched = await launchUrl(uri);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not launch call'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _triggerSOS() async {
    final contacts = widget.profile.emergencyContacts;

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No emergency contacts found! Please add contacts in your ICE profile.',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isCalling = true);

    await _makeCall(contacts[0].phone);

    setState(() => _isCalling = false);
  }

  @override
  Widget build(BuildContext context) {
    final contacts = widget.profile.emergencyContacts;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      children: [
        // ── Warning Banner ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.red.shade400, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Only use in a real emergency. This will call your first emergency contact immediately.',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // ── SOS Button ──
        Center(
          child: GestureDetector(
            onTap: _isCalling ? null : _triggerSOS,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isCalling ? Colors.red.shade300 : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: _isCalling ? 40 : 20,
                    spreadRadius: _isCalling ? 10 : 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sos_rounded,
                    color: Theme.of(context).cardColor,
                    size: 64,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'EMERGENCY',
                    style: TextStyle(
                      color: Theme.of(context).cardColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Tap to call your emergency contact',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 40),

        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.surfaceVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.contacts_rounded,
                        color: Colors.teal,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Emergency Contacts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              if (contacts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No contacts added yet. Go to ICE Profile to add emergency contacts.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                ...contacts.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: i == 0
                            ? Colors.red.withOpacity(0.12)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: i == 0 ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      c.phone,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    trailing: i == 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Primary',
                              style: TextStyle(
                                color: Colors.red.shade400,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : IconButton(
                            onPressed: () => _makeCall(c.phone),
                            icon: const Icon(
                              Icons.call_rounded,
                              color: Colors.teal,
                              size: 20,
                            ),
                          ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}
