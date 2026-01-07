import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/help_service.dart';
import 'package:go_router/go_router.dart';

/// A banner widget that shows quick tips to first-time users
class QuickTipsBanner extends StatefulWidget {
  const QuickTipsBanner({Key? key}) : super(key: key);

  @override
  State<QuickTipsBanner> createState() => _QuickTipsBannerState();
}

class _QuickTipsBannerState extends State<QuickTipsBanner> {
  bool _isVisible = false;
  String _currentTip = '';
  int _tipIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkAndShowTips();
  }

  Future<void> _checkAndShowTips() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTips = prefs.getBool('has_seen_quick_tips') ?? false;
    final dismissedPermanently = prefs.getBool('dismissed_quick_tips') ?? false;
    
    if (!hasSeenTips && !dismissedPermanently) {
      final tips = HelpService.getQuickTips();
      if (tips.isNotEmpty) {
        setState(() {
          _isVisible = true;
          _currentTip = tips[_tipIndex];
        });
      }
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_quick_tips', true);
    setState(() {
      _isVisible = false;
    });
  }

  Future<void> _dismissPermanently() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dismissed_quick_tips', true);
    await prefs.setBool('has_seen_quick_tips', true);
    setState(() {
      _isVisible = false;
    });
  }

  void _nextTip() {
    final tips = HelpService.getQuickTips();
    setState(() {
      _tipIndex = (_tipIndex + 1) % tips.length;
      _currentTip = tips[_tipIndex];
    });
  }

  void _previousTip() {
    final tips = HelpService.getQuickTips();
    setState(() {
      _tipIndex = (_tipIndex - 1 + tips.length) % tips.length;
      _currentTip = tips[_tipIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quick Tip',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                onPressed: _dismiss,
                tooltip: 'Dismiss',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentTip,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    onPressed: _previousTip,
                    tooltip: 'Previous tip',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_tipIndex + 1} / ${HelpService.getQuickTips().length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    onPressed: _nextTip,
                    tooltip: 'Next tip',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      context.push('/help');
                      _dismiss();
                    },
                    child: Text(
                      'More Help',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _dismissPermanently,
                    child: Text(
                      'Don\'t show again',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
