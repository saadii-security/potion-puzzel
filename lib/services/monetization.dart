/// Local stubs. Real ads / IAP / Supabase belong in later phases.
/// These methods never invent a completed backend.
class Monetization {
  static bool rewardedAvailable = false;
  static bool interstitialAvailable = false;
  static bool iapAvailable = false;

  static Future<bool> showRewarded(String reason) async {
    // No ad SDK wired. Caller must treat this as unavailable.
    return false;
  }

  static Future<bool> showInterstitial() async => false;

  static Future<bool> purchase(String sku) async => false;
}

class CloudSync {
  static bool configured = false;

  static Future<void> pull() async {}
  static Future<void> push() async {}
}
