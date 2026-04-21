import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';

class DiaryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DiaryCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = entry.photoPaths.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPhoto) _buildPhotoStrip(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (entry.mood != null) ...[
                        Text(entry.mood!, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          entry.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: onDelete,
                        color: Colors.red.shade300,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  _buildMetaRow(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoStrip() {
    final photos = entry.photoPaths.take(3).toList();
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        height: 140,
        child: Row(
          children: [
            Expanded(
              flex: photos.length > 1 ? 2 : 1,
              child: _photoTile(photos[0]),
            ),
            if (photos.length > 1) ...[
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _photoTile(photos[1])),
                    if (photos.length > 2) ...[
                      const SizedBox(height: 2),
                      Expanded(child: _photoTile(photos[2])),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _photoTile(String path) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _metaChip(Icons.calendar_today,
            DateFormat('yyyy.MM.dd (E)', 'ko').format(entry.date)),
        if (entry.weather != null)
          _metaChip(null, entry.weather!, isEmoji: true),
        if (entry.location != null && entry.location!.isNotEmpty)
          _metaChip(Icons.location_on, entry.location!),
        if (entry.batteryLevel != null)
          _metaChip(Icons.battery_std, '${entry.batteryLevel}%'),
        if (entry.photoPaths.isNotEmpty)
          _metaChip(Icons.photo, '${entry.photoPaths.length}장'),
      ],
    );
  }

  Widget _metaChip(IconData? icon, String label, {bool isEmoji = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isEmoji) Text(label, style: const TextStyle(fontSize: 14))
        else ...[
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ],
    );
  }
}
