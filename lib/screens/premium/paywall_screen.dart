import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../../services/billing_service.dart';
import '../../services/entitlement_service.dart';
import '../../theme/app_theme.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  static const _benefits = <({IconData icon, String title, String sub})>[
    (
      icon: Icons.insights_rounded,
      title: 'Progression analytics',
      sub: 'Strength charts, estimated 1RM trends, and personal records.',
    ),
    (
      icon: Icons.auto_awesome_rounded,
      title: 'Unlimited plan refreshes',
      sub: 'Regenerate workouts and swap diet meals as often as you like.',
    ),
    (
      icon: Icons.notifications_active_rounded,
      title: 'Smart reminders',
      sub: 'Workout-day nudges and streak-saver alerts tuned to your schedule.',
    ),
    (
      icon: Icons.favorite_rounded,
      title: 'Support development',
      sub: 'Help us keep building and ship new features faster.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entitlement = context.watch<EntitlementService>();
    final billing = context.watch<BillingService>();

    // Auto-close once entitlement is granted (after a successful purchase).
    if (entitlement.isPremium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('FitForge Premium')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryContainer, AppTheme.tertiary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Train smarter with Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Unlock analytics, unlimited plans, and smart reminders.',
                          style: TextStyle(color: Colors.white, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._benefits.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryContainer.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              b.icon,
                              color: AppTheme.primaryContainer,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  b.sub,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (billing.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      billing.error!,
                      style: TextStyle(color: colorScheme.error, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            _PurchaseActions(billing: billing),
          ],
        ),
      ),
    );
  }
}

class _PurchaseActions extends StatelessWidget {
  final BillingService billing;

  const _PurchaseActions({required this.billing});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget productButton(ProductDetails product, {bool primary = true}) {
      final label = '${product.title.split('(').first.trim()} · ${product.price}';
      final child = billing.purchasePending
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label);
      return SizedBox(
        width: double.infinity,
        child: primary
            ? FilledButton(
                onPressed: billing.purchasePending
                    ? null
                    : () => billing.buy(product),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: child,
              )
            : OutlinedButton(
                onPressed: billing.purchasePending
                    ? null
                    : () => billing.buy(product),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: child,
              ),
      );
    }

    final yearly = billing.productById(BillingService.yearlyId);
    final monthly = billing.productById(BillingService.monthlyId);
    final hasProducts = yearly != null || monthly != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (billing.isAvailable && hasProducts) ...[
            if (yearly != null) productButton(yearly),
            if (yearly != null && monthly != null) const SizedBox(height: 10),
            if (monthly != null) productButton(monthly, primary: yearly == null),
            const SizedBox(height: 8),
            const _PaymentMethodsNote(),
            TextButton(
              onPressed: () => billing.restore(),
              child: const Text('Restore purchase'),
            ),
          ] else ...[
            Text(
              billing.isAvailable
                  ? 'Subscription products arenʼt available yet. They appear once configured in the Play Console.'
                  : 'In-app purchases arenʼt available on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 10),
            // Dev/testing fallback so the premium UI is reachable before billing
            // products are live. Remove before production.
            OutlinedButton(
              onPressed: () =>
                  context.read<EntitlementService>().startPremium(),
              child: const Text('Unlock (testing)'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Communicates the available payment methods. On Android, the Google Play
/// checkout sheet offers UPI, cards, net banking and wallets — selected by the
/// user during purchase. (Play policy requires digital goods to use Play
/// Billing, so a separate UPI/card gateway is not used.)
class _PaymentMethodsNote extends StatelessWidget {
  const _PaymentMethodsNote();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_rounded,
                size: 13,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Secure payment via Google Play',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'UPI · Cards · Net banking · Wallets',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          Text(
            'Cancel anytime in Google Play subscriptions.',
            style: TextStyle(
              fontSize: 10.5,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
