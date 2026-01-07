import 'package:flutter/material.dart';
import '../services/pwa_service.dart';

/// Banner widget that shows PWA install prompt when available
class PwaInstallBanner extends StatefulWidget {
  final Widget? child;
  final bool showBanner;
  final Duration autoHideDuration;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? buttonColor;
  final String? installText;
  final String? dismissText;

  const PwaInstallBanner({
    Key? key,
    this.child,
    this.showBanner = true,
    this.autoHideDuration = const Duration(days: 7),
    this.backgroundColor,
    this.textColor,
    this.buttonColor,
    this.installText,
    this.dismissText,
  }) : super(key: key);

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  final PwaService _pwaService = PwaService();
  bool _showBanner = false;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _checkInstallAvailability();
    _pwaService.installPromptAvailable.listen((available) {
      if (mounted && available && !_isDismissed) {
        setState(() {
          _showBanner = true;
        });
      }
    });
  }

  Future<void> _checkInstallAvailability() async {
    if (!widget.showBanner || _isDismissed) return;
    
    // Check if already installed
    if (_pwaService.isStandalone) {
      setState(() {
        _showBanner = false;
      });
      return;
    }

    // Check if install prompt is available
    if (_pwaService.canInstall) {
      setState(() {
        _showBanner = true;
      });
    }
  }

  Future<void> _handleInstall() async {
    final installed = await _pwaService.showInstallPrompt();
    if (installed) {
      setState(() {
        _showBanner = false;
      });
    }
  }

  void _handleDismiss() {
    setState(() {
      _showBanner = false;
      _isDismissed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.backgroundColor ?? theme.colorScheme.surface;
    final textColor = widget.textColor ?? theme.colorScheme.onSurface;
    final buttonColor = widget.buttonColor ?? theme.colorScheme.primary;

    return Stack(
      children: [
        if (widget.child != null) widget.child!,
        if (_showBanner && !_pwaService.isStandalone)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              elevation: 4,
              color: backgroundColor,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.download,
                        color: buttonColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.installText ??
                                  'Install Dual Reader for a better experience',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Get offline access and faster loading',
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _handleInstall,
                        style: TextButton.styleFrom(
                          foregroundColor: buttonColor,
                        ),
                        child: const Text('Install'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _handleDismiss,
                        color: textColor.withOpacity(0.6),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
