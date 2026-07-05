import '../../l10n/app_localizations.dart';

/// A context-free, localizable message produced by a provider.
///
/// Providers run outside the widget tree and cannot access [AppLocalizations],
/// so they describe *which* message (and any parameters) via a [UiMessage]
/// instead of hard-coding English. The screen resolves it to display text by
/// calling [resolve] with its [AppLocalizations]. The resolver is a closure, so
/// parameterized messages (counts, codes) are supported without the provider
/// touching `BuildContext`.
class UiMessage {
  const UiMessage(this.resolve);

  /// Resolves this message to localized text.
  final String Function(AppLocalizations l10n) resolve;

  // ── Result ────────────────────────────────────────────────────────────
  static UiMessage get genericError => UiMessage((l) => l.genericError);
  static UiMessage get resultNotFound => UiMessage((l) => l.resultNotFound);
  static UiMessage get couldNotLoadResult =>
      UiMessage((l) => l.couldNotLoadResult);
  static UiMessage get sendFeedbackFailed =>
      UiMessage((l) => l.sendFeedbackFailed);
  static UiMessage get submitReportFailed =>
      UiMessage((l) => l.submitReportFailed);
  static UiMessage get sendRequestFailed =>
      UiMessage((l) => l.sendRequestFailed);
  static UiMessage get sprayAdvisoryUnavailable =>
      UiMessage((l) => l.sprayAdvisoryUnavailable);

  // ── Settings ──────────────────────────────────────────────────────────
  static UiMessage get deleteAccountReauth =>
      UiMessage((l) => l.deleteAccountReauth);
  static UiMessage get deleteAccountFailed =>
      UiMessage((l) => l.deleteAccountFailed);
  static UiMessage get modelUpToDate => UiMessage((l) => l.modelUpToDate);

  // ── Scanner ───────────────────────────────────────────────────────────
  static UiMessage get analysisFailed => UiMessage((l) => l.analysisFailed);
  static UiMessage get cameraUnavailable =>
      UiMessage((l) => l.cameraUnavailable);
  static UiMessage get torchUnavailable => UiMessage((l) => l.torchUnavailable);
  static UiMessage get captureFailed => UiMessage((l) => l.captureFailed);
  static UiMessage get urlNotImage => UiMessage((l) => l.urlNotImage);
  static UiMessage get urlLoadFailed => UiMessage((l) => l.urlLoadFailed);
  static UiMessage get batchAllFailed => UiMessage((l) => l.batchAllFailed);
  static UiMessage get noImagesToAnalyse =>
      UiMessage((l) => l.noImagesToAnalyse);
  static UiMessage get qualityBlurry => UiMessage((l) => l.qualityBlurry);
  static UiMessage get qualityTooDark => UiMessage((l) => l.qualityTooDark);
  static UiMessage get qualityTooBright => UiMessage((l) => l.qualityTooBright);
  static UiMessage get qualityTooSmall => UiMessage((l) => l.qualityTooSmall);
  static UiMessage get qualityPoor => UiMessage((l) => l.qualityPoor);

  // ── Parameterized ─────────────────────────────────────────────────────
  static UiMessage downloadFailed(int code) =>
      UiMessage((l) => l.downloadFailed(code));
  static UiMessage batchPartial(int analysed, int total) =>
      UiMessage((l) => l.batchPartial(analysed, total));
}
