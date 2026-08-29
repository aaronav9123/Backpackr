package com.backpackr.util;

import java.io.IOException;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.FilterConfig;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.annotation.WebFilter;

/**
 * BUG FIX (Visual bug: every emoji/icon in the sidebar, headers, and
 * buttons renders as garbled boxes - "ð..." tofu characters - instead of
 * the actual emoji, in every screenshot across this whole project):
 *
 * Every JSP already correctly declares
 * <%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>,
 * and the .jsp source files themselves are genuinely valid UTF-8 on disk
 * (verified directly). Despite that, some Tomcat/JVM configurations don't
 * fully honor the page directive's charset when writing the final response
 * bytes - depending on the server's default platform encoding (very
 * commonly Windows-1252/Cp1252 on a Windows machine, which is exactly what
 * this project is being run on), Jasper can still emit multi-byte UTF-8
 * characters (like the 4-byte emoji used throughout Backpackr) using the
 * wrong byte encoding. The browser then has no way to know the bytes were
 * mis-encoded and renders exactly the corrupted-looking boxes seen in
 * every screenshot.
 *
 * The reliable, environment-independent fix is a filter that explicitly
 * sets both the request and response character encoding to UTF-8 before
 * anything else runs, on every single request - this is the standard,
 * well-known fix for this class of Tomcat/Jasper encoding issue, and does
 * not require editing any server configuration outside the app itself
 * (no web.xml/context.xml changes needed - @WebFilter registers this
 * automatically, the same way @WebServlet/@WebListener already do
 * elsewhere in this project).
 */
@WebFilter("/*")
public class CharacterEncodingFilter implements Filter {

    @Override
    public void init(FilterConfig filterConfig) throws ServletException {
        // No setup needed.
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        request.setCharacterEncoding("UTF-8");
        response.setCharacterEncoding("UTF-8");
        chain.doFilter(request, response);
    }

    @Override
    public void destroy() {
        // No cleanup needed.
    }
}
