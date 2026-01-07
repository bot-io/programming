import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/help_service.dart';

/// A reusable help icon widget that shows tooltips and can open help documentation
class HelpIcon extends StatelessWidget {
  final String featureKey;
  final bool showDialog;
  final IconData icon;
  final double? iconSize;
  final Color? iconColor;
  final EdgeInsets? padding;
  final String? customTooltip;

  const HelpIcon({
    Key? key,
    required this.featureKey,
    this.showDialog = false,
    this.icon = Icons.help_outline,
    this.iconSize,
    this.iconColor,
    this.padding,
    this.customTooltip,
  }) : super(key: key);

  /// Small help icon for inline use
  const HelpIcon.small({
    Key? key,
    required this.featureKey,
    this.showDialog = false,
    this.icon = Icons.help_outline,
    this.iconSize = 18,
    this.iconColor,
    this.padding = EdgeInsets.zero,
    this.customTooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tooltip = customTooltip ?? HelpService.getTooltip(featureKey);
    
    return IconButton(
      icon: Icon(icon, size: iconSize),
      color: iconColor,
      padding: padding ?? const EdgeInsets.all(8.0),
      constraints: padding == EdgeInsets.zero 
          ? const BoxConstraints() 
          : null,
      tooltip: tooltip,
      onPressed: () {
        if (showDialog) {
          _showHelpDialog(context, tooltip);
        } else {
          // Show tooltip via snackbar or just navigate to help
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tooltip),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'More Help',
                onPressed: () => context.push('/help'),
              ),
            ),
          );
        }
      },
    );
  }

  void _showHelpDialog(BuildContext context, String tooltip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline),
            SizedBox(width: 8),
            Text('Help'),
          ],
        ),
        content: Text(tooltip),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/help');
            },
            child: const Text('More Help'),
          ),
        ],
      ),
    );
  }
}

/// Help icon that shows a dialog with help information
class HelpDialogIcon extends StatelessWidget {
  final String featureKey;
  final IconData icon;
  final double? iconSize;
  final Color? iconColor;
  final EdgeInsets? padding;

  const HelpDialogIcon({
    Key? key,
    required this.featureKey,
    this.icon = Icons.help_outline,
    this.iconSize,
    this.iconColor,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HelpIcon(
      featureKey: featureKey,
      showDialog: true,
      icon: icon,
      iconSize: iconSize,
      iconColor: iconColor,
      padding: padding,
    );
  }
}
