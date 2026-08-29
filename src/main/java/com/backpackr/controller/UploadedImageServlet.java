package com.backpackr.controller;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

import com.backpackr.util.UploadPaths;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * BUG FIX (Bug 1 - uploaded images not displaying):
 *
 * AddPlaceServlet used to save uploaded photos under
 * getServletContext().getRealPath("/uploads"), which, depending on how
 * Eclipse/Tomcat publishes the project (exploded copy vs. "serve modules
 * without publishing"), does not always point at the same folder that
 * Tomcat's default static-file handling actually serves requests from.
 * That's why the console showed "IMAGE SAVED SUCCESSFULLY / Exists = true"
 * while the browser still got a 404 for the exact same file.
 *
 * The fix: uploaded photos are now written to a fixed, absolute folder
 * OUTSIDE the deployed web app (see UploadPaths), and this servlet is
 * explicitly mapped to /uploads/* so it always serves whatever is in that
 * folder directly - independent of how/where the WAR/exploded app was
 * published. It also falls back to the old webapp/uploads folder so any
 * image that happened to already be saved there keeps working.
 *
 * Nothing about the stored IMAGE_URL format changes ("uploads/filename.ext"),
 * so existing PLACES rows and all JSP/CSS that render p.getImageUrl() keep
 * working exactly as before.
 */
@WebServlet("/uploads/*")
public class UploadedImageServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String pathInfo = request.getPathInfo(); // e.g. "/place_xxxxx.jpeg"

        if (pathInfo == null || pathInfo.equals("/")) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }

        // Strip leading slash and guard against directory traversal.
        String fileName = pathInfo.substring(1);
        if (fileName.contains("..") || fileName.contains("/") || fileName.contains("\\")) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST);
            return;
        }

        File file = UploadPaths.resolveExistingUploadFile(fileName, getServletContext());

        if (file == null || !file.isFile()) {
            response.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }

        String mimeType = getServletContext().getMimeType(file.getName());
        if (mimeType == null) {
            mimeType = "application/octet-stream";
        }
        response.setContentType(mimeType);
        response.setContentLengthLong(file.length());
        response.setHeader("Cache-Control", "public, max-age=86400");

        try (InputStream in = new FileInputStream(file);
             OutputStream out = response.getOutputStream()) {
            in.transferTo(out);
        }
    }
}
