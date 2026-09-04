import 'package:flutter/material.dart';

import '../../../shared/widgets/studio_widgets.dart';
import '../application/keyring_controller.dart';
import '../domain/keyring_models.dart';

class KeyringPage extends StatefulWidget {
  const KeyringPage({
    required this.controller,
    super.key,
  });

  final KeyringController controller;

  @override
  State<KeyringPage> createState() => _KeyringPageState();
}

class _KeyringPageState extends State<KeyringPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    widget.controller.addListener(_onChanged);
    widget.controller.checkStatus();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _tabController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!widget.controller.isInitialized) {
      return _buildInitializeView(theme);
    }

    if (!widget.controller.isUnlocked) {
      return _buildUnlockView(theme);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('密钥库管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline_rounded),
            tooltip: '锁定密钥库',
            onPressed: () => widget.controller.lockVault(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '凭据列表', icon: Icon(Icons.key_rounded)),
            Tab(text: '审计日志', icon: Icon(Icons.history_rounded)),
            Tab(text: '导入/导出', icon: Icon(Icons.swap_vert_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCredentialsView(theme),
          _buildAuditLogView(theme),
          _buildImportExportView(theme),
        ],
      ),
    );
  }

  Widget _buildInitializeView(ThemeData theme) {
    return Scaffold(
      appBar: AppBar(title: const Text('初始化密钥库')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ResponsiveContent(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_person_outlined,
                size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text('设置主密码',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                '主密码用于加密所有 API 密钥。请设置一个强密码（至少 8 位），'
                '密码丢失后无法恢复。',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              _buildEncryptionAlgorithmSelector(theme),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '主密码',
                  prefixIcon: const Icon(Icons.password_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                decoration: const InputDecoration(
                  labelText: '确认主密码',
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
              ),
              const SizedBox(height: 24),
              if (widget.controller.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    widget.controller.errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: widget.controller.isBusy ? null : _doInitialize,
                icon: widget.controller.isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_open_rounded),
                label: const Text('初始化密钥库'),
              ),
              const SizedBox(height: 16),
              InfoBanner(
                icon: Icons.info_outline,
                title: '安全说明',
                message: '密钥库使用 ${widget.controller.algorithm.label} 加密，'
                    '密钥仅存储在本地设备，不会上传到任何服务器。',
                tone: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockView(ThemeData theme) {
    return Scaffold(
      appBar: AppBar(title: const Text('解锁密钥库')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ResponsiveContent(
          maxWidth: 460,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.lock_rounded,
                size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text('输入主密码',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center),
              const SizedBox(height: 28),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '主密码',
                  prefixIcon: const Icon(Icons.password_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
                onSubmitted: (_) => _doUnlock(),
              ),
              const SizedBox(height: 24),
              if (widget.controller.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    widget.controller.errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: widget.controller.isBusy ? null : _doUnlock,
                icon: widget.controller.isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_open_rounded),
                label: const Text('解锁'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEncryptionAlgorithmSelector(ThemeData theme) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('加密算法', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          ...EncryptionAlgorithm.values.map((algo) {
            return RadioListTile<EncryptionAlgorithm>(
              value: algo,
              groupValue: widget.controller.algorithm,
              title: Text(algo.label),
              subtitle: Text(algo.description,
                style: theme.textTheme.bodySmall),
              onChanged: (v) => widget.controller.setAlgorithm(v!),
              dense: true,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCredentialsView(ThemeData theme) {
    final entries = widget.controller.entries;
    if (entries.isEmpty) {
      return _buildEmptyState(theme, '暂无凭据', '点击下方按钮添加 API 密钥');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('凭据列表（${entries.length}）',
                style: theme.textTheme.titleMedium),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _showAddCredentialDialog(theme),
                icon: const Icon(Icons.add_rounded),
                label: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...entries.map((entry) => _CredentialCard(
            entry: entry,
            onVerify: () => widget.controller.verifyCredential(entry.id),
            onEdit: () => _showEditCredentialDialog(theme, entry),
            onDelete: () => _showDeleteConfirm(theme, entry),
          )),
        ],
      ),
    );
  }

  Widget _buildAuditLogView(ThemeData theme) {
    final logs = widget.controller.auditLogs;
    if (logs.isEmpty) {
      return _buildEmptyState(theme, '暂无审计日志', '密钥库操作记录将显示在这里');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: logs.length,
      itemBuilder: (ctx, idx) {
        final log = logs[logs.length - 1 - idx];
        return _AuditLogTile(log: log);
      },
    );
  }

  Widget _buildImportExportView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.file_download_outlined,
                      color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text('导出 .env 文件',
                      style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '将所有已加密的凭据解密并导出为标准 .env 文件格式。'
                  '导出的文件包含明文密钥，请妥善保管。',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    final content = await widget.controller.exportEnvFile();
                    if (mounted) {
                      _showExportedContent(theme, content);
                    }
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('导出 .env'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.file_upload_outlined,
                      color: theme.colorScheme.secondary),
                    const SizedBox(width: 10),
                    Text('导入 .env 文件',
                      style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '粘贴 .env 文件内容，系统将自动识别并导入 API 密钥。'
                  '现有相同 KEY 的凭据将被覆盖。',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: () => _showImportDialog(theme),
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('导入 .env'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.key_off_outlined,
            size: 56, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  void _doInitialize() {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.length < 8) {
      _showError('主密码至少 8 位');
      return;
    }
    if (password != confirm) {
      _showError('两次输入的密码不一致');
      return;
    }

    widget.controller.initializeVault(password);
  }

  void _doUnlock() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      _showError('请输入主密码');
      return;
    }
    widget.controller.unlockVault(password);
  }

  void _showAddCredentialDialog(ThemeData theme) {
    CredentialProvider provider = CredentialProvider.dashscope;
    final apiKeyController = TextEditingController();
    final nameController = TextEditingController();
    final workspaceController = TextEditingController();
    final endpointController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('添加凭据'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CredentialProvider>(
                  value: provider,
                  decoration: const InputDecoration(labelText: '服务商'),
                  items: CredentialProvider.values.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.label),
                  )).toList(),
                  onChanged: (v) => setState(() {
                    provider = v!;
                    apiKeyController.clear();
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: '${provider.defaultEnvKey} 的值',
                    prefixIcon: const Icon(Icons.vpn_key_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '显示名称（可选）',
                    hintText: '例如：生产环境 DashScope Key',
                  ),
                ),
                if (provider == CredentialProvider.bailian) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: workspaceController,
                    decoration: const InputDecoration(
                      labelText: 'Workspace ID',
                      prefixIcon: Icon(Icons.work_rounded),
                    ),
                  ),
                ],
                if (provider == CredentialProvider.azure) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: endpointController,
                    decoration: const InputDecoration(
                      labelText: 'Azure Endpoint',
                      prefixIcon: Icon(Icons.link_rounded),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: widget.controller.isBusy
                ? null
                : () async {
                    final success = await widget.controller.addCredential(
                      provider: provider,
                      envKey: provider.defaultEnvKey,
                      apiKey: apiKeyController.text,
                      displayName: nameController.text.isEmpty
                        ? null
                        : nameController.text,
                      workspaceId: workspaceController.text.isEmpty
                        ? null
                        : workspaceController.text,
                      endpoint: endpointController.text.isEmpty
                        ? null
                        : endpointController.text,
                    );
                    if (ctx.mounted) {
                      if (success) {
                        Navigator.pop(ctx);
                        _showSuccess('凭据已添加');
                      } else {
                        _showError(widget.controller.errorMessage ?? '添加失败');
                      }
                    }
                  },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCredentialDialog(ThemeData theme, CredentialEntry entry) {
    final apiKeyController = TextEditingController();
    final nameController = TextEditingController(text: entry.displayName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑凭据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: apiKeyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '新的 API Key（留空保持不变）',
                prefixIcon: const Icon(Icons.vpn_key_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '显示名称',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final newEntry = entry.copyWith(
                encryptedValue: apiKeyController.text.isEmpty
                    ? entry.encryptedValue
                    : apiKeyController.text,
                displayName: nameController.text,
              );
              final success = await widget.controller.updateCredential(newEntry);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (success) {
                  _showSuccess('凭据已更新');
                } else {
                  _showError(widget.controller.errorMessage ?? '更新失败');
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(ThemeData theme, CredentialEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除凭据'),
        content: Text('确定要删除 ${entry.provider.label} 的凭据吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () async {
              await widget.controller.deleteCredential(entry.id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                _showSuccess('凭据已删除');
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(ThemeData theme) {
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入 .env'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: contentController,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: '粘贴 .env 文件内容',
              hintText: 'DASHSCOPE_API_KEY=sk-xxxx\nOPENAI_API_KEY=sk-xxxx',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final count = await widget.controller
                  .importFromEnvFile(contentController.text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (count > 0) {
                  _showSuccess('成功导入 $count 条凭据');
                } else {
                  _showError('未识别到有效凭据');
                }
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  void _showExportedContent(ThemeData theme, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('.env 文件内容'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _CredentialCard extends StatelessWidget {
  const _CredentialCard({
    required this.entry,
    required this.onVerify,
    required this.onEdit,
    required this.onDelete,
  });

  final CredentialEntry entry;
  final VoidCallback onVerify;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorForStatus(entry.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            entry.displayName ?? entry.provider.label,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(entry.status.label),
                            backgroundColor: color.withValues(alpha: .15),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.provider.label} · ${entry.envKey}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'verify',
                      child: Row(
                        children: [
                          Icon(Icons.verified_rounded),
                          SizedBox(width: 8),
                          Text('验证'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                            color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除',
                            style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'verify':
                        onVerify();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildMaskedKey(),
                const Spacer(),
                if (entry.lastVerified != null)
                  Text(
                    '上次验证: ${_formatDate(entry.lastVerified!)}',
                    style: theme.textTheme.labelSmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaskedKey() {
    final masked = '•' * 8 + (entry.encryptedValue.length > 16
        ? entry.encryptedValue.substring(entry.encryptedValue.length - 4)
        : '');
    return Text(masked, style: const TextStyle(fontFamily: 'monospace'));
  }

  Color _colorForStatus(CredentialStatus status) {
    return switch (status) {
      CredentialStatus.valid => Colors.green,
      CredentialStatus.expired => Colors.orange,
      CredentialStatus.invalid => Colors.red,
      CredentialStatus.unverified => Colors.blue,
      CredentialStatus.notSet => Colors.grey,
    };
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.log});

  final KeyringAuditLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconForAction(log.action);
    final color = _colorForAction(log.action);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: .15),
              foregroundColor: color,
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.action.label,
                    style: theme.textTheme.labelLarge),
                  if (log.detail != null)
                    Text(log.detail!, style: theme.textTheme.bodySmall),
                  if (log.provider != null)
                    Text(log.provider!.label,
                      style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            Text(
              _formatTime(log.timestamp),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForAction(KeyringAction action) {
    return switch (action) {
      KeyringAction.vaultInit => Icons.lock_clock_outlined,
      KeyringAction.vaultUnlock => Icons.lock_open_rounded,
      KeyringAction.vaultLock => Icons.lock_outline_rounded,
      KeyringAction.credentialAdd => Icons.add_circle_outline,
      KeyringAction.credentialUpdate => Icons.update_rounded,
      KeyringAction.credentialDelete => Icons.delete_outline_rounded,
      KeyringAction.credentialVerify => Icons.verified_rounded,
      KeyringAction.exportEnv => Icons.download_rounded,
      KeyringAction.importEnv => Icons.upload_rounded,
    };
  }

  Color _colorForAction(KeyringAction action) {
    return switch (action) {
      KeyringAction.vaultInit => Colors.purple,
      KeyringAction.vaultUnlock => Colors.green,
      KeyringAction.vaultLock => Colors.orange,
      KeyringAction.credentialAdd => Colors.blue,
      KeyringAction.credentialUpdate => Colors.teal,
      KeyringAction.credentialDelete => Colors.red,
      KeyringAction.credentialVerify => Colors.indigo,
      KeyringAction.exportEnv => Colors.brown,
      KeyringAction.importEnv => Colors.cyan,
    };
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
