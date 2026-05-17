import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/backup_service.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _secureStorage = FlutterSecureStorage();
  static final _localAuth = LocalAuthentication();

  bool _pinEnabled = false;
  bool _biometricEnabled = false;

  // ──────────────────────────────────────────────────────────────
  // Currency helpers
  // ──────────────────────────────────────────────────────────────

  static const Map<String, String> _currencySymbols = {
    'BDT': '৳',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'JPY': '¥',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'SGD': 'S\$',
  };

  static String _currencySymbol(String code) => _currencySymbols[code] ?? code;

  static String _themeName(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System Default',
      };

  // ──────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    final pinLock = await _secureStorage.read(key: 'pin_lock_enabled');
    final bioLock = await _secureStorage.read(key: 'biometric_enabled');
    if (!mounted) return;
    setState(() {
      _pinEnabled = pinLock == 'true';
      _biometricEnabled = bioLock == 'true';
    });
  }

  // ──────────────────────────────────────────────────────────────
  // Theme
  // ──────────────────────────────────────────────────────────────

  void _showThemePicker() {
    final current = ref.read(themeModeProvider);
    showModalBottomSheet<ThemeMode>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choose Theme',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            for (final mode in ThemeMode.values)
              ListTile(
                title: Text(_themeName(mode)),
                leading: Radio<ThemeMode>(
                  value: mode,
                  groupValue: current,
                  onChanged: (v) {
                    ref.read(themeModeProvider.notifier).setThemeMode(v!);
                    Navigator.pop(context);
                  },
                ),
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Currency
  // ──────────────────────────────────────────────────────────────

  void _showCurrencyPicker() {
    final current = ref.read(settingsProvider).currencyCode;
    final entries = _currencySymbols.entries.toList();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Choose Currency',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final code = entries[i].key;
                  final symbol = entries[i].value;
                  return ListTile(
                    title: Text('$code ($symbol)'),
                    leading: Radio<String>(
                      value: code,
                      groupValue: current,
                      onChanged: (v) => _setCurrency(v!),
                    ),
                    onTap: () => _setCurrency(code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setCurrency(String code) async {
    await ref.read(settingsProvider.notifier).setCurrency(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency_code', code);
    if (!mounted) return;
    Navigator.pop(context);
  }

  // ──────────────────────────────────────────────────────────────
  // PIN Lock
  // ──────────────────────────────────────────────────────────────

  Future<void> _togglePinLock(bool enable) async {
    if (enable) {
      final pin = await _showPinSetupDialog();
      if (pin != null) {
        await _secureStorage.write(key: 'pin_code', value: pin);
        await _secureStorage.write(key: 'pin_lock_enabled', value: 'true');
        if (!mounted) return;
        setState(() => _pinEnabled = true);
      }
    } else {
      final verified = await _verifyCurrentPin();
      if (verified) {
        await _secureStorage.delete(key: 'pin_code');
        await _secureStorage.write(key: 'pin_lock_enabled', value: 'false');
        // Disable biometric as well
        await _secureStorage.write(key: 'biometric_enabled', value: 'false');
        if (!mounted) return;
        setState(() {
          _pinEnabled = false;
          _biometricEnabled = false;
        });
      } else {
        if (!mounted) return;
        // Revert switch — PIN verification failed or was cancelled
        setState(() {}); // rebuild to reset switch visually
      }
    }
  }

  /// Returns the PIN if set, or null.
  Future<String?> _showPinSetupDialog() async {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Set App PIN'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: c1,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Enter PIN (4-6 digits)',
                ),
                validator: (v) => (v != null && v.length >= 4 && v.length <= 6)
                    ? null
                    : 'PIN must be 4-6 digits',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: c2,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                ),
                validator: (v) => v == c1.text ? null : 'PINs do not match',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, c1.text);
              }
            },
            child: const Text('Set PIN'),
          ),
        ],
      ),
    );
  }

  Future<bool> _verifyCurrentPin() async {
    final storedPin = await _secureStorage.read(key: 'pin_code');
    if (storedPin == null) return true; // no pin set yet

    if (!mounted) return false;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Enter current PIN',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text == storedPin) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Incorrect PIN')),
                );
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  // ──────────────────────────────────────────────────────────────
  // Biometric
  // ──────────────────────────────────────────────────────────────

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isAvailable = await _localAuth.isDeviceSupported();
      if (!canCheck || !isAvailable) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Biometric authentication not available on this device.'),
          ),
        );
        setState(() {}); // revert switch
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to enable biometric unlock',
      );
      if (authenticated) {
        await _secureStorage.write(key: 'biometric_enabled', value: 'true');
        if (!mounted) return;
        setState(() => _biometricEnabled = true);
      } else {
        if (!mounted) return;
        setState(() {}); // revert
      }
    } else {
      await _secureStorage.write(key: 'biometric_enabled', value: 'false');
      if (!mounted) return;
      setState(() => _biometricEnabled = false);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Export CSV
  // ──────────────────────────────────────────────────────────────

  Future<void> _exportCsv() async {
    try {
      final storage = StorageService();
      final exportService = ExportService(storage);
      final transactions = storage.getAllTransactions();
      final csv = exportService.exportToCsv(transactions);
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/fintrack_export_$ts.csv');
      await file.writeAsString(csv);
      await exportService.shareFile(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Export PDF
  // ──────────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    try {
      final storage = StorageService();
      final exportService = ExportService(storage);
      final transactions = storage.getAllTransactions();
      if (transactions.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transactions to export.')),
        );
        return;
      }
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      final pdfPath = await exportService.exportToPdf(
        transactions: transactions,
        title: 'FinTrack Lite – Monthly Report',
        startDate: startDate,
        endDate: now,
      );
      final file = File(pdfPath);
      await exportService.shareFile(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Backup
  // ──────────────────────────────────────────────────────────────

  Future<void> _backupData() async {
    try {
      final backupService = BackupService();
      final dir = await getTemporaryDirectory();
      final path = await backupService.createBackup(directoryPath: dir.path);
      if (path == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup failed. Please try again.')),
        );
        return;
      }
      final file = File(path);
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup saved: ${file.path.split('/').last}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Restore
  // ──────────────────────────────────────────────────────────────

  Future<void> _restoreData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'To restore your data:\n\n'
          '1. Name your backup file "fintrack_backup.json"\n'
          '2. Place it in your device\'s Documents folder\n'
          '3. Tap "Restore" below\n\n'
          '⚠️ This will replace ALL existing data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/fintrack_backup.json');
      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup file not found at:\n${file.path}',
            ),
          ),
        );
        return;
      }

      final backupService = BackupService();
      final success = await backupService.restoreBackup(file);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data restored successfully!')),
        );
        // Force rebuild of dependent providers by invalidating them
        ref.invalidate(allTransactionsProvider);
        ref.invalidate(allCategoriesProvider);
        ref.invalidate(settingsProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore failed. Invalid backup file.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Delete All Data
  // ──────────────────────────────────────────────────────────────

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        var canDelete = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Delete All Data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently delete ALL transactions, categories, '
                  'budgets, and settings. This action cannot be undone.',
                  style: TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Type DELETE to confirm',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final valid = v == 'DELETE';
                    if (valid != canDelete) {
                      setDialogState(() => canDelete = valid);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: canDelete ? () => Navigator.pop(ctx, true) : null,
                child:
                    const Text('DELETE', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Clear all Hive boxes
      final categoriesBox = Hive.box<Category>('categories');
      final transactionsBox = Hive.box<Transaction>('transactions');
      final recurringBox = Hive.box('recurringRules');
      final budgetsBox = Hive.box('budgets');
      final settingsBox = Hive.box('settings');

      await categoriesBox.clear();
      await transactionsBox.clear();
      await recurringBox.clear();
      await budgetsBox.clear();
      await settingsBox.clear();

      // Re-seed default categories
      final storage = StorageService();
      await storage.initialize();

      // Clear secure storage PIN/biometric
      await _secureStorage.deleteAll();

      // Reset SharedPreferences theme/currency
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('themeMode');
      await prefs.remove('currency_code');

      // Reset providers
      ref.invalidate(themeModeProvider);
      ref.invalidate(settingsProvider);
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(allCategoriesProvider);

      if (!mounted) return;
      setState(() {
        _pinEnabled = false;
        _biometricEnabled = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data has been deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);
    final currencyCode = settings.currencyCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // ── APPEARANCE ───────────────────────────────────
          _sectionHeader('Appearance'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme'),
                  subtitle: Text(_themeName(themeMode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showThemePicker,
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Currency'),
                  subtitle: Text(
                    '$currencyCode (${_currencySymbol(currencyCode)})',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showCurrencyPicker,
                ),
              ],
            ),
          ),

          // ── SECURITY ─────────────────────────────────────
          const SizedBox(height: 16),
          _sectionHeader('Security'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('App Lock (PIN)'),
                  value: _pinEnabled,
                  onChanged: _togglePinLock,
                ),
                const Divider(height: 1, indent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometric Unlock'),
                  value: _biometricEnabled,
                  onChanged: _pinEnabled ? _toggleBiometric : null,
                ),
              ],
            ),
          ),

          // ── DATA MANAGEMENT ──────────────────────────────
          const SizedBox(height: 16),
          _sectionHeader('Data Management'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.table_chart),
                  title: const Text('Export to CSV'),
                  onTap: _exportCsv,
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('Export to PDF'),
                  onTap: _exportPdf,
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Backup Data'),
                  subtitle: const Text('Save all data as JSON'),
                  onTap: _backupData,
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('Restore Data'),
                  subtitle: const Text('Import from backup file'),
                  onTap: _restoreData,
                ),
              ],
            ),
          ),

          // ── ABOUT ────────────────────────────────────────
          const SizedBox(height: 16),
          _sectionHeader('About'),
          const Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About FinTrack Lite'),
                  subtitle: Text(
                    'A local-first expense tracker built with Flutter',
                  ),
                ),
                Divider(height: 1, indent: 16),
                ListTile(
                  leading: Icon(Icons.tag),
                  title: Text('Version'),
                  subtitle: Text('1.0.0'),
                ),
              ],
            ),
          ),

          // ── DANGER ZONE ──────────────────────────────────
          const SizedBox(height: 16),
          _sectionHeader('Danger Zone'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Delete All Data',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text(
                'This cannot be undone',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
              onTap: _deleteAllData,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
