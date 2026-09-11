import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../services.dart';

const _uuid = Uuid();

class SuppliersTab extends StatelessWidget {
  const SuppliersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<Services>().db;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupplierDialog(context, db),
        icon: const Icon(Icons.add),
        label: const Text('Add supplier'),
      ),
      body: StreamBuilder<List<Supplier>>(
        stream: db.supplierDao.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final suppliers = snapshot.data!;
          if (suppliers.isEmpty) {
            return const Center(child: Text('No suppliers yet.'));
          }
          return ListView.separated(
            itemCount: suppliers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return ListTile(
                title: Text(supplier.name),
                subtitle: Text([
                  if (supplier.contactPerson != null) supplier.contactPerson!,
                  if (supplier.phone != null) supplier.phone!,
                  if (supplier.email != null) supplier.email!,
                ].join(' · ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showSupplierDialog(context, db, existing: supplier),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => db.supplierDao.softDelete(supplier.id),
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

  Future<void> _showSupplierDialog(BuildContext context, PosDatabase db,
      {Supplier? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final contactController = TextEditingController(text: existing?.contactPerson ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final addressController = TextEditingController(text: existing?.address ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add supplier' : 'Edit supplier'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Supplier name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: contactController,
                  decoration: const InputDecoration(labelText: 'Contact person'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
              ],
            ),
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
    String? orNull(String text) => text.trim().isEmpty ? null : text.trim();

    if (existing == null) {
      await db.supplierDao.insertSupplier(SuppliersCompanion.insert(
        id: _uuid.v4(),
        name: nameController.text.trim(),
        contactPerson: Value(orNull(contactController.text)),
        phone: Value(orNull(phoneController.text)),
        email: Value(orNull(emailController.text)),
        address: Value(orNull(addressController.text)),
      ));
    } else {
      await db.supplierDao.updateSupplier(existing.toCompanion(true).copyWith(
            name: Value(nameController.text.trim()),
            contactPerson: Value(orNull(contactController.text)),
            phone: Value(orNull(phoneController.text)),
            email: Value(orNull(emailController.text)),
            address: Value(orNull(addressController.text)),
            updatedAt: Value(DateTime.now()),
          ));
    }
  }
}
