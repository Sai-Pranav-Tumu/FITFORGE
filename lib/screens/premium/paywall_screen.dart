import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../../services/billing_service.dart';
import '../../services/entitlement_service.dart';
import '../../theme/app_theme.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _yearly = true;

  static const List<String> _proFeatures = [
    'Full 800+ exercise library with animated guides',
    'Adaptive engine — progressive overload & volume tuning',
    'All regions & cuisines, unlimited diet swaps & regens',
    'Full workout history + progress & strength charts',
    'Custom reminders · No ads',
  ];

  static const List<String> _maxFeatures = [
    'Everything in Pro, plus:',
    'AI diet recommender — the smartest, model-ranked plans',
    '1RM & volume analytics + CSV/PDF export',
    'Early access to new features + priority support',
    'Unlimited everything — no caps anywhere',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entitlement = context.watch<EntitlementService>();
    final billing = context.watch<BillingService>();

    // Auto-close once any paid tier is granted (after a successful purchase).
    if (entitlement.isPremium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      });
    }

    final proId = _yearly
        ? BillingService.proYearlyId
        : BillingService.proMonthlyId;
    final maxId = _yearly
        ? BillingService.maxYearlyId
        : BillingService.maxMonthlyId;
    final proProduct = billing.productById(proId);
    final maxProduct = billing.productById(maxId);

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade FitForge')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Train smarter. Eat better.',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick the plan that fits your goals. Cancel anytime.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _BillingPeriodToggle(
              yearly: _yearly,
              onChanged: (v) => setState(() => _yearly = v),
            ),
            const SizedBox(height: 18),
            _TierCard(
              title: 'Pro',
              tagline: 'The complete FitForge experience',
              accent: AppTheme.primaryContainer,
              features: _proFeatures,
              priceLabel: _priceLabel(proProduct),
              isCurrent: entitlement.tier == AppTier.pro,
              highlighted: false,
              onBuy: proProduct == null || billing.purchasePending
                  ? null
                  : () => billing.buy(proProduct),
              onDevUnlock: kDebugMode
                  ? () => context.read<EntitlementService>().setTier(AppTier.pro)
                  : null,
            ),
            const SizedBox(height: 14),
            _TierCard(
              title: 'Max',
              tagline: 'Ultimate access — every feature, no caps',
              accent: AppTheme.secondary,
              features: _maxFeatures,
              priceLabel: _priceLabel(maxProduct),
              isCurrent: entitlement.tier == AppTier.max,
              highlighted: true,
              onBuy: maxProduct == null || billing.purchasePending
                  ? null
                  : () => billing.buy(maxProduct),
              onDevUnlock: kDebugMode
                  ? () => context.read<EntitlementService>().setTier(AppTier.max)
                  : null,
            ),
            const SizedBox(height: 16),
            if (billing.error != null)
              Text(
                billing.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              ),
            if (!billing.isAvailable ||
                (proProduct == null && maxProduct == null))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  billing.isAvailable
                      ? 'Subscription products appear here once configured in the Play Console.'
                      : 'In-app purchases aren’t available on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            const _PaymentMethodsNote(),
            Center(
              child: TextButton(
                onPressed: () => billing.restore(),
                child: const Text('Restore purchase'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _priceLabel(ProductDetails? product) {
    if (product == null) return '—';
    return '${product.price} / ${_yearly ? 'year' : 'month'}';
  }
}

class _BillingPeriodToggle extends StatelessWidget {
  const _BillingPeriodToggle({required this.yearly, required this.onChanged});

  final bool yearly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget seg(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          seg('Monthly', !yearly, () => onChanged(false)),
          seg('Yearly · save more', yearly, () => onChanged(true)),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.title,
    required this.tagline,
    required this.accent,
    required this.features,
    required this.priceLabel,
    required this.isCurrent,
    required this.highlighted,
    required this.onBuy,
    required this.onDevUnlock,
  });

  final String title;
  final String tagline;
  final Color accent;
  final List<String> features;
  final String priceLabel;
  final bool isCurrent;
  final bool highlighted;
  final VoidCallback? onBuy;
  final VoidCallback? onDevUnlock;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted ? accent : colorScheme.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
              if (highlighted) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'BEST VALUE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (isCurrent)
                Text(
                  'Current',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            tagline,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(f, style: const TextStyle(height: 1.3)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isCurrent ? null : onBuy,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text(
                isCurrent ? 'Your current plan' : 'Choose $title · $priceLabel',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (onDevUnlock != null)
            Center(
              child: TextButton(
                onPressed: onDevUnlock,
                child: Text('Unlock $title (testing)'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Communicates the available payment methods. On Android, the Google Play
/// checkout sheet offers UPI, cards, net banking and wallets.
class _PaymentMethodsNote extends StatelessWidget {
  const _PaymentMethodsNote();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, size: 13, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Secure payment via Google Play',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'UPI · Cards · Net banking · Wallets · Cancel anytime',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
