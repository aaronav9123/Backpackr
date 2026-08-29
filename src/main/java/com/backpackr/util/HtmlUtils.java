package com.backpackr.util;

/**
 * BUG FIX (Code Review - Security: stored/reflected XSS):
 *
 * Every JSP in the project used to print user-controlled values (place
 * names/descriptions/addresses submitted through "Add Place", trip names,
 * AI notes, the ?q= search box, etc.) straight into HTML with plain
 * <%= ... %> expressions and no escaping at all. Because "Add Place"
 * publishes instantly with no moderation step, anything a community member
 * typed into e.g. the description field - including a &lt;script&gt; tag -
 * was rendered verbatim to every other visitor's browser (stored XSS). The
 * ?q= search box reflected the raw query back into the page the same way
 * (reflected XSS).
 *
 * This is a tiny, dependency-free HTML-escaping helper (no JSTL/taglib
 * needed, so the stack is untouched) used from JSP scriptlets/expressions
 * as e.g. <%= HtmlUtils.esc(p.getPlaceName()) %> anywhere a value that
 * originated from user input (community contributions, search terms, trip
 * names, etc.) is rendered.
 */
public final class HtmlUtils {

    private HtmlUtils() {
    }

    /** Escapes text for safe placement inside HTML element content or an attribute value. */
    public static String esc(Object value) {
        if (value == null) return "";
        String s = String.valueOf(value);
        StringBuilder sb = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '&': sb.append("&amp;"); break;
                case '<': sb.append("&lt;"); break;
                case '>': sb.append("&gt;"); break;
                case '"': sb.append("&quot;"); break;
                case '\'': sb.append("&#x27;"); break;
                default: sb.append(c);
            }
        }
        return sb.toString();
    }

    /** Escapes text for safe placement inside a single-quoted or double-quoted JavaScript string literal. */
    public static String escJs(Object value) {
        if (value == null) return "";
        String s = String.valueOf(value);
        StringBuilder sb = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '\\': sb.append("\\\\"); break;
                case '"': sb.append("\\\""); break;
                case '\'': sb.append("\\'"); break;
                case '\n': sb.append("\\n"); break;
                case '\r': sb.append("\\r"); break;
                case '<': sb.append("\\x3C"); break;
                case '>': sb.append("\\x3E"); break;
                default: sb.append(c);
            }
        }
        return sb.toString();
    }
}
