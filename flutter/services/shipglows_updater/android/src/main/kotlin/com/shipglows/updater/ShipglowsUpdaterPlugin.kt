package com.shipglows.updater

import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Separate class so the merged manifest never collides with the app's own FileProvider. */
class ShipglowsUpdaterFileProvider : FileProvider()

/**
 * Installed version and source, install permission, then the checks on a
 * downloaded APK (SHA-256, package, version, signing certificate) before the
 * system installer opens it.
 */
class ShipglowsUpdaterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private val worker: ExecutorService = Executors.newSingleThreadExecutor()
  private val main = Handler(Looper.getMainLooper())

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "shipglows_updater")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "info" -> result.success(info())
      "canRequestInstalls" -> result.success(canRequestInstalls())
      "openInstallPermission" -> {
        openInstallPermission()
        result.success(null)
      }
      "install" -> {
        val path = call.argument<String>("path")
        val sha256 = call.argument<String>("sha256")
        if (path == null || sha256 == null) {
          result.error("install", "path and sha256 are required", null)
          return
        }
        // Hashing a large APK must not block the UI thread.
        worker.execute {
          val error = try {
            verify(File(path), sha256.lowercase())
          } catch (e: Exception) {
            "install" to (e.message ?: e.javaClass.simpleName)
          }
          main.post {
            if (error != null) {
              result.error(error.first, error.second, null)
            } else {
              try {
                openInstaller(File(path))
                result.success(null)
              } catch (e: Exception) {
                result.error("install", e.message, null)
              }
            }
          }
        }
      }
      else -> result.notImplemented()
    }
  }

  private fun info(): Map<String, Any?> {
    val info = installedPackage(0)
    return mapOf(
      "versionName" to info.versionName,
      "versionCode" to versionCode(info),
      "installer" to installer(),
      "updatesDir" to File(context.cacheDir, "shipglows_updates").absolutePath,
    )
  }

  @Suppress("DEPRECATION")
  private fun installer(): String? = try {
    val pm = context.packageManager
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      pm.getInstallSourceInfo(context.packageName).installingPackageName
    } else {
      pm.getInstallerPackageName(context.packageName)
    }
  } catch (e: Exception) {
    null
  }

  private fun canRequestInstalls(): Boolean =
    Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
      context.packageManager.canRequestPackageInstalls()

  private fun openInstallPermission() {
    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Intent(
        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
        Uri.parse("package:${context.packageName}"),
      )
    } else {
      Intent(Settings.ACTION_SECURITY_SETTINGS)
    }
    context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
  }

  /** Null when [file] may be installed, else an error code and message. */
  private fun verify(file: File, sha256: String): Pair<String, String>? {
    if (!file.isFile) return "install" to "No file at ${file.path}"
    val digest = MessageDigest.getInstance("SHA-256")
    file.inputStream().use { input ->
      val buffer = ByteArray(64 * 1024)
      while (true) {
        val read = input.read(buffer)
        if (read < 0) break
        digest.update(buffer, 0, read)
      }
    }
    val actual = digest.digest().joinToString("") { "%02x".format(it) }
    if (actual != sha256) {
      file.delete()
      return "checksum" to "sha256 $actual, expected $sha256"
    }

    val archive = archivePackage(file)
      ?: return "install" to "Not a readable APK"
    if (archive.packageName != context.packageName) {
      file.delete()
      return "package" to "APK is ${archive.packageName}, not ${context.packageName}"
    }
    val installed = installedPackage(signatureFlag())
    if (versionCode(archive) <= versionCode(installed)) {
      return "downgrade" to
        "APK versionCode ${versionCode(archive)} <= installed ${versionCode(installed)}"
    }
    val expected = certificates(installed)
    val found = certificates(archive)
    // Rotated keys keep the old certificate in their history: one in common
    // is enough. Unreadable archive certificates are left to Android, which
    // refuses a mismatched update itself.
    if (expected.isNotEmpty() && found.isNotEmpty() && expected.intersect(found).isEmpty()) {
      file.delete()
      return "signature" to "APK is not signed with this app's certificate"
    }
    return null
  }

  private fun openInstaller(file: File) {
    val uri = FileProvider.getUriForFile(
      context,
      "${context.packageName}.shipglows_updater.files",
      file,
    )
    val intent = Intent(Intent.ACTION_VIEW)
      .setDataAndType(uri, "application/vnd.android.package-archive")
      .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
    context.startActivity(intent)
  }

  @Suppress("DEPRECATION")
  private fun signatureFlag(): Int =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      PackageManager.GET_SIGNING_CERTIFICATES
    } else {
      PackageManager.GET_SIGNATURES
    }

  @Suppress("DEPRECATION")
  private fun installedPackage(flags: Int): PackageInfo =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      context.packageManager.getPackageInfo(
        context.packageName,
        PackageManager.PackageInfoFlags.of(flags.toLong()),
      )
    } else {
      context.packageManager.getPackageInfo(context.packageName, flags)
    }

  @Suppress("DEPRECATION")
  private fun archivePackage(file: File): PackageInfo? =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      context.packageManager.getPackageArchiveInfo(
        file.path,
        PackageManager.PackageInfoFlags.of(signatureFlag().toLong()),
      )
    } else {
      context.packageManager.getPackageArchiveInfo(file.path, signatureFlag())
    }

  @Suppress("DEPRECATION")
  private fun versionCode(info: PackageInfo): Long =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      info.longVersionCode
    } else {
      info.versionCode.toLong()
    }

  /** SHA-256 of each signing certificate, rotation history included. */
  @Suppress("DEPRECATION")
  private fun certificates(info: PackageInfo): Set<String> {
    val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      val signing = info.signingInfo ?: return emptySet()
      if (signing.hasMultipleSigners()) {
        signing.apkContentsSigners
      } else {
        signing.signingCertificateHistory
      }
    } else {
      info.signatures
    }
    return signatures.orEmpty().map { signature ->
      MessageDigest.getInstance("SHA-256")
        .digest(signature.toByteArray())
        .joinToString("") { "%02x".format(it) }
    }.toSet()
  }
}
