import 'package:flutter/material.dart';
import 'quick_access_widgets.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _announcementController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'Global Announcements',
      children: [
        QuickAccessCard(
          title: 'Broadcast Announcement',
          description: 'Broadcast notifications to all active school clusters.',
          child: Column(
            children: [
              TextField(
                controller: _announcementController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Compose announcement to broadcast globally...',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Announcement Broadcasted Successfully!')),
                  );
                  _announcementController.clear();
                },
                icon: const Icon(Icons.campaign_outlined, size: 16),
                label: const Text('Broadcast Announcement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
