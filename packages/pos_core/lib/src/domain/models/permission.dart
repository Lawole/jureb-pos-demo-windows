import '../../database/tables/staff_table.dart';

/// App-level capabilities gated by role. Kept as a flat enum + static map
/// (rather than per-role booleans scattered through the UI) so every screen
/// checks permissions the same way, and adding a new capability means
/// touching one place.
enum Permission {
  viewDashboard,
  manageProducts,
  manageCategories,
  manageSuppliers,
  adjustStock,
  makeSale,
  applyDiscount,
  voidSaleItem,
  processRefund,
  openCloseTill,
  manageStaff,
  viewReports,
  manageSettings,
}

const Map<StaffRole, Set<Permission>> _rolePermissions = {
  StaffRole.admin: {
    Permission.viewDashboard,
    Permission.manageProducts,
    Permission.manageCategories,
    Permission.manageSuppliers,
    Permission.adjustStock,
    Permission.makeSale,
    Permission.applyDiscount,
    Permission.voidSaleItem,
    Permission.processRefund,
    Permission.openCloseTill,
    Permission.manageStaff,
    Permission.viewReports,
    Permission.manageSettings,
  },
  StaffRole.manager: {
    Permission.viewDashboard,
    Permission.manageProducts,
    Permission.manageCategories,
    Permission.manageSuppliers,
    Permission.adjustStock,
    Permission.makeSale,
    Permission.applyDiscount,
    Permission.voidSaleItem,
    Permission.processRefund,
    Permission.openCloseTill,
    Permission.viewReports,
  },
  StaffRole.cashier: {
    Permission.viewDashboard,
    Permission.makeSale,
    Permission.openCloseTill,
  },
};

extension StaffRolePermissions on StaffRole {
  Set<Permission> get permissions => _rolePermissions[this] ?? const {};

  bool can(Permission permission) => permissions.contains(permission);
}
