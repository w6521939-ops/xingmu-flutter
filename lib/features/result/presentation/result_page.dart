import 'package:flutter/material.dart';

import '../../../presentation/models/studio_view_data.dart';
import '../../../shared/widgets/studio_widgets.dart';

class ResultExportOptions {
  const ResultExportOptions({
    required this.includeSubtitles,
    required this.includeWatermark,
  });

  final bool includeSubtitles;
  final bool includeWatermark;
}

class ResultPage extends StatefulWidget {
  const ResultPage({
    required this.result,
    required this.onPlay,
    required this.onDownload,
    required this.onShare,
    required this.onRegenerate,
    required this.onBackHome,
    required this.onNavigateStep,
    super.key,
    this.state = UiLoadState.ready,
    this.onRetry,
    this.demoMode = false,
    this.canPreview = false,
    this.canDownload = false,
    this.canShare = false,
    this.canConfigureExportOptions = false,
  });

  final ResultData result;
  final VoidCallback onPlay;
  final ValueChanged<ResultExportOptions> onDownload;
  final VoidCallback onShare;
  final VoidCallback onRegenerate;
  final VoidCallback onBackHome;
  final ValueChanged<StudioDestination> onNavigateStep;
  final UiLoadState state;
  final VoidCallback? onRetry;
  final bool demoMode;
  final bool canPreview;
  final bool canDownload;
  final bool canShare;
  final bool canConfigureExportOptions;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _includeSubtitles = false;
  bool _includeWatermark = false;

