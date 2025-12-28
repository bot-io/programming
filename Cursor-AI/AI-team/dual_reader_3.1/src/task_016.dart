// Basic usage (automatic fallback)
final service = TranslationService();
await service.initialize();

final translated = await service.translate(
  text: 'Hello world',
  targetLanguage: 'es',
);

// With Google Translate API key
final service = TranslationService(
  googleApiKey: 'your-api-key',
);

// Check active service
print('Using: ${service.getActiveServiceName()}');