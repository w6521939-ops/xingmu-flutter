import 'package:flutter/material.dart';

import '../../../presentation/models/studio_view_data.dart';
import '../../../shared/widgets/studio_widgets.dart';

class SettingsViewData {
  const SettingsViewData({
    required this.demoMode,
    required this.apiBaseUrl,
    required this.cacheSizeLabel,
    this.primaryProvider,
    this.selfHostedConfigured,
  });

  final bool demoMode;
  final String apiBaseUrl;
  final String? primaryProvider;
  final bool? selfHostedConfigured;
  final String cacheSizeLabel;

  String get safeApiHost {
    if (demoMode) return '未连接远程服务';
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.host.isEmpty) return '地址未配置';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.data,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onTestConnection,
    required this.onOpenPrivacy,
    required this.onOpenLicenses,
    required this.onClearCache,
    super.key,
    this.state = UiLoadState.ready,
    this.onRetry,
  });

  final SettingsViewData data;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onTestConnection;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenLicenses;
  final VoidCallback onClearCache;
  final UiLoadState state;
  final VoidCallback? onRetry;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _wifiOnly = true;
  bool _notifyWhenComplete = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ResponsiveContent(
        maxWidth: 920,
        child: StatePanel(
          state: widget.state,
          onRetry: widget.onRetry,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageIntro(
                eyebrow: '设置',
                title: '创作环境与隐私',
                description: '查看本次运行的界面选项与数据边界。模型密钥仅能在受信服务端配置。',
              ),
              const SizedBox(height: 22),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: '外观',
                      subtitle: '支持跟随系统、浅色和深色模式',
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_rounded),
                            label: Text('跟随系统'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined),
                            label: Text('浅色'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined),
                            label: Text('深色'),
                          ),
                        ],
                        selected: {widget.themeMode},
                        onSelectionChanged: (selection) =>
                            widget.onThemeChanged(selection.first),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: '生成服务',
                      subtitle: widget.data.demoMode
                          ? '当前为演示模式'
                          : '远程模式；具体 Provider 状态未由客户端读取',
                      action: StatusPill(
                        status: GenerationStatus.draft,
                        label: widget.data.demoMode ? '演示模式' : '远程模式',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SettingRow(
                      icon: Icons.dns_outlined,
                      title: 'API Host',
                      subtitle: widget.data.safeApiHost,
                    ),
                    const Divider(height: 24),
                    _SettingRow(
                      icon: Icons.auto_awesome_outlined,
                      title: '主生成通道',
                      subtitle: widget.data.demoMode
                          ? '本地示例数据，不提交外部请求'
                          : widget.data.primaryProvider ??
                                '服务端自动编排；客户端未读取具体 Provider 配置',
                    ),
                    const SizedBox(height: 14),
                    Tooltip(
                      message: widget.data.demoMode
                          ? '演示模式不会发起网络请求'
                          : '检查服务端健康状态',
                      child: FilledButton.tonalIcon(
                        onPressed: widget.data.demoMode
                            ? null
                            : widget.onTestConnection,
                        icon: const Icon(Icons.wifi_tethering_rounded),
                        label: Text(
                          widget.data.demoMode ? '演示模式无需测试' : '测试服务连接',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    InfoBanner(
                      icon: Icons.key_off_outlined,
                      title: '手机端不显示密钥',
                      message: '此页仅显示 API Host，不显示、读取或缓存 Token 和 Provider Key。',
                      tone: Colors.teal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: '提供商',
                      subtitle: '仅展示服务端明确返回的配置',
                    ),
                    const SizedBox(height: 14),
                    _ProviderRow(
                      icon: Icons.hub_outlined,
                      title: 'Provider 配置',
                      subtitle: widget.data.demoMode
                          ? '演示模式未连接生成 Provider'
                          : widget.data.primaryProvider ??
                                '状态未知：客户端未读取服务端 Provider 配置',
                      enabled:
                          !widget.data.demoMode &&
                          widget.data.primaryProvider != null,
                    ),
                    if (widget.data.selfHostedConfigured
                        case final configured?) ...[
                      const Divider(height: 24),
                      _ProviderRow(
                        icon: Icons.developer_board_outlined,
                        title: '自托管节点',
                        subtitle: configured ? '服务端报告已配置节点' : '服务端报告未配置节点',
                        enabled: configured,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SurfaceCard(
                child: Column(
                  children: [
                    const InfoBanner(
                      icon: Icons.info_outline_rounded,
                      title: '选项尚未持久化',
                      message: '以下开关只会改变本次运行的界面状态；关闭应用后不会保留，也不代表已接入实际下载或系统通知。',
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _wifiOnly,
                      onChanged: (value) => setState(() => _wifiOnly = value),
                      secondary: const Icon(Icons.wifi_rounded),
                      title: const Text('预设：仅在 Wi-Fi 下下载'),
                      subtitle: const Text('仅本次运行生效；文件下载尚未接入'),
                    ),
                    const Divider(),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _notifyWhenComplete,
                      onChanged: (value) =>
                          setState(() => _notifyWhenComplete = value),
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                      ),
                      title: const Text('预设：生成完成时通知'),
                      subtitle: const Text('仅本次运行生效；系统通知尚未接入'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cleaning_services_outlined),
                      title: const Text('清理本地预览缓存'),
                      subtitle: Text(
                        '预览下载尚未接入；缓存统计 ${widget.data.cacheSizeLabel}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: widget.onClearCache,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('隐私与数据说明'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: widget.onOpenPrivacy,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.code_rounded),
                      title: const Text('开源组件许可'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: widget.onOpenLicenses,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '星幕 AI 漫剧工作台 · Flutter Android / HarmonyOS',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: enabled
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: enabled
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Icon(
          enabled ? Icons.check_circle_rounded : Icons.block_rounded,
          color: enabled ? Colors.teal : Theme.of(context).colorScheme.outline,
        ),
      ],
    );
  }
}
