import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/theme/xingmu_theme.dart';
import '../../../shared/widgets/studio_widgets.dart';
import '../application/video_lab_controller.dart';
import '../domain/video_lab_models.dart';

class VideoLabPage extends StatefulWidget {
  const VideoLabPage({
    required this.controller,
    required this.baseUrlLabel,
    super.key,
    this.onCopyOfficialUrl,
    this.onOpenMediaUrl,
  });

  final VideoLabController controller;
  final String baseUrlLabel;
  final Future<void> Function(Uri uri, String label)? onCopyOfficialUrl;
  final Future<void> Function(Uri uri)? onOpenMediaUrl;

  @override
  State<VideoLabPage> createState() => _VideoLabPageState();
}

class _VideoLabPageState extends State<VideoLabPage> {
  late final TextEditingController _storyController;

  @override
  void initState() {
    super.initState();
    _storyController = TextEditingController(
      text: '月球快递员在风暴中送出最后一单，发现包裹里藏着返回地球的坐标。',
    );
  }

  @override
  void dispose() {
    _storyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => SingleChildScrollView(
        child: ResponsiveContent(
          maxWidth: 1080,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageIntro(
                eyebrow: 'MOTION COMIC · 3 SHOTS',
                title: '3 分镜视频漫剧',
                description: widget.controller.usesHybridShotVideoPipeline
                    ? '固定三个分镜的首尾帧，分别生成真实 MP4 视频片段，再合成为约 9 秒竖屏漫剧。脚本、首尾帧和配音仍为本地或预生成素材。'
                    : '本地模板只对固定图片做推拉、平移与转场合成，不是图生视频；选择后端标记为可用的 Wan 视频模型后，才会生成分镜 MP4。',
              ),
              const SizedBox(height: 18),
              _ConnectionBanner(
                controller: widget.controller,
                baseUrlLabel: widget.baseUrlLabel,
              ),
              const SizedBox(height: 18),
              _StoryCard(
                storyController: _storyController,
                controller: widget.controller,
              ),
              const SizedBox(height: 18),
              _ModelGrid(
                controller: widget.controller,
                onCopyOfficialUrl:
                    widget.onCopyOfficialUrl ??
                    (uri, label) => _copyOfficialUrl(context, uri, label),
              ),
              const SizedBox(height: 18),
              _TemplateBoundary(controller: widget.controller),
              const SizedBox(height: 18),
              const _ContinuityCard(),
              const SizedBox(height: 18),
              _GenerateCard(
                controller: widget.controller,
                onGenerate: () =>
                    widget.controller.generate(_storyController.text),
              ),
              if (widget.controller.job != null ||
                  widget.controller.errorMessage != null) ...[
                const SizedBox(height: 18),
                _JobResult(
                  controller: widget.controller,
                  onOpenMediaUrl: widget.onOpenMediaUrl,
                ),
              ],
              const SizedBox(height: 14),
              const InfoBanner(
                icon: Icons.verified_user_outlined,
                title: '密钥与支付边界',
                message:
                    '手机端不接收模型 API Key，也不代收费用。付费入口只复制厂商官方价格与充值说明；模型只有在可信后端目录标记为“可用”时才能选择和提交。',
                tone: XingmuTheme.cyanGlow,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _copyOfficialUrl(
    BuildContext context,
    Uri uri,
    String label,
  ) async {
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('已复制$label，请在系统浏览器打开')));
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.controller,
    required this.baseUrlLabel,
  });

  final VideoLabController controller;
  final String baseUrlLabel;

  @override
  Widget build(BuildContext context) {
    final configured = controller.isConfigured;
    return InfoBanner(
      icon: configured ? Icons.lan_rounded : Icons.cable_rounded,
      title: configured ? '漫剧服务已配置' : '尚未配置本地漫剧服务',
      message: configured
          ? '连接地址：$baseUrlLabel。手机只提交任务、轮询状态和预览同源结果。'
          : '先运行本地服务，再通过 --dart-define=VIDEO_LAB_URL=... 配置地址；未配置时仍可查看模型和官方付费入口。',
      tone: configured ? Colors.tealAccent : Colors.orangeAccent,
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.storyController, required this.controller});

  final TextEditingController storyController;
  final VideoLabController controller;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('1 · 故事设定', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '4–500 字。云端图片适配器接入后才会按故事重绘；当前本地画面固定。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('video-lab-story'),
            controller: storyController,
            minLines: 4,
            maxLines: 7,
            maxLength: 500,
            enabled: !controller.isBusy,
            decoration: const InputDecoration(
              labelText: '漫剧故事',
              hintText: '例如：月球快递员在风暴中送出最后一单……',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelGrid extends StatelessWidget {
  const _ModelGrid({required this.controller, required this.onCopyOfficialUrl});

  final VideoLabController controller;
  final Future<void> Function(Uri uri, String label) onCopyOfficialUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: '2 · 选择四类模型',
          subtitle: '目录中的“可用”状态来自可信后端；未就绪模型不能选择，但仍可查看官方计费说明。',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 2 : 1;
            final spacing = 12.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: width,
                  child: _ModelPicker(
                    pickerKey: 'text',
                    title: '脚本模型',
                    icon: Icons.description_outlined,
                    models: controller.catalog.textModels,
                    selectedId: controller.selectedTextModelId,
                    enabled: !controller.isBusy,
                    onSelected: controller.selectTextModel,
                    onCopyOfficialUrl: onCopyOfficialUrl,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _ModelPicker(
                    pickerKey: 'image',
                    title: '图片模型',
                    icon: Icons.image_outlined,
                    models: controller.catalog.imageModels,
                    selectedId: controller.selectedImageModelId,
                    enabled: !controller.isBusy,
                    onSelected: controller.selectImageModel,
                    onCopyOfficialUrl: onCopyOfficialUrl,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _ModelPicker(
                    pickerKey: 'video',
                    title: '视频模型',
                    icon: Icons.movie_creation_outlined,
                    models: controller.catalog.videoModels,
                    selectedId: controller.selectedVideoModelId,
                    enabled: !controller.isBusy,
                    onSelected: controller.selectVideoModel,
                    onCopyOfficialUrl: onCopyOfficialUrl,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _ModelPicker(
                    pickerKey: 'voice',
                    title: '声音模型',
                    icon: Icons.record_voice_over_outlined,
                    models: controller.catalog.voiceModels,
                    selectedId: controller.selectedVoiceModelId,
                    enabled: !controller.isBusy,
                    onSelected: controller.selectVoiceModel,
                    onCopyOfficialUrl: onCopyOfficialUrl,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ModelPicker extends StatelessWidget {
  const _ModelPicker({
    required this.pickerKey,
    required this.title,
    required this.icon,
    required this.models,
    required this.selectedId,
    required this.enabled,
    required this.onSelected,
    required this.onCopyOfficialUrl,
  });

  final String pickerKey;
  final String title;
  final IconData icon;
  final List<VideoLabModel> models;
  final String selectedId;
  final bool enabled;
  final ValueChanged<String> onSelected;
  final Future<void> Function(Uri uri, String label) onCopyOfficialUrl;

  @override
  Widget build(BuildContext context) {
    final selected = models.firstWhere((model) => model.id == selectedId);
    final scheme = Theme.of(context).colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _ModelBadge(model: selected),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            key: ValueKey('model-picker-$pickerKey-$selectedId'),
            children: [
              for (final model in models)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _InlineModelOption(
                    key: ValueKey('model-option-$pickerKey-${model.id}'),
                    model: model,
                    selected: model.id == selectedId,
                    enabled: enabled && model.canGenerate,
                    onTap: () => onSelected(model.id),
                    onCopyOfficialUrl: onCopyOfficialUrl,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            selected.description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 7),
          Text(
            selected.canGenerate
                ? '当前服务可用 · ${selected.provider}'
                : '后端适配器待接入 · ${selected.provider}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected.canGenerate
                  ? Colors.tealAccent
                  : Colors.orangeAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineModelOption extends StatelessWidget {
  const _InlineModelOption({
    super.key,
    required this.model,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.onCopyOfficialUrl,
  });

  final VideoLabModel model;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Future<void> Function(Uri uri, String label) onCopyOfficialUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected
        ? scheme.primary
        : scheme.outlineVariant.withValues(alpha: .7);
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: .38)
          : scheme.surfaceContainerHighest.withValues(alpha: .26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 19,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      model.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    model.canGenerate ? '可选' : '后端未就绪',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: model.canGenerate
                          ? Colors.tealAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
              if (model.isPaid) ...[
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (model.pricingUrl != null)
                      OutlinedButton.icon(
                        key: ValueKey('pricing-${model.id}'),
                        onPressed: () =>
                            onCopyOfficialUrl(model.pricingUrl!, '官方计费说明'),
                        icon: const Icon(Icons.price_check_rounded, size: 17),
                        label: const Text('官方计费'),
                      ),
                    if (model.billingUrl != null)
                      OutlinedButton.icon(
                        key: ValueKey('billing-${model.id}'),
                        onPressed: () =>
                            onCopyOfficialUrl(model.billingUrl!, '官方充值入口'),
                        icon: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 17,
                        ),
                        label: const Text('充值入口'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelBadge extends StatelessWidget {
  const _ModelBadge({required this.model});

  final VideoLabModel model;

  @override
  Widget build(BuildContext context) {
    final color = model.isPaid ? Colors.amberAccent : Colors.tealAccent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          model.isPaid ? '付费' : '免费',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TemplateBoundary extends StatelessWidget {
  const _TemplateBoundary({required this.controller});

  final VideoLabController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.usesHybridShotVideoPipeline) {
      return const InfoBanner(
        icon: Icons.movie_creation_outlined,
        title: '仅分镜视频在本次任务中由云模型生成',
        message:
            '脚本为本地模板，首尾帧来自预生成固定项目素材，配音为本地慧慧；Wan 只根据每个分镜的首帧与尾帧生成 MP4 视频片段，最后再合片。',
        tone: XingmuTheme.cyanGlow,
      );
    }
    if (!controller.usesFixedMoonCourierAssets) {
      return const InfoBanner(
        icon: Icons.cloud_off_outlined,
        title: '当前模型组合不能执行',
        message: '请只选择可信后端目录中标记为“可用”的模型；付费入口仅用于查看官方说明。',
        tone: Colors.orangeAccent,
      );
    }
    return const InfoBanner(
      icon: Icons.warning_amber_rounded,
      title: '固定图片运镜模板，不是分镜图生视频',
      message: '本地 FFmpeg 只对《月背最后一单》的固定图片做推拉、平移、转场和字幕合成；不会按故事重绘，也不会生成画面中的真实动作。',
      tone: Colors.orangeAccent,
    );
  }
}

class _ContinuityCard extends StatelessWidget {
  const _ContinuityCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('3 · 角色连续性', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          Text(
            '云端漫剧流水线必须遵守以下规则；本地模板使用同一组固定素材模拟这套结构。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 13),
          const _ContinuityLine(
            icon: Icons.badge_outlined,
            title: '先固定角色、道具、场景标准参考图',
          ),
          const _ContinuityLine(
            icon: Icons.low_priority_rounded,
            title: '每次引用顺序固定为：角色 → 道具 → 场景',
          ),
          const _ContinuityLine(
            icon: Icons.compare_rounded,
            title: '每个镜头先生成明确首帧与尾帧，再生成视频',
          ),
        ],
      ),
    );
  }
}

class _ContinuityLine extends StatelessWidget {
  const _ContinuityLine({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 9),
          Expanded(child: Text(title)),
        ],
      ),
    );
  }
}

class _GenerateCard extends StatelessWidget {
  const _GenerateCard({required this.controller, required this.onGenerate});

  final VideoLabController controller;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final blockedByModel = controller.selectedModels.any(
      (model) => !model.canGenerate,
    );
    final pipelineBlocked =
        !blockedByModel &&
        controller.selectedPipeline != null &&
        !controller.usesRunnableComicPipeline;
    final unsupportedCombination =
        !blockedByModel && controller.selectedPipeline == null;
    final isShotVideo = controller.usesHybridShotVideoPipeline;
    return SurfaceCard(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: .34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('4 · 生成漫剧', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          Text(
            !controller.isConfigured
                ? '启动并配置本地漫剧服务后才能提交任务。'
                : !controller.hasLoadedCatalog
                ? '模型目录尚未成功加载，请先恢复本地漫剧服务连接。'
                : blockedByModel
                ? '所选云模型的后端适配器待接入，当前不能生成；可查看官方付费说明或切回本地组合。'
                : pipelineBlocked
                ? '单个模型已就绪，但所选漫剧流水线仍被后端标记为未就绪，当前不能提交。'
                : unsupportedCombination
                ? '所选模型不能组成当前服务支持的漫剧流水线。'
                : isShotVideo
                ? '将分别提交 3 个分镜的首尾帧，生成 3 条真实 MP4 视频片段，再拼接为 9:16 漫剧成片。'
                : '将固定图片合成为 3 段运镜模板并导出 MP4/GIF；这是模板合成，不是图生视频。',
          ),
          const SizedBox(height: 15),
          FilledButton.icon(
            key: const ValueKey('video-lab-generate'),
            onPressed: controller.canGenerate ? onGenerate : null,
            icon: controller.isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_motion_rounded),
            label: Text(
              controller.isBusy
                  ? (isShotVideo ? '正在生成分镜视频…' : '正在合成模板…')
                  : (isShotVideo ? '生成 3 个分镜视频并合片' : '合成本地运镜模板'),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobResult extends StatelessWidget {
  const _JobResult({required this.controller, this.onOpenMediaUrl});

  final VideoLabController controller;
  final Future<void> Function(Uri uri)? onOpenMediaUrl;

  @override
  Widget build(BuildContext context) {
    final job = controller.job;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('生成进度与结果', style: Theme.of(context).textTheme.titleLarge),
              if (job != null) Chip(label: Text(_statusLabel(job.status))),
              if (job != null) _ExecutionBadge(job: job),
            ],
          ),
          if (controller.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              controller.errorMessage!,
              key: const ValueKey('video-lab-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (job != null) ...[
            const SizedBox(height: 14),
            ProgressStrip(
              value: job.progress,
              label: _stageLabel(job.stageCode),
            ),
            const SizedBox(height: 14),
            InfoBanner(
              icon: job.generatedForRequest
                  ? Icons.auto_awesome_rounded
                  : Icons.movie_filter_outlined,
              title: job.executionKind == VideoLabExecutionKind.template
                  ? '本次任务未调用AI · 使用预生成的项目固定ImageGen素材'
                  : job.executionKind == VideoLabExecutionKind.hybrid
                  ? '本次仅分镜视频动态调用AI生成'
                  : job.generatedForRequest
                  ? '本次任务已调用AI生成'
                  : '本次任务未调用AI',
              message: job.executionKind == VideoLabExecutionKind.template
                  ? '未按story重绘；视觉来源：${job.visualSource}（固定项目素材）；'
                        '素材来源：${job.assetProvenance}。'
                        '素材包含预生成的ImageGen项目资产。模板故事：${job.templateStoryTitle}。${job.visualWarning}'
                  : job.executionKind == VideoLabExecutionKind.hybrid
                  ? '脚本与配音为本地执行，首尾帧来自预生成固定项目素材；只有每个分镜的 MP4 动态由云视频模型在本次任务生成。${job.visualWarning}'
                  : '视觉来源：${job.visualSource}；'
                        '素材${job.containsAiGeneratedAssets ? '包含' : '不包含'}AI生成资产；'
                        '素材来源：${job.assetProvenance}。模板故事：${job.templateStoryTitle}。${job.visualWarning}',
              tone: job.generatedForRequest
                  ? XingmuTheme.cyanGlow
                  : Colors.orangeAccent,
            ),
            if (job.modelExecution != null) ...[
              const SizedBox(height: 12),
              _ModelExecutionDisclosure(execution: job.modelExecution!),
            ],
            const SizedBox(height: 15),
            SectionHeader(
              title:
                  job.output?.isShotVideoComposition == true ||
                      job.modelExecution?.generatesShotVideos == true
                  ? '3 个分镜视频'
                  : '3 个模板镜头',
              subtitle: job.modelExecution?.generatesShotVideos == true
                  ? '每个分镜独立展示首尾帧、远端视频任务状态、进度和成功 MP4。'
                  : '固定图片运镜只报告模板合成进度，不称为图生视频。',
            ),
            const SizedBox(height: 9),
            for (var index = 0; index < job.shots.length; index++) ...[
              _ShotProgressCard(
                index: index,
                shot: job.shots[index],
                onOpenMediaUrl: onOpenMediaUrl,
              ),
              if (index != job.shots.length - 1) const SizedBox(height: 9),
            ],
            if (job.previewUrl != null &&
                job.output?.isShotVideoComposition != true) ...[
              const SizedBox(height: 16),
              Text(
                '模板 GIF 动态预览（不是分镜视频）',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ColoredBox(
                    color: Colors.black,
                    child: Image.network(
                      job.previewUrl.toString(),
                      key: const ValueKey('video-lab-preview'),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('模板 GIF 加载失败，可复制 MP4 地址检查。'),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ],
            if (job.videoUrl != null) ...[
              const SizedBox(height: 14),
              _Mp4ResultCard(
                key: const ValueKey('final-mp4-result'),
                title: job.output?.isShotVideoComposition == true
                    ? '分镜视频合片 MP4'
                    : '模板合成 MP4',
                description: job.output?.isShotVideoComposition == true
                    ? '${job.output!.sourceClipCount} 个独立分镜 MP4 已按顺序合片；这不是 GIF，也不是固定图片运镜冒充的视频。'
                    : '该 MP4 来自固定图片的运镜与转场模板，不代表画面动作由视频模型生成。',
                videoUrl: job.videoUrl!,
                copyKey: const ValueKey('copy-video-url'),
                openKey: const ValueKey('open-video-url'),
                onOpenMediaUrl: onOpenMediaUrl,
                thumbnailUrl: job.shots.first.firstFrameUrl,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ExecutionBadge extends StatelessWidget {
  const _ExecutionBadge({required this.job});

  final VideoLabJob job;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (job.executionKind) {
      VideoLabExecutionKind.template => (
        '本地模板 · 固定项目素材 · story未重绘',
        Colors.orangeAccent,
      ),
      VideoLabExecutionKind.cloudAi => (
        '云端 AI · 本次按story生成',
        XingmuTheme.cyanGlow,
      ),
      VideoLabExecutionKind.hybrid => ('混合流水线 · 仅视频云生成', Colors.purpleAccent),
    };
    return Chip(
      key: const ValueKey('execution-kind'),
      avatar: Icon(
        job.generatedForRequest
            ? Icons.auto_awesome_rounded
            : Icons.movie_filter_outlined,
        size: 17,
        color: color,
      ),
      label: Text(label),
    );
  }
}

class _ModelExecutionDisclosure extends StatelessWidget {
  const _ModelExecutionDisclosure({required this.execution});

  final VideoLabModelExecution execution;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('本次各能力实际执行来源', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ExecutionSourceChip(label: '脚本', source: execution.text),
                _ExecutionSourceChip(label: '画面', source: execution.image),
                _ExecutionSourceChip(label: '视频', source: execution.video),
                _ExecutionSourceChip(label: '配音', source: execution.voice),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExecutionSourceChip extends StatelessWidget {
  const _ExecutionSourceChip({required this.label, required this.source});

  final String label;
  final VideoLabExecutionSource source;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = switch (source) {
      VideoLabExecutionSource.local => '本地执行',
      VideoLabExecutionSource.preGenerated => '预生成固定素材',
      VideoLabExecutionSource.cloud => '本次云端生成',
      VideoLabExecutionSource.notExecuted => '未执行',
    };
    return Chip(label: Text('$label · $sourceLabel'));
  }
}

class _ShotProgressCard extends StatelessWidget {
  const _ShotProgressCard({
    required this.index,
    required this.shot,
    this.onOpenMediaUrl,
  });

  final int index;
  final VideoLabShot shot;
  final Future<void> Function(Uri uri)? onOpenMediaUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: ValueKey('shot-progress-${shot.id}'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 30,
                    child: Center(child: Text('${index + 1}')),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    shot.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  '${(shot.progress * 100).round()}%',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 9),
            LinearProgressIndicator(value: shot.progress, minHeight: 6),
            const SizedBox(height: 7),
            Text(
              '${_statusLabel(shot.status)} · ${_stageLabel(shot.stageCode)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (shot.motionPrompt != null) ...[
              const SizedBox(height: 10),
              Text(
                '动作说明：${shot.motionPrompt}',
                key: ValueKey('shot-motion-${shot.id}'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (shot.hasFramePair) ...[
              const SizedBox(height: 12),
              _ShotFramePair(shot: shot),
            ],
            if (shot.videoTask != null) ...[
              const SizedBox(height: 12),
              _RemoteVideoTaskCard(
                shotId: shot.id,
                task: shot.videoTask!,
                thumbnailUrl: shot.firstFrameUrl,
                onOpenMediaUrl: onOpenMediaUrl,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShotFramePair extends StatelessWidget {
  const _ShotFramePair({required this.shot});

  final VideoLabShot shot;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _FramePreview(
            key: ValueKey('shot-first-frame-${shot.id}'),
            label: '首帧',
            imageUrl: shot.firstFrameUrl!,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FramePreview(
            key: ValueKey('shot-last-frame-${shot.id}'),
            label: '尾帧',
            imageUrl: shot.lastFrameUrl!,
          ),
        ),
      ],
    );
  }
}

class _FramePreview extends StatelessWidget {
  const _FramePreview({super.key, required this.label, required this.imageUrl});

  final String label;
  final Uri imageUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Image.network(
                imageUrl.toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '$label加载失败',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RemoteVideoTaskCard extends StatelessWidget {
  const _RemoteVideoTaskCard({
    required this.shotId,
    required this.task,
    required this.thumbnailUrl,
    this.onOpenMediaUrl,
  });

  final String shotId;
  final VideoLabShotVideoTask task;
  final Uri? thumbnailUrl;
  final Future<void> Function(Uri uri)? onOpenMediaUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: ValueKey('shot-video-task-$shotId'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_sync_outlined, size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '远端分镜视频任务',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text('${(task.progress * 100).round()}%'),
              ],
            ),
            if (task.remoteTaskId != null) ...[
              const SizedBox(height: 5),
              Text(
                '任务 ${task.remoteTaskId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            const SizedBox(height: 8),
            LinearProgressIndicator(value: task.progress, minHeight: 6),
            const SizedBox(height: 7),
            Text(_statusLabel(task.status)),
            if (task.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                task.errorMessage!,
                key: ValueKey('shot-video-error-$shotId'),
                style: TextStyle(color: scheme.error),
              ),
            ],
            if (task.videoUrl != null) ...[
              const SizedBox(height: 10),
              _Mp4ResultCard(
                title: '真实图生视频 MP4 已生成',
                description: '这是该分镜的视频模型输出片段，将作为最终合片源。',
                videoUrl: task.videoUrl!,
                thumbnailUrl: thumbnailUrl,
                copyKey: ValueKey('copy-shot-video-$shotId'),
                openKey: ValueKey('open-shot-video-$shotId'),
                onOpenMediaUrl: onOpenMediaUrl,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Mp4ResultCard extends StatelessWidget {
  const _Mp4ResultCard({
    super.key,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.copyKey,
    required this.openKey,
    this.thumbnailUrl,
    this.onOpenMediaUrl,
  });

  final String title;
  final String description;
  final Uri videoUrl;
  final Uri? thumbnailUrl;
  final Key copyKey;
  final Key openKey;
  final Future<void> Function(Uri uri)? onOpenMediaUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (thumbnailUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        thumbnailUrl.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            ColoredBox(color: scheme.surfaceContainerHigh),
                      ),
                      const ColoredBox(color: Color(0x44000000)),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 5),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              videoUrl.toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onOpenMediaUrl != null)
                  FilledButton.tonalIcon(
                    key: openKey,
                    onPressed: () => onOpenMediaUrl!(videoUrl),
                    icon: const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('播放 MP4'),
                  ),
                OutlinedButton.icon(
                  key: copyKey,
                  onPressed: () => _copyVideoUrl(context, videoUrl),
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: const Text('复制 MP4 地址'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _copyVideoUrl(BuildContext context, Uri uri) async {
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已复制 MP4 地址')));
  }
}

String _statusLabel(VideoLabJobStatus status) => switch (status) {
  VideoLabJobStatus.queued => '排队中',
  VideoLabJobStatus.running => '生成中',
  VideoLabJobStatus.succeeded => '已完成',
  VideoLabJobStatus.failed => '失败',
};

String _stageLabel(String code) => switch (code) {
  'queued' => '等待执行',
  'preparing' => '准备固定三镜头模板',
  'script' || 'storyboard' => '生成三镜头脚本',
  'assets' || 'preparing_assets' => '准备角色、道具与场景',
  'frames' || 'storyboard_frames' => '生成镜头首尾帧',
  'voice' || 'synthesizing_voice' => '生成角色对白',
  'video' || 'rendering_shot' || 'rendering_shots' => '合成动态镜头',
  'composing' => '拼接三镜头',
  'generating_preview' => '生成动图预览',
  'verifying' => '校验漫剧成片',
  'export' || 'exporting' => '合成竖屏成片',
  'completed' || 'succeeded' => '漫剧已完成',
  'failed' => '生成失败',
  _ => '阶段：$code',
};