  @override
  Widget build(BuildContext context) {
    final resultAvailable = widget.result.ready && !widget.demoMode;
    final previewAvailable = resultAvailable && widget.canPreview;
    final downloadAvailable = resultAvailable && widget.canDownload;
    final shareAvailable = resultAvailable && widget.canShare;
    final exportOptionsAvailable =
        resultAvailable && widget.canConfigureExportOptions;
    return SingleChildScrollView(
      child: ResponsiveContent(
        maxWidth: 1120,
        child: StatePanel(
          state: widget.state,
          onRetry: widget.onRetry,
          emptyTitle: '成片还在路上',
          emptyMessage: '完成镜头、配音和字幕后，可在任务中心提交合成。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StudioStepBar(
                activeDestination: StudioDestination.result,
                onStepTap: widget.onNavigateStep,
              ),
              const SizedBox(height: 24),
              PageIntro(
                eyebrow: '06 · 成片结果',
                title: widget.demoMode
                    ? '演示占位成片'
                    : widget.result.ready
                    ? '服务端成片已就绪'
                    : '尚无可用成片',
                description: widget.demoMode
                    ? '以下封面、时长、文件大小与生成时间都是本地演示数据，不是模型生成成片。'
                    : widget.result.ready
                    ? '服务端已返回成片记录；当前客户端尚未接入播放器、文件下载、系统分享及字幕水印导出选项。'
                    : '服务端尚未返回可用成片。请到任务中心刷新或查看任务状态；本页不会推测合成阶段。',
                trailing: StatusPill(
                  status: widget.demoMode
                      ? GenerationStatus.draft
                      : widget.result.ready
                      ? GenerationStatus.completed
                      : GenerationStatus.draft,
                  label: widget.demoMode
                      ? '演示占位'
                      : widget.result.ready
                      ? '服务端已就绪'
                      : '未返回成片',
                ),
              ),
              if (widget.demoMode) ...[
                const SizedBox(height: 16),
                const InfoBanner(
                  icon: Icons.science_outlined,
                  title: '演示占位成片，不是真实结果',
                  message: '演示模式不调用视频模型，也没有可播放、下载或分享的 MP4 文件。',
                ),
              ],
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final preview = _ResultPreview(
                    result: widget.result,
                    demoMode: widget.demoMode,
                    canPreview: previewAvailable,
                    onPlay: widget.onPlay,
                  );
                  final details = _ResultDetails(
                    result: widget.result,
                    demoMode: widget.demoMode,
                    includeSubtitles: _includeSubtitles,
                    includeWatermark: _includeWatermark,
                    canConfigureExportOptions: exportOptionsAvailable,
                    onSubtitlesChanged: (value) =>
                        setState(() => _includeSubtitles = value),
                    onWatermarkChanged: (value) =>
                        setState(() => _includeWatermark = value),
                    onDownload: downloadAvailable
                        ? () => widget.onDownload(
                            ResultExportOptions(
                              includeSubtitles: _includeSubtitles,
                              includeWatermark: _includeWatermark,
                            ),
                          )
                        : null,
                    onShare: shareAvailable ? widget.onShare : null,
                  );
                  if (constraints.maxWidth < 780) {
                    return Column(
                      children: [preview, const SizedBox(height: 16), details],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: preview),
                      const SizedBox(width: 16),
                      Expanded(flex: 6, child: details),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              InfoBanner(
                icon: Icons.verified_user_outlined,
                title: '发布前请检查素材权利',
                message: '请确认上传的参考图、声音样本和音乐拥有可使用权；应用不会自动将作品发布到任何第三方平台。',
                tone: Colors.teal,
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onRegenerate,
                    icon: const Icon(Icons.video_settings_outlined),
                    label: const Text('返回修改镜头'),
                  ),
                  TextButton.icon(
                    onPressed: widget.onBackHome,
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('回到项目首页'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPreview extends StatelessWidget {
  const _ResultPreview({
    required this.result,
    required this.demoMode,
    required this.canPreview,
    required this.onPlay,
  });

  final ResultData result;
  final bool demoMode;
  final bool canPreview;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GeneratedArtwork(
                    title: result.title,
                    icon: Icons.local_fire_department_rounded,
                    color: const Color(0xFF263E69),
                    aspectRatio: 9 / 16,
                    badge: demoMode
                        ? '演示占位'
                        : !result.ready
                        ? '成片未返回'
                        : !canPreview
                        ? '预览未接入'
                        : result.durationLabel,
                  ),
                  IconButton.filled(
                    tooltip: demoMode
                        ? '演示占位不可播放'
                        : !result.ready
                        ? '服务端未返回可用成片'
                        : canPreview
                        ? '播放成片'
                        : '视频播放器尚未接入',
                    onPressed: canPreview ? onPlay : null,
                    iconSize: 36,
                    padding: const EdgeInsets.all(17),
                    icon: Icon(
                      canPreview
                          ? Icons.play_arrow_rounded
                          : demoMode
                          ? Icons.science_outlined
                          : result.ready
                          ? Icons.play_disabled_outlined
                          : Icons.video_file_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!result.ready && !demoMode) ...[
            const SizedBox(height: 14),
            const InfoBanner(
              icon: Icons.cloud_sync_outlined,
              title: '服务端尚未返回可用成片',
              message: '请到任务中心刷新或查看任务状态；此页不显示未经服务端确认的进度或阶段。',
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultDetails extends StatelessWidget {
  const _ResultDetails({
    required this.result,
    required this.demoMode,
    required this.includeSubtitles,
    required this.includeWatermark,
    required this.canConfigureExportOptions,
    required this.onSubtitlesChanged,
    required this.onWatermarkChanged,
    required this.onDownload,
    required this.onShare,
  });

  final ResultData result;
  final bool demoMode;
  final bool includeSubtitles;
  final bool includeWatermark;
  final bool canConfigureExportOptions;
  final ValueChanged<bool> onSubtitlesChanged;
  final ValueChanged<bool> onWatermarkChanged;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(result.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            result.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              MetricTile(
                icon: Icons.timer_outlined,
                value: result.durationLabel,
                label: '成片时长',
              ),
              MetricTile(
                icon: Icons.aspect_ratio_rounded,
                value: result.resolutionLabel,
                label: '分辨率',
              ),
              MetricTile(
                icon: Icons.sd_storage_outlined,
                value: result.sizeLabel,
                label: '文件大小',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: includeSubtitles,
            onChanged: canConfigureExportOptions ? onSubtitlesChanged : null,
            title: const Text('字幕导出选项（未接入）'),
            subtitle: const Text('当前开关不生效，客户端尚未提交字幕导出参数'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: includeWatermark,
            onChanged: canConfigureExportOptions ? onWatermarkChanged : null,
            title: const Text('水印导出选项（未接入）'),
            subtitle: const Text('当前开关不生效，客户端尚未提交水印导出参数'),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onDownload,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.download_rounded),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    demoMode
                        ? '演示占位不可下载'
                        : !result.ready
                        ? '服务端未返回成片'
                        : onDownload != null
                        ? '下载 MP4 成片'
                        : '文件下载尚未接入',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
            label: Text(
              demoMode
                  ? '演示占位不可分享'
                  : !result.ready
                  ? '服务端未返回成片'
                  : onShare != null
                  ? '使用系统分享'
                  : '系统分享尚未接入',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            demoMode
                ? '演示数据标注时间：${result.generatedAtLabel}'
                : '服务端记录时间：${result.generatedAtLabel}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
