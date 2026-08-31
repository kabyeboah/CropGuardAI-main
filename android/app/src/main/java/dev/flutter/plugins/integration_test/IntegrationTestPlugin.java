package dev.flutter.plugins.integration_test;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding;

/**
 * Stub implementation of the integration_test plugin for release builds.
 * The real integration_test plugin is a dev_dependency only needed for testing.
 * This stub satisfies the generated registration code without pulling in the full test framework,
 * allowing release builds to compile successfully.
 */
public class IntegrationTestPlugin implements FlutterPlugin {
    public IntegrationTestPlugin() {}

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        // No‑op for release builds.
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        // No‑op.
    }
}
