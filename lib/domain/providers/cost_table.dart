class ProviderPricing {
  const ProviderPricing({
    required this.currency,
    required this.price,
    required this.unit,
    this.minCharge,
  });

  final String currency;
  final double price;
  final String unit;
  final double? minCharge;
}

class CostTable {
  const CostTable._();

  static const _pricing = <String, ProviderPricing>{
    'bailian-script': ProviderPricing(currency: 'CNY', price: 0.04, unit: '千token'),
    'bailian-image': ProviderPricing(currency: 'CNY', price: 0.16, unit: '张'),
    'bailian-voice': ProviderPricing(currency: 'CNY', price: 0.35, unit: '万字'),
    'bailian-video': ProviderPricing(currency: 'CNY', price: 0.50, unit: '秒'),
    'deepseek-v4': ProviderPricing(currency: 'CNY', price: 0.002, unit: '千token'),
    'deepseek-r1': ProviderPricing(currency: 'CNY', price: 0.016, unit: '千token'),
    'qwen-plus': ProviderPricing(currency: 'CNY', price: 0.04, unit: '千token'),
    'qwen-max': ProviderPricing(currency: 'CNY', price: 0.12, unit: '千token'),
    'wan2.7': ProviderPricing(currency: 'CNY', price: 0.16, unit: '张'),
    'wan2.7-i2v': ProviderPricing(currency: 'CNY', price: 0.50, unit: '秒'),
    'qwen-tts': ProviderPricing(currency: 'CNY', price: 0.35, unit: '万字'),
    'seedream-5': ProviderPricing(currency: 'CNY', price: 0.20, unit: '张'),
    'edge-tts': ProviderPricing(currency: 'CNY', price: 0.0, unit: '万字'),
    'kling-3': ProviderPricing(currency: 'CNY', price: 1.00, unit: '秒'),
    'kimi-k3': ProviderPricing(currency: 'CNY', price: 0.06, unit: '千token'),
    'gpt-5': ProviderPricing(currency: 'USD', price: 0.005, unit: '千token'),
  };

  static ProviderPricing? getPricing(String modelId) => _pricing[modelId];

  static double estimate({
    required String modelId,
    required int quantity,
    String unit = '次',
  }) {
    final pricing = _pricing[modelId];
    if (pricing == null) return 0;
    var cost = pricing.price * quantity;
    if (pricing.minCharge != null && cost < pricing.minCharge!) {
      cost = pricing.minCharge!;
    }
    return cost;
  }

  static String getCurrency(String modelId) =>
      _pricing[modelId]?.currency ?? 'CNY';

  static String formatCost(double amount, String currency) {
    if (currency == 'CNY') return '¥${amount.toStringAsFixed(2)}';
    if (currency == 'USD') return '\$${amount.toStringAsFixed(2)}';
    return '$currency ${amount.toStringAsFixed(2)}';
  }
}
