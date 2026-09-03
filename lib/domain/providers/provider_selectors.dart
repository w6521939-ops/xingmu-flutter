import 'base_provider.dart';
import 'cost_table.dart';

class ScriptProvider extends BaseProvider {
  const ScriptProvider({
    required super.id,
    required super.name,
    required super.displayName,
    required super.defaultModel,
    super.supportedModels = const {},
  });

  @override
  Set<ProviderCapability> get capabilities => const {ScriptCapability()};

  @override
  Future<ProviderProbe> probe({String? apiKey}) async {
    if (apiKey == null || apiKey.isEmpty) {
      return const ProviderProbe(status: ProviderStatus.unavailable, detail: '未配置 API Key');
    }
    return const ProviderProbe(status: ProviderStatus.available);
  }

  @override
  CostEstimate estimateCost({
    required String modelId,
    required int quantity,
    String unit = '千token',
  }) {
    final amount = CostTable.estimate(modelId: modelId, quantity: quantity);
    return CostEstimate(
      currency: CostTable.getCurrency(modelId),
      amount: amount / quantity.clamp(1, 999999),
      unit: unit,
      quantity: quantity,
      total: amount,
    );
  }

  @override
  String get pricingNote => '按千 token 计费';
}

class ImageProvider extends BaseProvider {
  const ImageProvider({
    required super.id,
    required super.name,
    required super.displayName,
    required super.defaultModel,
    super.supportedModels = const {},
  });

  @override
  Set<ProviderCapability> get capabilities => const {ImageCapability()};

  @override
  Future<ProviderProbe> probe({String? apiKey}) async {
    if (apiKey == null || apiKey.isEmpty) {
      return const ProviderProbe(status: ProviderStatus.unavailable, detail: '未配置 API Key');
    }
    return const ProviderProbe(status: ProviderStatus.available);
  }

  @override
  CostEstimate estimateCost({
    required String modelId,
    required int quantity,
    String unit = '张',
  }) {
    final amount = CostTable.estimate(modelId: modelId, quantity: quantity);
    return CostEstimate(
      currency: CostTable.getCurrency(modelId),
      amount: amount / quantity.clamp(1, 999999),
      unit: unit,
      quantity: quantity,
      total: amount,
    );
  }

  @override
  String get pricingNote => '按张计费';
}

class VoiceProvider extends BaseProvider {
  const VoiceProvider({
    required super.id,
    required super.name,
    required super.displayName,
    required super.defaultModel,
    super.supportedModels = const {},
  });

  @override
  Set<ProviderCapability> get capabilities => const {VoiceCapability()};

  @override
  Future<ProviderProbe> probe({String? apiKey}) async {
    if (apiKey == null || apiKey.isEmpty) {
      return const ProviderProbe(status: ProviderStatus.unavailable, detail: '未配置 API Key');
    }
    return const ProviderProbe(status: ProviderStatus.available);
  }

  @override
  CostEstimate estimateCost({
    required String modelId,
    required int quantity,
    String unit = '万字',
  }) {
    final amount = CostTable.estimate(modelId: modelId, quantity: quantity);
    return CostEstimate(
      currency: CostTable.getCurrency(modelId),
      amount: amount / quantity.clamp(1, 999999),
      unit: unit,
      quantity: quantity,
      total: amount,
    );
  }

  @override
  String get pricingNote => '按万字计费';
}

class VideoProvider extends BaseProvider {
  const VideoProvider({
    required super.id,
    required super.name,
    required super.displayName,
    required super.defaultModel,
    super.supportedModels = const {},
  });

  @override
  Set<ProviderCapability> get capabilities => const {VideoCapability()};

  @override
  Future<ProviderProbe> probe({String? apiKey}) async {
    if (apiKey == null || apiKey.isEmpty) {
      return const ProviderProbe(status: ProviderStatus.unavailable, detail: '未配置 API Key');
    }
    return const ProviderProbe(status: ProviderStatus.available);
  }

  @override
  CostEstimate estimateCost({
    required String modelId,
    required int quantity,
    String unit = '秒',
  }) {
    final amount = CostTable.estimate(modelId: modelId, quantity: quantity);
    return CostEstimate(
      currency: CostTable.getCurrency(modelId),
      amount: amount / quantity.clamp(1, 999999),
      unit: unit,
      quantity: quantity,
      total: amount,
    );
  }

  @override
  String get pricingNote => '按秒计费';
}

class ScriptProviderSelector extends BaseProviderSelector<ScriptProvider> {
  static ScriptProviderSelector? _instance;

