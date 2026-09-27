import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PaywallManager {
  // RevenueCat Public API Keys & Entitlement ID
  // Passed via --dart-define-from-file=api_keys.json or --dart-define=RC_GOOGLE_KEY=...
  static const String googleApiKey = String.fromEnvironment('RC_GOOGLE_KEY');
  static const String appleApiKey = String.fromEnvironment('RC_APPLE_KEY');

  /// The entitlement ID configured in your RevenueCat Dashboard.
  /// Standard identifier used for Shipathon submissions.
  static const String entitlementId = String.fromEnvironment(
    'RC_ENTITLEMENT_ID',
    defaultValue: 'APP HATCH Pro',
  );

  /// Global notifier for subscription status.
  /// Defaults to false so subscription check is properly enforced.
  static final ValueNotifier<bool> isProNotifier = ValueNotifier<bool>(false);

  /// Whether the SDK was initialized successfully.
  static bool _isConfigured = false;
  static bool get isConfigured => _isConfigured;

  /// Initialize RevenueCat SDK
  static Future<void> init() async {
    try {
      if (kIsWeb) {
        debugPrint('RevenueCat Purchases is not supported on web.');
        return;
      }

      String apiKey = '';
      if (Platform.isAndroid) {
        apiKey = googleApiKey;
      } else if (Platform.isIOS || Platform.isMacOS) {
        apiKey = appleApiKey;
      }

      if (apiKey.isEmpty) {
        debugPrint('No RevenueCat API key configured for platform.');
        return;
      }

      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      final configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);
      _isConfigured = true;

      // Listen to customer info updates in real-time
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updateProStatus(customerInfo);
      });

      // Initial check
      await refreshCustomerInfo();
      debugPrint('RevenueCat initialized successfully. Pro = ${isProNotifier.value}');
    } catch (e) {
      debugPrint('Error initializing RevenueCat: $e');
    }
  }

  /// Manually refresh customer info and update status
  static Future<void> refreshCustomerInfo() async {
    if (!_isConfigured) return;
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      _updateProStatus(customerInfo);
    } catch (e) {
      debugPrint('Error fetching customer info: $e');
    }
  }

  static void _updateProStatus(CustomerInfo customerInfo) {
    // Check if the primary entitlement is active
    final entitlement = customerInfo.entitlements.all[entitlementId];
    bool isActive = entitlement?.isActive ?? false;

    // Fallback: If any active entitlement exists, consider user Pro
    if (!isActive && customerInfo.entitlements.active.isNotEmpty) {
      isActive = true;
    }

    isProNotifier.value = isActive;
    debugPrint('Subscription Status Updated: Pro = $isActive (Active Entitlements: ${customerInfo.entitlements.active.keys.toList()})');
  }

  /// Purchase a package
  static Future<bool> purchasePackage(Package package) async {
    if (!_isConfigured) return false;
    try {
      final purchaseResult = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      _updateProStatus(purchaseResult.customerInfo);
      return isProNotifier.value;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('Purchase Error: ${e.message}');
      }
      return false;
    } catch (e) {
      debugPrint('Unexpected Purchase Error: $e');
      return false;
    }
  }

  /// Restore purchases
  static Future<bool> restorePurchases() async {
    if (!_isConfigured) return false;
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      _updateProStatus(customerInfo);
      return isProNotifier.value;
    } on PlatformException catch (e) {
      debugPrint('Restore Error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Unexpected Restore Error: $e');
      return false;
    }
  }

  /// Fetch current offerings (Monthly, Yearly, Lifetime)
  static Future<Offerings?> getOfferings() async {
    if (!_isConfigured) return null;
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (e) {
      debugPrint('Error fetching offerings: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Unexpected offerings error: $e');
      return null;
    }
  }
}

