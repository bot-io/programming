import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/help_service.dart';

/// A contextual help widget that can be used to show help information
/// for specific features or sections of the app
class ContextualHelp extends StatelessWidget {
  final String featureKey;
  final Widget child;
  final String? customMessage;
  final bool showIcon;
  final IconData icon;
  final Color? iconColor;
  final EdgeInsets? padding;

  const ContextualHelp({
    Key? key,
    required this.featureKey,
    required this.child,
    this.customMessage,
    this.showIcon = true,
    this.icon = Icons.help_outline,
    this.iconColor,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tooltip = customMessage ?? HelpService.getTooltip(featureKey);
    
    return Tooltip(
      message: tooltip,
      child: Stack(
        children: [
          child,
          if (showIcon)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _showHelpDialog(context, tooltip),
                child: Container(
                  padding: padding ?? const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: iconColor ?? Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Help'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message),
        ),
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

/// A help banner that can be shown at the top of screens
class HelpBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onLearnMore;
  final bool dismissible;

  const HelpBanner({
    Key? key,
    required this.message,
    this.onDismiss,
    this.onLearnMore,
    this.dismissible = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          if (onLearnMore != null)
            TextButton(
              onPressed: onLearnMore,
              child: Text(
                'Learn More',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          if (dismissible && onDismiss != null)
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

/// A help button that opens the help screen
class HelpButton extends StatelessWidget {
  final String? customTooltip;
  final IconData icon;
  final Color? iconColor;

  const HelpButton({
    Key? key,
    this.customTooltip,
    this.icon = Icons.help_outline,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: iconColor,
      tooltip: customTooltip ?? HelpService.getTooltip('help'),
      onPressed: () {
        context.push('/help');
      },
    );
  }
}
