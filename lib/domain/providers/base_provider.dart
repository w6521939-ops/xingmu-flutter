abstract class ProviderCapability {
  const ProviderCapability();
}

class ScriptCapability extends ProviderCapability {
  const ScriptCapability();
}

class ImageCapability extends ProviderCapability {
  const ImageCapability();
}

class VoiceCapability extends ProviderCapability {
  const VoiceCapability();
}

class VideoCapability extends ProviderCapability {
  const VideoCapability();
}

enum ProviderStatus { available, unavailable, unknown }

class ProviderProbe {
  const ProviderProbe({
    required this.status,
    this.latencyMs,
    this.detail,
  });

  final ProviderStatus status;
  final int? latencyMs;
  final String? detail;

  bool get isAvailable => status == ProviderStatus.available;
}

class CostEstimate {
  const CostEstimate({
    required this.currency,
    required this.amount,
    required this.unit,
    required this.quantity,
    required this.total,
  });

  final String currency;
  final double amount;
  final String unit;
  final int quantity;
  final double total;

  String get formattedTotal {
    if (currency == 'CNY') return '¥${total.toStringAsFixed(2)}';
    if (currency == 'USD') return '\$${total.toStringAsFixed(2)}';
    return '$currency ${total.toStringAsFixed(2)}';
  }
}

abstract class BaseProvider {
  String get id;
  String get name;
  String get displayName;
  Set<ProviderCapability> get capabilities;
  Set<String> get supportedModels;
  String get defaultModel;

  Future<ProviderProbe> probe({String? apiKey});

  CostEstimate estimateCost({
    required String modelId,
    required int quantity,
    String unit = '次',
  });

  String get pricingNote;
}

abstract class BaseProviderSelector<T extends BaseProvider> {
  final Map<String, T> _providers = {};
  final List<String> _priority = [];

  void register(T provider, {bool primary = false}) {
    _providers[provider.id] = provider;
    if (primary || _priority.isEmpty) {
      if (!_priority.contains(provider.id)) _priority.insert(0, provider.id);
    } else {
      if (!_priority.contains(provider.id)) _priority.add(provider.id);
    }
  }

  List<T> get availableProviders => _priority
      .map((id) => _providers[id])
      .whereType<T>()
      .toList();

  T? get activeProvider => _providers[_priority.firstOrNull];

  String? get activeProviderId => _priority.firstOrNull;

  T? getProvider(String id) => _providers[id];

  void setActive(String id) {
    if (_providers.containsKey(id) && _priority.remove(id)) {
      _priority.insert(0, id);
    }
  }

  Future<T?> resolveActive({String? apiKey}) async {
    for (final id in List.of(_priority)) {
      final provider = _providers[id];
      if (provider == null) continue;
      final probe = await provider.probe(apiKey: apiKey);
      if (probe.isAvailable) return provider;
    }
    return null;
  }

  List<String> listAvailable() => _priority.toList();
}
