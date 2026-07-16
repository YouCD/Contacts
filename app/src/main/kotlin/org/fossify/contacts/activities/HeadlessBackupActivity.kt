package org.fossify.contacts.activities

import android.os.Bundle
import org.fossify.commons.helpers.ensureBackgroundThread
import org.fossify.commons.helpers.ContactsHelper
import org.fossify.commons.models.contacts.Contact
import org.fossify.contacts.helpers.VcfExporter
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class HeadlessBackupActivity : SimpleActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val defaultBase = getExternalFilesDir(null)?.absolutePath ?: cacheDir.absolutePath
        val rawOutputPath = intent.getStringExtra(OUTPUT_PATH)
            ?: "$defaultBase/ContactsBackup"
        val filename = intent.getStringExtra(FILENAME)
            ?: "contacts_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())}"
        val override = intent.getBooleanExtra(OVERRIDE, false)

        android.util.Log.d(TAG, "Requested backup path: $rawOutputPath/$filename.vcf")
        ensureBackgroundThread {
            doBackup(rawOutputPath, defaultBase, filename, override)
        }
    }

    private fun doBackup(rawOutputPath: String, defaultBase: String, filename: String, override: Boolean) {
        ContactsHelper(this).getContacts(true, false, HashSet()) { contacts ->
            if (contacts.isEmpty()) {
                android.util.Log.e(TAG, "No contacts found for export")
                finish()
                return@getContacts
            }

            var dir = File(rawOutputPath)
            if (!dir.isDirectory && !dir.mkdirs()) {
                android.util.Log.w(TAG, "Cannot access $rawOutputPath, falling back to app external files dir")
                dir = File("$defaultBase/ContactsBackup")
                dir.mkdirs()
            }

            var exportFile = File(dir, "$filename.vcf")
            var filePath = exportFile.absolutePath

            if (!override) {
                var num = 0
                while (exportFile.exists()) {
                    num++
                    exportFile = File(dir, "${filename}_${num}.vcf")
                    filePath = exportFile.absolutePath
                }
            }

            try {
                FileOutputStream(exportFile).use { outputStream ->
                    VcfExporter().exportContacts(
                        context = this,
                        outputStream = outputStream,
                        contacts = contacts,
                        showExportingToast = false
                    ) { result ->
                        when (result) {
                            VcfExporter.ExportResult.EXPORT_OK ->
                                android.util.Log.i(TAG, "Backup successful: $filePath (${contacts.size} contacts)")
                            VcfExporter.ExportResult.EXPORT_PARTIAL ->
                                android.util.Log.w(TAG, "Backup partially successful: $filePath")
                            VcfExporter.ExportResult.EXPORT_FAIL ->
                                android.util.Log.e(TAG, "Backup failed")
                        }
                        finish()
                    }
                }
            } catch (e: Exception) {
                android.util.Log.w(TAG, "Cannot write to $filePath, falling back to $defaultBase/ContactsBackup/${filename}.vcf")
                File("$defaultBase/ContactsBackup").mkdirs()
                val fallbackFile = File("$defaultBase/ContactsBackup/$filename.vcf")
                try {
                    FileOutputStream(fallbackFile).use { outputStream ->
                        VcfExporter().exportContacts(
                            context = this,
                            outputStream = outputStream,
                            contacts = contacts,
                            showExportingToast = false
                        ) { result ->
                            when (result) {
                                VcfExporter.ExportResult.EXPORT_OK ->
                                    android.util.Log.i(TAG, "Backup successful (fallback): ${fallbackFile.absolutePath} (${contacts.size} contacts)")
                                VcfExporter.ExportResult.EXPORT_PARTIAL ->
                                    android.util.Log.w(TAG, "Backup partially successful (fallback): ${fallbackFile.absolutePath}")
                                VcfExporter.ExportResult.EXPORT_FAIL ->
                                    android.util.Log.e(TAG, "Backup failed")
                            }
                            finish()
                        }
                    }
                } catch (e2: Exception) {
                    android.util.Log.e(TAG, "Backup failed entirely", e2)
                    finish()
                }
            }
        }
    }

    companion object {
        private const val TAG = "HeadlessBackup"
        const val OUTPUT_PATH = "output_path"
        const val FILENAME = "filename"
        const val OVERRIDE = "override"
    }
}
