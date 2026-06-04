import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dual_reader/src/data/services/language_model_manager.dart';
import 'package:dual_reader/src/core/utils/language_utils.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Screen for managing downloaded language models
///
/// Allows users to:
/// - View downloaded languages
/// - Download new language models
/// - Delete unused models
/// - See model sizes
/// - Monitor download progress
class LanguageModelsScreen extends ConsumerStatefulWidget {
  const LanguageModelsScreen({super.key});

  @override
  ConsumerState<LanguageModelsScreen> createState() => _LanguageModelsScreenState();
}

class _LanguageModelsScreenState extends ConsumerState<LanguageModelsScreen> {
  final LanguageModelManager _modelManager = LanguageModelManager.instance;
  // ConnectivityPlus instance (version 5.x doesn't require constructor call)
  final ConnectivityPlus _connectivity = ConnectivityPlus();

  List<LanguageModelInfo> _downloadedModels = [];
  List<LanguageModelInfo> _allModels = [];
  NetworkStatus? _networkStatus;

  bool _isLoading = true;
  String? _selectedLanguageCode;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenToNetworkChanges();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load network status
      _networkStatus = await _modelManager.checkNetworkStatus();

      // Load model info
      _downloadedModels = _modelManager.getDownloadedModels();
      _allModels = _modelManager.getAvailableModels();

      // Get recommended languages that aren't downloaded
      final recommended = _modelManager.getRecommendedLanguages();
      for (final lang in recommended) {
        if (!_downloadedModels.any((m) => m.languageCode == lang)) {
          // Add new model info for languages not yet tracked
          _allModels.add(LanguageModelInfo(
            languageCode: lang,
            displayName: LanguageUtils.getLanguageName(lang),
            version: '1.0',
            sizeBytes: _modelManager.estimateModelSize(lang),
            isDownloaded: false,
          ));
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      LoggingService.error('Failed to load language models', error: e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _listenToNetworkChanges() {
    _modelManager.networkStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _networkStatus = status;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language Models'),
        actions: [
          // Network status indicator
          _buildNetworkIndicator(),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
            tooltip: 'Download Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // Summary section
                  _buildSummarySection(),
                  const Divider(),

                  // Downloaded models section
                  _buildDownloadedSection(),

                  // Available models section
                  _buildAvailableSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildNetworkIndicator() {
    final status = _networkStatus;
    String label;
    IconData icon;
    Color color;

    if (status == null || !status!.isConnected) {
      label = 'Offline';
      icon = Icons.wifi_off;
      color = Colors.red;
    } else if (status.isWiFi) {
      label = 'WiFi';
      icon = Icons.wifi;
      color = Colors.green;
    } else if (status.isMobile) {
      label = 'Mobile';
      icon = Icons.signal_cellular_alt;
      color = Colors.orange;
    } else {
      label = 'Online';
      icon = Icons.cloud_done;
      color = Colors.blue;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final downloadedCount = _downloadedModels.length;
    final totalSize = _modelManager.getTotalModelSizeFormatted();

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Translation Models',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '$downloadedCount language${downloadedCount == 1 ? '' : 's'} downloaded • $totalSize used',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadedSection() {
    if (_downloadedModels.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('No language models downloaded yet.\nDownload models to translate offline.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Text(
            'Downloaded Languages',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _downloadedModels.length,
          itemBuilder: (context, index) {
            final model = _downloadedModels[index];
            return _buildModelTile(model, isDownloaded: true);
          },
        ),
      ],
    );
  }

  Widget _buildAvailableSection() {
    final availableModels = _allModels.where((m) => !m.isDownloaded).toList();

    if (availableModels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
          child: Text(
            'Available Languages',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: availableModels.length,
          itemBuilder: (context, index) {
            final model = availableModels[index];
            return _buildModelTile(model, isDownloaded: false);
          },
        ),
      ],
    );
  }

  Widget _buildModelTile(LanguageModelInfo model, {required bool isDownloaded}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            model.displayName.substring(0, 2).toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(model.displayName),
        subtitle: Text(model.formattedSize),
        trailing: isDownloaded
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Downloaded',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _showDeleteDialog(context, model),
                    tooltip: 'Delete model',
                  ),
                ],
              )
            : _DownloadButton(
                model: model,
                onPressed: () => _downloadModel(context, model),
              ),
      ),
    );
  }

  Future<void> _downloadModel(BuildContext context, LanguageModelInfo model) async {
    final status = _networkStatus;
    if (status == null || !status!.isConnected) {
      _showOfflineSnackBar(context);
      return;
    }

    if (_modelManager.isDownloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Another download is in progress')),
      );
      return;
    }

    // Show download progress dialog
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ModelDownloadDialog(
        modelManager: _modelManager,
        languageCode: model.languageCode,
        languageName: model.displayName,
        onComplete: () {
          Navigator.of(dialogContext).pop();
          _loadData(); // Refresh the list
        },
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, LanguageModelInfo model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${model.displayName} Model'),
        content: Text('Are you sure you want to delete the ${model.displayName} language model?\n\nIt will be downloaded again when needed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _modelManager.deleteModel(model.languageCode);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${model.displayName} model deleted')),
        );
      }
    }
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    final config = _modelManager.configuration;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatefulBuilder(
              builder: (context, setState) {
                return SwitchListTile(
                  title: const Text('WiFi Only'),
                  subtitle: const Text('Only download on WiFi connection'),
                  value: config.wifiOnly,
                  onChanged: (value) {
                    Navigator.of(context).pop();
                    _modelManager.configure(wifiOnly: value);
                  },
                );
              },
            ),
            StatefulBuilder(
              builder: (context, setState) {
                return SwitchListTile(
                  title: const Text('Auto-Download'),
                  subtitle: const Text('Automatically download preferred languages'),
                  value: config.autoDownloadPreferred,
                  onChanged: (value) {
                    Navigator.of(context).pop();
                    _modelManager.configure(autoDownloadPreferred: value);
                  },
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showOfflineSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No internet connection. Please connect to download models.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// Dialog showing model download progress
class _ModelDownloadDialog extends StatefulWidget {
  final LanguageModelManager modelManager;
  final String languageCode;
  final String languageName;
  final VoidCallback onComplete;

  const _ModelDownloadDialog({
    required this.modelManager,
    required this.languageCode,
    required this.languageName,
    required this.onComplete,
  });

  @override
  State<_ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<_ModelDownloadDialog> {
  String _progressMessage = 'Preparing download...';
  double _progress = 0.0;
  bool _isDownloading = true;
  bool _isSuccess = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    final success = await modelManager.downloadModel(
      languageCode,
      onProgress: (message) {
        if (mounted) {
          setState(() {
            _progressMessage = message;
            _progress = (_progress + 0.1).clamp(0.0, 0.9);
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isSuccess = success;
        _error = success ? null : 'Download failed';
      });

      // Wait a moment to show the result
      await Future.delayed(const Duration(seconds: 1));

      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Downloading $languageName'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isDownloading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_progressMessage, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _progress),
            ] else if (_isSuccess) ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              const Text('Download complete!'),
            ] else ...[
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_error ?? 'Download failed'),
            ],
          ],
        ),
      ),
    );
  }
}

/// Download button with state management
class _DownloadButton extends StatefulWidget {
  final LanguageModelInfo model;
  final VoidCallback onPressed;

  const _DownloadButton({
    required this.model,
    required this.onPressed,
  });

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.download),
      label: const Text('Download'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.blue,
      ),
    );
  }
}
