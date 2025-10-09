import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:minecraft_server_link/models/server.dart';
import 'package:uuid/uuid.dart';

class ServerDialog extends StatefulWidget {
  final Server? server; // 支持编辑模式

  const ServerDialog({super.key, this.server});

  @override
  State<ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<ServerDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _portController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late ServerType _selectedType;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.server?.type ?? ServerType.java;
    _nameController = TextEditingController(text: widget.server?.name ?? '');
    _addressController = TextEditingController(text: widget.server?.address ?? '');
    _portController = TextEditingController(
      text: widget.server?.port.toString() ?? _selectedType.defaultPort.toString(),
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTypeChanged(ServerType? type) {
    if (type == null || type == _selectedType) return;

    setState(() {
      _selectedType = type;
      // 如果端口是旧类型的默认端口，则自动更新为新类型的默认端口
      final currentPort = int.tryParse(_portController.text);
      final oldDefaultPort = _selectedType == ServerType.java
          ? ServerType.bedrock.defaultPort
          : ServerType.java.defaultPort;

      if (currentPort == oldDefaultPort) {
        _portController.text = type.defaultPort.toString();
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // 模拟验证延迟，让用户看到加载状态
    await Future.delayed(const Duration(milliseconds: 500));

    final server = Server(
      id: widget.server?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      port: int.tryParse(_portController.text) ?? _selectedType.defaultPort,
      type: _selectedType,
    );

    if (mounted) {
      Navigator.pop(context, server);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.server != null;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头部
              _buildHeader(isEdit, theme),

              // 表单内容
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTypeSelector(),
                        const SizedBox(height: 20),
                        _buildNameField(),
                        const SizedBox(height: 20),
                        _buildAddressField(),
                        const SizedBox(height: 20),
                        _buildPortField(),
                        const SizedBox(height: 24),
                        _buildHelpText(),
                      ],
                    ),
                  ),
                ),
              ),

              // 底部按钮
              _buildActions(isEdit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEdit, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dns,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? '编辑服务器' : '添加服务器',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEdit ? '修改服务器信息' : '连接到你的 Minecraft 服务器',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: ServerType.values.map((type) {
          final isSelected = _selectedType == type;
          return Expanded(
            child: InkWell(
              onTap: _isLoading ? null : () => _onTypeChanged(type),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green[600] : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type == ServerType.java ? Icons.computer : Icons.phone_android,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type.displayName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      enabled: !_isLoading,
      textCapitalization: TextCapitalization.words,
      maxLength: 20,
      decoration: InputDecoration(
        labelText: '服务器名称',
        hintText: '例如：我的世界服务器',
        prefixIcon: Icon(Icons.label, color: Colors.green[600]),
        filled: true,
        fillColor: Colors.green[50],
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green[100]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green[600]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入服务器名称';
        }
        if (value.trim().length < 2) {
          return '名称至少需要 2 个字符';
        }
        return null;
      },
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      enabled: !_isLoading,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: '服务器地址',
        hintText: 'play.example.com',
        prefixIcon: Icon(Icons.public, color: Colors.blue[600]),
        filled: true,
        fillColor: Colors.blue[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[100]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入服务器地址';
        }
        final trimmed = value.trim();
        if (trimmed.length < 3) {
          return '地址格式不正确';
        }
        // 简单的域名/IP验证
        final validPattern = RegExp(
          r'^[a-zA-Z0-9][a-zA-Z0-9\-\.]*[a-zA-Z0-9]$',
        );
        if (!validPattern.hasMatch(trimmed)) {
          return '地址包含无效字符';
        }
        return null;
      },
    );
  }

  Widget _buildPortField() {
    return TextFormField(
      controller: _portController,
      enabled: !_isLoading,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
      onFieldSubmitted: (_) => _handleSubmit(),
      decoration: InputDecoration(
        labelText: '端口号',
        hintText: _selectedType.defaultPort.toString(),
        prefixIcon: Icon(Icons.settings_ethernet, color: Colors.purple[600]),
        suffixIcon: Tooltip(
          message: '${_selectedType.displayName}默认端口是 ${_selectedType.defaultPort}',
          child: Icon(Icons.info_outline, color: Colors.grey[400], size: 20),
        ),
        filled: true,
        fillColor: Colors.purple[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.purple[100]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.purple[600]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入端口号';
        }
        final port = int.tryParse(value);
        if (port == null) {
          return '端口号必须是数字';
        }
        if (port < 1 || port > 65535) {
          return '端口号范围：1-65535';
        }
        return null;
      },
    );
  }

  Widget _buildHelpText() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedType == ServerType.java
                  ? '提示：Java 版默认端口 25565'
                  : '提示：基岩版默认端口 19132',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(bool isEdit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '取消',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isEdit ? Icons.check : Icons.add,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isEdit ? '保存' : '添加',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}