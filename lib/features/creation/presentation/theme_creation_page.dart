import 'package:flutter/material.dart';

import '../../../presentation/models/studio_view_data.dart';
import '../../../shared/widgets/studio_widgets.dart';

class CreationDraft {
  const CreationDraft({
    required this.title,
    required this.idea,
    required this.genre,
    required this.visualStyle,
    required this.aspectRatio,
    required this.durationSeconds,
  });

  final String title;
  final String idea;
  final String genre;
  final String visualStyle;
  final String aspectRatio;
  final int durationSeconds;
}

class ThemeCreationPage extends StatefulWidget {
  const ThemeCreationPage({
    required this.onSaveDraft,
    required this.onGenerateScript,
    super.key,
    this.state = UiLoadState.ready,
    this.onRetry,
    this.initialTitle = '',
    this.initialIdea = '',
    this.canSaveDraft = false,
  });

  final ValueChanged<CreationDraft> onSaveDraft;
  final ValueChanged<CreationDraft> onGenerateScript;
  final UiLoadState state;
  final VoidCallback? onRetry;
  final String initialTitle;
  final String initialIdea;
  final bool canSaveDraft;

  @override
  State<ThemeCreationPage> createState() => _ThemeCreationPageState();
}

class _ThemeCreationPageState extends State<ThemeCreationPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _ideaController;
  static const String _genre = '悬疑';
  static const String _visualStyle = '国风厚涂';
  static const String _aspectRatio = '9:16';
  static const double _duration = 60;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle)
      ..addListener(_refresh);
    _ideaController = TextEditingController(text: widget.initialIdea)
      ..addListener(_refresh);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_refresh)
      ..dispose();
    _ideaController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      _ideaController.text.trim().length >= 20;

  CreationDraft get _draft => CreationDraft(
    title: _titleController.text.trim(),
    idea: _ideaController.text.trim(),
    genre: _genre,
    visualStyle: _visualStyle,
    aspectRatio: _aspectRatio,
    durationSeconds: _duration.round(),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsiveContent(
        maxWidth: 980,
        child: StatePanel(
          state: widget.state,
          onRetry: widget.onRetry,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageIntro(
                eyebrow: '01 · 主题创作',
                title: '从一个好故事开始',
                description: '说清主角、目标、阻碍和情绪，AI 会将创意整理成可审核的分集剧本。',
                trailing: TextButton.icon(
                  onPressed: _canSubmit && widget.canSaveDraft
                      ? () => widget.onSaveDraft(_draft)
                      : null,
                  icon: Icon(
                    widget.canSaveDraft
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                  ),
                  label: Text(widget.canSaveDraft ? '保存草稿' : '保存草稿（未接入）'),
                ),
              ),
              const SizedBox(height: 24),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      maxLength: 30,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '项目名称',
                        hintText: '例如：长夜拾灯人',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ideaController,
                      minLines: 6,
                      maxLines: 11,
                      maxLength: 1200,
                      decoration: const InputDecoration(
                        labelText: '故事创意',
                        alignLabelWithHint: true,
                        hintText: '主角是谁？她想完成什么？面临什么危机？',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '故事类型（规划预览）',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '本版请求只提交项目名称和故事创意；类型与视觉风格尚未接入后端契约。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['悬疑', '治愈', '奇幻', '爱情', '科幻', '热血'].map((
                        genre,
                      ) {
                        return ChoiceChip(
                          label: Text(genre),
                          selected: _genre == genre,
                          onSelected: null,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '视觉风格（规划预览）',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['国风厚涂', '日系动画', '电影写实', '复古绘本'].map((style) {
                        return ChoiceChip(
                          avatar: Icon(_styleIcon(style), size: 18),
                          label: Text(style),
                          selected: _visualStyle == style,
                          onSelected: null,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: '成片规格（规划预览）',
                      subtitle: '当前请求固定 9:16；时长和其他画幅待契约接入',
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final ratioPicker = SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: '9:16',
                              icon: Icon(Icons.stay_current_portrait_rounded),
                              label: Text('9:16'),
                            ),
                            ButtonSegment(
                              value: '16:9',
                              icon: Icon(Icons.smart_display_outlined),
                              label: Text('16:9'),
                            ),
                          ],
                          selected: {_aspectRatio},
                          onSelectionChanged: null,
                        );
                        if (constraints.maxWidth < 620) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ratioPicker,
                              const SizedBox(height: 20),
                              _DurationControl(
                                value: _duration,
                                onChanged: null,
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ratioPicker,
                            const SizedBox(width: 28),
                            Expanded(
                              child: _DurationControl(
                                value: _duration,
                                onChanged: null,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const InfoBanner(
                      icon: Icons.lock_clock_outlined,
                      title: '规格选择尚未提交',
                      message: '本版不会把类型、风格、画幅或时长伪装成已生效参数；待后端契约接入后再开放选择。',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InfoBanner(
                icon: Icons.tips_and_updates_outlined,
                title: '创作建议',
                message: _ideaController.text.trim().length < 20
                    ? '再补充一些故事细节，至少输入 20 个字才能生成剧本。'
                    : '信息已足够。本版生成后可审核；编辑持久化与镜头数量调整待接入。',
                tone: _ideaController.text.trim().length < 20
                    ? Theme.of(context).colorScheme.error
                    : Colors.teal,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _canSubmit
                    ? () => widget.onGenerateScript(_draft)
                    : null,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(_canSubmit ? '生成漫剧剧本' : '请先补全项目名称和故事'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _styleIcon(String style) => switch (style) {
    '国风厚涂' => Icons.brush_rounded,
    '日系动画' => Icons.animation_rounded,
    '电影写实' => Icons.movie_filter_outlined,
    _ => Icons.auto_stories_outlined,
  };
}

class _DurationControl extends StatelessWidget {
  const _DurationControl({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('目标时长', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(
              '${value.round()} 秒',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        Slider(
          value: value,
          min: 30,
          max: 90,
          divisions: 4,
          label: '${value.round()} 秒',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
