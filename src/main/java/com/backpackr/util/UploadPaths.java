package com.backpackr.util;

import java.io.File;

import jakarta.servlet.ServletContext;

/**
 * Resolves where community-uploaded place photos are physically stored.
 *
 * BUG FIX (Bug 1 - uploaded images returning 404):
 * Saving uploads under getServletContext().getRealPath("/uploads") ties the
 * file location to whatever copy of the web app Eclipse/Tomcat happens to be
 * publishing from at that moment, which is not guaranteed to be the same
 * folder that answers real HTTP requests. To make uploads reliable no
 * matter how the project is deployed/republished, files are now written to
 * one fixed, absolute folder on disk, outside the web app deployment
 * directory entirely: "<user.home>/backpackr_uploads" (overridable with the
 * UPLOAD_DIR key in config.properties if you'd rather point it somewhere
 * else, e.g. a shared server path).
 */
public class UploadPaths {

    private UploadPaths() {
    }

    /**
     * The stable, absolute folder new uploads are written to and served from.
     */
    public static File getExternalUploadDir() {
        String configured = Config.get("UPLOAD_DIR", null);
        File dir = (configured != null && !configured.trim().isEmpty())
                ? new File(configured.trim())
                : new File(System.getProperty("user.home"), "backpackr_uploads");

        if (!dir.exists()) {
            dir.mkdirs();
        }
        return dir;
    }

    /**
     * Looks up a previously-saved upload by file name, checking the new
     * external folder first, then falling back to the old
     * webapp-relative /uploads folder for backward compatibility with any
     * files that were saved there before this fix.
     */
    public static File resolveExistingUploadFile(String fileName, ServletContext servletContext) {
        File externalFile = new File(getExternalUploadDir(), fileName);
        if (externalFile.isFile()) {
            return externalFile;
        }

        String legacyPath = servletContext.getRealPath("/uploads/" + fileName);
        if (legacyPath != null) {
            File legacyFile = new File(legacyPath);
            if (legacyFile.isFile()) {
                return legacyFile;
            }
        }

        return null;
    }
}