  static ScriptProviderSelector get instance =>
      _instance ??= ScriptProviderSelector._();

  ScriptProviderSelector._() {
    register(const ScriptProvider(
      id: 'bailian',
      name: '百炼',
      displayName: '阿里云百炼 · 通义千问',
      defaultModel: 'qwen-plus',
      supportedModels: {'qwen-plus', 'qwen-max'},
    ), primary: true);
    register(const ScriptProvider(
      id: 'deepseek',
      name: 'DeepSeek',
      displayName: '深度求索 · DeepSeek',
      defaultModel: 'deepseek-v4',
      supportedModels: {'deepseek-v4', 'deepseek-r1'},
    ));
    register(const ScriptProvider(
      id: 'kimi',
      name: 'Kimi',
      displayName: '月之暗面 · Kimi',
      defaultModel: 'kimi-k3',
      supportedModels: {'kimi-k3'},
    ));
  }

  static void reset() => _instance = null;
}

class ImageProviderSelector extends BaseProviderSelector<ImageProvider> {
  static ImageProviderSelector? _instance;

  static ImageProviderSelector get instance =>
      _instance ??= ImageProviderSelector._();

  ImageProviderSelector._() {
    register(const ImageProvider(
      id: 'bailian',
      name: '百炼',
      displayName: '阿里云百炼 · 通义万相',
      defaultModel: 'wan2.7',
      supportedModels: {'wan2.7'},
    ), primary: true);
    register(const ImageProvider(
      id: 'seedream',
      name: 'Seedream',
      displayName: '字节跳动 · 豆包 Seedream',
      defaultModel: 'seedream-5',
      supportedModels: {'seedream-5'},
    ));
  }

  static void reset() => _instance = null;
}

class VoiceProviderSelector extends BaseProviderSelector<VoiceProvider> {
  static VoiceProviderSelector? _instance;

  static VoiceProviderSelector get instance =>
      _instance ??= VoiceProviderSelector._();

  VoiceProviderSelector._() {
    register(const VoiceProvider(
      id: 'bailian',
      name: '百炼',
      displayName: '阿里云百炼 · 通义语音',
      defaultModel: 'qwen-tts',
      supportedModels: {'qwen-tts'},
    ), primary: true);
    register(const VoiceProvider(
      id: 'edge-tts',
      name: 'Edge TTS',
      displayName: '微软 Edge · 免费语音合成',
      defaultModel: 'edge-tts',
      supportedModels: {'edge-tts'},
    ));
  }

  static void reset() => _instance = null;
}

class VideoProviderSelector extends BaseProviderSelector<VideoProvider> {
  static VideoProviderSelector? _instance;

  static VideoProviderSelector get instance =>
      _instance ??= VideoProviderSelector._();

  VideoProviderSelector._() {
    register(const VideoProvider(
      id: 'bailian',
      name: '百炼',
      displayName: '阿里云百炼 · Wan 图生视频',
      defaultModel: 'wan2.7-i2v',
      supportedModels: {'wan2.7-i2v'},
    ), primary: true);
    register(const VideoProvider(
      id: 'kling',
      name: '可灵',
      displayName: '快手 · 可灵视频生成',
      defaultModel: 'kling-3',
      supportedModels: {'kling-3'},
    ));
  }

  static void reset() => _instance = null;
}

List<BaseProviderSelector> get allSelectors => [
  ScriptProviderSelector.instance,
  ImageProviderSelector.instance,
  VoiceProviderSelector.instance,
  VideoProviderSelector.instance,
];

Map<String, List<String>> listAvailableProviders() {
  return {
    'script': ScriptProviderSelector.instance.listAvailable(),
    'image': ImageProviderSelector.instance.listAvailable(),
    'voice': VoiceProviderSelector.instance.listAvailable(),
    'video': VideoProviderSelector.instance.listAvailable(),
  };
}

CostEstimate? estimateTaskCost({
  required String capability,
  required String modelId,
  required int quantity,
  String unit = '次',
}) {
  final selector = switch (capability) {
    'script' => ScriptProviderSelector.instance.activeProvider,
    'image' => ImageProviderSelector.instance.activeProvider,
    'voice' => VoiceProviderSelector.instance.activeProvider,
    'video' => VideoProviderSelector.instance.activeProvider,
    _ => null,
  };

  if (selector == null) return null;
  return selector.estimateCost(modelId: modelId, quantity: quantity, unit: unit);
}
