import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/banner_item.dart';
import '../../models/tournament.dart';
import '../../services/firestore_service.dart';
import '../../services/tournament_service.dart';
import '../../theme.dart';

/// Owner promo banner management (title, text, image link, tournament
/// link, on/off, order).
class BannersScreen extends StatelessWidget {
  const BannersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Promo banners')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New banner'),
        onPressed: () => _edit(context, null),
      ),
      body: StreamBuilder<List<BannerItem>>(
        stream: db.banners(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final banners = snap.data!;
          if (banners.isEmpty) {
            return const Center(
                child: Text('No banners yet — announce something!'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              for (final b in banners)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: b.active
                          ? AppTheme.ballLime
                          : Colors.grey.shade300,
                      child: Text('${b.order}',
                          style: const TextStyle(
                              color: AppTheme.courtBlueDark,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text(b.title),
                    subtitle: Text(b.text,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Switch(
                      value: b.active,
                      onChanged: (on) => db.saveBanner(BannerItem(
                        id: b.id,
                        title: b.title,
                        text: b.text,
                        imageUrl: b.imageUrl,
                        tournamentId: b.tournamentId,
                        active: on,
                        order: b.order,
                      )),
                    ),
                    onTap: () => _edit(context, b),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, BannerItem? existing) async {
    final db = context.read<FirestoreService>();
    final tournaments =
        await context.read<TournamentService>().tournaments().first;
    if (!context.mounted) return;

    final title = TextEditingController(text: existing?.title);
    final text = TextEditingController(text: existing?.text);
    final imageUrl = TextEditingController(text: existing?.imageUrl);
    final order =
        TextEditingController(text: (existing?.order ?? 0).toString());
    String tournamentId = existing?.tournamentId ?? '';
    final upcoming = tournaments.where((t) => !t.isPast).toList();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) => AlertDialog(
          title: Text(existing == null ? 'New banner' : 'Edit banner'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: title,
                    decoration:
                        const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(
                    controller: text,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Short text')),
                const SizedBox(height: 12),
                TextField(
                    controller: imageUrl,
                    decoration: const InputDecoration(
                        labelText: 'Image URL (optional)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tournamentId,
                  decoration: const InputDecoration(
                      labelText: 'Link to tournament (optional)'),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('No link')),
                    for (final Tournament t in upcoming)
                      DropdownMenuItem(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) => setState(() => tournamentId = v ?? ''),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Order (lower shows first)')),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await db.deleteBanner(existing.id);
                  if (ctx2.mounted) Navigator.pop(ctx2);
                },
                child: const Text('Delete',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                await db.saveBanner(BannerItem(
                  id: existing?.id ?? '',
                  title: title.text.trim(),
                  text: text.text.trim(),
                  imageUrl: imageUrl.text.trim(),
                  tournamentId: tournamentId,
                  active: existing?.active ?? true,
                  order: int.tryParse(order.text) ?? 0,
                ));
                if (ctx2.mounted) Navigator.pop(ctx2);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
