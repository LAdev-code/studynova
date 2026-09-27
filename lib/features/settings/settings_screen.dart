import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/theme_service.dart';
import '../../services/paywall_manager.dart';
import '../../ui/paywall_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = S.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Subscription & Pro Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ValueListenableBuilder<bool>(
                valueListenable: PaywallManager.isProNotifier,
                builder: (context, isPro, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPro ? Icons.verified : Icons.stars_rounded,
                            color: isPro ? Colors.green : Colors.amber.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isPro ? 'Study Nova Pro' : 'Study Nova Free',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPro
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isPro ? 'ACTIVE' : 'FREE TIER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPro ? Colors.green : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isPro
                            ? 'All premium features unlocked: Unlimited TalkBack AI tutor, advanced materials, and more.'
                            : 'Upgrade to Study Nova Pro to unlock full AI voice tutoring and premium features.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (!isPro)
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => PaywallScreen.show(context),
                                icon: const Icon(Icons.bolt, size: 18),
                                label: const Text('Upgrade to Pro'),
                              ),
                            ),
                          if (isPro)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => PaywallScreen.showCustomerCenter(),
                                icon: const Icon(Icons.manage_accounts, size: 18),
                                label: const Text('Manage Subscription'),
                              ),
                            ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () async {
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Restoring purchases...'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                              await PaywallManager.restorePurchases();
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    PaywallManager.isProNotifier.value
                                        ? 'Purchases restored successfully!'
                                        : 'No active purchases found.',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Restore'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appearance,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeService.themeMode,
                    builder: (context, mode, _) {
                      return SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.darkMode),
                        value: mode == ThemeMode.dark,
                        onChanged: (value) {
                          ThemeService.toggleDarkMode(value);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.accentColor,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      _ColorOption(color: Colors.deepPurple),
                      _ColorOption(color: Colors.blue),
                      _ColorOption(color: Colors.teal),
                      _ColorOption(color: Colors.orange),
                      _ColorOption(color: Colors.pink),
                      _ColorOption(color: Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => ThemeService.changePrimaryColor(color),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
