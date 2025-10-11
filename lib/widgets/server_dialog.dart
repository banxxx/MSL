import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:minecraft_server_link/models/server.dart';
import 'package:uuid/uuid.dart';

class _DialogConstants {
  static const maxWidth = 500.0;
  static const headerPadding = EdgeInsets.all(24);
  static const contentPadding = EdgeInsets.fromLTRB(24, 8, 24, 24);
  static const borderRadius = 24.0;
  static const iconSize = 28.0;
  static const animationDuration = Duration(milliseconds: 300);
  static const validationDelay = Duration(milliseconds: 500);

  static BoxDecoration headerDecoration = BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.green[400]!, Colors.green[600]!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(borderRadius),
      topRight: Radius.circular(borderRadius),
    ),
  );

  static BoxDecoration footerDecoration = BoxDecoration(
    color: Colors.grey[50],
    borderRadius: const BorderRadius.only(
      bottomLeft: Radius.circular(borderRadius),
      bottomRight: Radius.circular(borderRadius),
    ),
  );
}

class ServerDialog extends StatefulWidget {
  final Server? server;

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
      duration: _DialogConstants.animationDuration,
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

    final currentPort = int.tryParse(_portController.text);
    final oldDefaultPort = _selectedType == ServerType.java
        ? ServerType.bedrock.defaultPort
        : ServerType.java.defaultPort;

    setState(() {
      _selectedType = type;
      if (currentPort == oldDefaultPort) {
        _portController.text = type.defaultPort.toString();
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    await Future.delayed(_DialogConstants.validationDelay);

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
    final isEdit = widget.server != null;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_DialogConstants.borderRadius),
        ),
        elevation: 8,
        child: Container(
          constraints: const BoxConstraints(maxWidth: _DialogConstants.maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogHeader(isEdit: isEdit),
              Flexible(
                child: SingleChildScrollView(
                  padding: _DialogConstants.contentPadding,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _TypeSelector(
                          selectedType: _selectedType,
                          isLoading: _isLoading,
                          onChanged: _onTypeChanged,
                        ),
                        const SizedBox(height: 20),
                        _NameField(
                          controller: _nameController,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 20),
                        _AddressField(
                          controller: _addressController,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 20),
                        _PortField(
                          controller: _portController,
                          isLoading: _isLoading,
                          selectedType: _selectedType,
                          onSubmit: _handleSubmit,
                        ),
                        const SizedBox(height: 24),
                        _HelpText(selectedType: _selectedType),
                      ],
                    ),
                  ),
                ),
              ),
              _DialogActions(
                isEdit: isEdit,
                isLoading: _isLoading,
                onCancel: () => Navigator.pop(context),
                onSubmit: _handleSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final bool isEdit;

  const _DialogHeader({required this.isEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _DialogConstants.headerPadding,
      decoration: _DialogConstants.headerDecoration,
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
              size: _DialogConstants.iconSize,
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
}

class _TypeSelector extends StatelessWidget {
  final ServerType selectedType;
  final bool isLoading;
  final ValueChanged<ServerType?> onChanged;

  const _TypeSelector({
    required this.selectedType,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: ServerType.values.map((type) {
          final isSelected = selectedType == type;
          return Expanded(
            child: _TypeSelectorItem(
              type: type,
              isSelected: isSelected,
              isLoading: isLoading,
              onTap: () => onChanged(type),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TypeSelectorItem extends StatelessWidget {
  final ServerType type;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  const _TypeSelectorItem({
    required this.type,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
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
    );
  }
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;

  const _NameField({
    required this.controller,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: !isLoading,
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
}

class _AddressField extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;

  const _AddressField({
    required this.controller,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: !isLoading,
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
}

class _PortField extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final ServerType selectedType;
  final VoidCallback onSubmit;

  const _PortField({
    required this.controller,
    required this.isLoading,
    required this.selectedType,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: !isLoading,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
      onFieldSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        labelText: '端口号',
        hintText: selectedType.defaultPort.toString(),
        prefixIcon: Icon(Icons.settings_ethernet, color: Colors.purple[600]),
        suffixIcon: Tooltip(
          message: '${selectedType.displayName}默认端口是 ${selectedType.defaultPort}',
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
}

class _HelpText extends StatelessWidget {
  final ServerType selectedType;

  const _HelpText({required this.selectedType});

  @override
  Widget build(BuildContext context) {
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
              selectedType == ServerType.java
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
}

class _DialogActions extends StatelessWidget {
  final bool isEdit;
  final bool isLoading;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _DialogActions({
    required this.isEdit,
    required this.isLoading,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _DialogConstants.footerDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: isLoading ? null : onCancel,
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
            onPressed: isLoading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
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