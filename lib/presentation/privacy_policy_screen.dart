import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'widgets/shell.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CandyScaffold(
      title: 'Privacy Policy',
      onBack: () => Navigator.pop(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        physics: const BouncingScrollPhysics(),
        children: [
          CandyPanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: CandyText(
                    'PRIVACY POLICY',
                    size: 22,
                    color: CandyTheme.goldLight,
                    outlineWidth: 3,
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: CandyText(
                    'Last Updated: September 6, 2026',
                    size: 11,
                    display: false,
                    color: Colors.white70,
                    outlineWidth: 1.5,
                    dropShadow: false,
                  ),
                ),
                const SizedBox(height: 20),
                _paragraph(
                  'Welcome to Potion Sort Adventure! Your privacy is extremely important to us. This Privacy Policy explains how we handle information when you play our game.',
                ),
                _sectionHeader('1. NO PERSONAL DATA COLLECTED'),
                _paragraph(
                  'We do not collect, store, or share any personal information (such as your name, email address, phone number, location, or device identifiers). You can play the game completely anonymously.',
                ),
                _sectionHeader('2. LOCAL STORAGE & PROGRESS'),
                _paragraph(
                  'To provide a smooth gaming experience, we store your game progress, settings (such as music, sound effects, haptics, and accessibility options), and daily streak data locally on your device using local storage (SharedPreferences). This data stays entirely on your device and is never uploaded to our servers.',
                ),
                _sectionHeader('3. FUTURE FEATURES & THIRD PARTIES'),
                _paragraph(
                  'Currently, all gameplay is offline and local. In future updates, we may introduce cloud sync, advertisements, or in-app purchases. If we do, we may integrate trusted third-party SDKs (such as Google AdMob or Supabase) which may collect anonymous device identifiers or usage statistics. We will update this policy accordingly if those features are enabled.',
                ),
                _sectionHeader('4. CHILDREN\'S PRIVACY'),
                _paragraph(
                  'Potion Sort Adventure is a family-friendly puzzle game designed for players of all ages. Because we do not collect any personal information, we are fully compliant with COPPA (Children\'s Online Privacy Protection Act) and do not knowingly collect any data from children.',
                ),
                _sectionHeader('5. CONTACT US'),
                _paragraph(
                  'If you have any questions or suggestions about this Privacy Policy, feel free to contact us at:',
                ),
                const SizedBox(height: 8),
                const Center(
                  child: CandyText(
                    'support@lumenspark.com',
                    size: 14,
                    color: CandyTheme.goldLight,
                    outlineWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: CandyText(
        title,
        size: 13,
        color: CandyTheme.pinkLight,
        outlineWidth: 2,
        align: TextAlign.left,
      ),
    );
  }

  Widget _paragraph(String text) {
    return CandyText(
      text,
      size: 11,
      display: false,
      outlineWidth: 1.5,
      dropShadow: false,
      color: Colors.white.withValues(alpha: 0.9),
      align: TextAlign.left,
      height: 1.4,
    );
  }
}
