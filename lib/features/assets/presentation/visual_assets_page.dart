import 'package:flutter/material.dart';

import '../../../presentation/models/studio_view_data.dart';
import '../../../shared/widgets/studio_widgets.dart';

class VisualAssetsPage extends StatefulWidget {
  const VisualAssetsPage({
    required this.assets,
    required this.onRegenerate,
    required this.onToggleLock,
    required this.onGenerateMissing,
    required this.onContinue,
    required this.onNavigateStep,
    super.key,
    this.state = UiLoadState.ready,
    this.onRetry,
  });

  final List<VisualAssetData> assets;
  final ValueChanged<VisualAssetData> onRegenerate;
  final ValueChanged<VisualAssetData> onToggleLock;
  final ValueChanged<VisualAssetType> onGenerateMissing;
  final VoidCallback onContinue;
  final ValueChanged<StudioDestination> onNavigateStep;
  final UiLoadState state;
  final VoidCallback? onRetry;

  @override
  State<VisualAssetsPage> createState() => _VisualAssetsPageState();
}

class _VisualAssetsPageState extends State<VisualAssetsPage> {
  VisualAssetType _selectedType = VisualAssetType.character;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.assets
        .where((asset) => asset.type == _selectedType)
        .toList();
    final lockedCount = widget.assets
        .where((asset) => asset.locked == true)
        .length;
    final unknownLockCount = widget.assets
        .where((asset) => asset.locked == null)
        .length;
    return SingleChildScrollView(
      child: ResponsiveContent(
        child: StatePanel(
          state: widget.state,
          onRetry: widget.onRetry,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StudioStepBar(
                activeDestination: StudioDestination.assets,
                onStepTap: widget.onNavigateStep,
              ),
              const SizedBox(height: 24),
              PageIntro(
                eyebrow: '03 · 视觉资产',
                title: '先固定世界，再生成镜头',
                description: '查看角色、场景与道具参考。锁定状态仅以服务端明确返回的数据为准。',
                trailing: FilledButton.icon(
                  onPressed: widget.onContinue,
                  icon: const Icon(Icons.movie_creation_outlined),
                  label: const Text('进入镜头工作台'),
                ),
              ),
              const SizedBox(height: 20),
              InfoBanner(
                icon: Icons.lock_person_outlined,
                title: unknownLockCount > 0
                    ? '$unknownLockCount 个参考的锁定状态未知'
                    : '服务端确认已锁定 $lockedCount 个参考',
                message: unknownLockCount > 0
                    ? '图片地址仅表示参考图已返回，不能据此判断资产已经锁定。'
                    : '这里仅展示服务端明确返回的锁定状态。',
                tone: Colors.teal,
              ),
              const SizedBox(height: 22),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<VisualAssetType>(
                  segments: const [
                    ButtonSegment(
                      value: VisualAssetType.character,
                      icon: Icon(Icons.face_rounded),
                      label: Text('角色'),
                    ),
                    ButtonSegment(
                      value: VisualAssetType.scene,
                      icon: Icon(Icons.landscape_outlined),
                      label: Text('场景'),
                    ),
                    ButtonSegment(
                      value: VisualAssetType.prop,
                      icon: Icon(Icons.category_outlined),
                      label: Text('道具'),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedType = selection.first);
                  },
                ),
              ),
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                SurfaceCard(
                  child: StatePanel(
                    state: UiLoadState.empty,
                    emptyTitle: '服务端尚未返回${_typeLabel(_selectedType)}卡',
                    emptyMessage:
                        '当前项目没有可展示的${_typeLabel(_selectedType)}卡，不补写占位资产内容。',
                    emptyActionLabel: '请求生成${_typeLabel(_selectedType)}卡',
                    onEmptyAction: () =>
                        widget.onGenerateMissing(_selectedType),
                    child: const SizedBox.shrink(),
                  ),
                )
              else
                _AssetGrid(
                  assets: filtered,
                  onRegenerate: widget.onRegenerate,
                  onToggleLock: widget.onToggleLock,
                ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => widget.onGenerateMissing(_selectedType),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('新建${_typeLabel(_selectedType)}卡'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.onContinue,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('继续到分镜'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(VisualAssetType type) => switch (type) {
    VisualAssetType.character => '角色',
    VisualAssetType.scene => '场景',
    VisualAssetType.prop => '道具',
  };
}

class _AssetGrid extends StatelessWidget {
  const _AssetGrid({
    required this.assets,
    required this.onRegenerate,
    required this.onToggleLock,
  });

  final List<VisualAssetData> assets;
  final ValueChanged<VisualAssetData> onRegenerate;
  final ValueChanged<VisualAssetData> onToggleLock;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
            ? 3
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        const gap = 14.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: assets
              .map(
                (asset) => SizedBox(
                  width: width,
                  child: _AssetCard(
                    asset: asset,
                    onRegenerate: () => onRegenerate(asset),
                    onToggleLock: () => onToggleLock(asset),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.onRegenerate,
    required this.onToggleLock,
  });

  final VisualAssetData asset;
  final VoidCallback onRegenerate;
  final VoidCallback onToggleLock;

  @override
  Widget build(BuildContext context) {
    final icon = switch (asset.type) {
      VisualAssetType.character => Icons.person_rounded,
      VisualAssetType.scene => Icons.temple_buddhist_rounded,
      VisualAssetType.prop => Icons.emoji_objects_rounded,
    };
    final lockBadge = switch (asset.locked) {
      true => '已锁定',
      false => '未锁定',
      null => '锁定状态未知',
    };
    final lockTooltip = switch (asset.locked) {
      true => '解除锁定',
      false => '锁定为标准参考',
      null => '服务端未返回锁定状态',
    };
    final lockIcon = switch (asset.locked) {
      true => Icons.lock_rounded,
      false => Icons.lock_open_rounded,
      null => Icons.help_outline_rounded,
    };
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GeneratedArtwork(
            title: asset.name,
            icon: icon,
            color: Color(asset.colorValue),
            badge: lockBadge,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  asset.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusPill(status: asset.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            asset.description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (asset.status == GenerationStatus.running) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.sync_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text('生成参考图中 · 服务端未返回精确进度')),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: asset.status == GenerationStatus.running
                      ? null
                      : onRegenerate,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    asset.status == GenerationStatus.running ? '生成中' : '重生成',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: lockTooltip,
                onPressed:
                    asset.status == GenerationStatus.running ||
                        asset.locked == null
                    ? null
                    : onToggleLock,
                icon: Icon(lockIcon),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
