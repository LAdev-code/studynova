import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../services/paywall_manager.dart';

class PaywallScreen {
  /// Shows the RevenueCat Paywall UI configured in the dashboard.
  /// This will automatically handle product display and purchases.
  static Future<void> show(BuildContext context) async {
    try {
      // Use the modern presentPaywall method which uses the RevenueCat Dashboard configuration
      final paywallResult = await RevenueCatUI.presentPaywall(
        displayCloseButton: true,
      );
      
      debugPrint('Paywall result: $paywallResult');
      
      // Refresh status after paywall is closed
      await PaywallManager.refreshCustomerInfo();
    } catch (e) {
      debugPrint('Error presenting paywall: $e');
      
      String message = 'Could not load paywall. Please check your internet connection.';
      if (e.toString().contains('NetworkError')) {
        message = 'Network error: Please check your internet connection and try again.';
      }
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Connection Issue'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Shows the RevenueCat Customer Center for subscription management
  static Future<void> showCustomerCenter() async {
    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      debugPrint('Error presenting Customer Center: $e');
    }
  }
}
