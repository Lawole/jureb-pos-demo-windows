import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../services.dart';

const _uuid = Uuid();

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<Services>().db;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(context, db),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: StreamBuilder<List<Category>>(
        stream: db.categoryDao.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = snapshot.data!;
          if (categories.isEmpty) {
            return const Center(child: Text('No categories yet.'));
          }
          return ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                title: Text(category.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showCategoryDialog(context, db, existing: category),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => db.categoryDao.softDelete(category.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCategoryDialog(BuildContext context, PosDatabase db,
      {Category? existing}) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add category' : 'Edit category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Category name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Save')),
        ],
      ),
    );

    if (saved != true) return;
    final name = controller.text.trim();
    if (existing == null) {
      await db.categoryDao.insertCategory(
        CategoriesCompanion.insert(id: _uuid.v4(), name: name),
      );
    } else {
      await db.categoryDao.updateCategory(
        existing.toCompanion(true).copyWith(name: Value(name), updatedAt: Value(DateTime.now())),
      );
    }
  }
}
