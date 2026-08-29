package com.backpackr.util;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * BUG FIX (Feature request - location accuracy / MAPS_LINK not being used):
 *
 * "Add a Place" always asked contributors to type exact decimal
 * latitude/longitude themselves. Almost nobody knows those numbers off the
 * top of their head, so in practice the fields were routinely left blank
 * (defaulting to 0.0/0.0 - see AddPlaceServlet) or filled with guesses,
 * which is why places were showing up on the map hundreds/thousands of
 * kilometres off (e.g. near (0,0) in the Gulf of Guinea).
 *
 * Google Maps links, on the other hand, are something everyone already
 * knows how to get (Share -> Copy link from the Maps app/site) - and they
 * almost always have the coordinates embedded directly in the URL. This
 * class extracts them, so AddPlaceServlet can auto-fill latitude/longitude
 * from a pasted Maps link instead of requiring the contributor to hand-type
 * coordinates.
 *
 * Handles the common URL shapes:
 *   .../@12.9716,77.5946,15z                (map camera position)
 *   .../place/.../data=...!3d12.9716!4d77.5946   (the actual place pin)
 *   ...?q=12.9716,77.5946
 *   ...?ll=12.9716,77.5946
 * and shortened links (maps.app.goo.gl/..., goo.gl/maps/...) by following
 * the HTTP redirect chain to the real URL first.
 */
public final class GoogleMapsLinkParser {

    private GoogleMapsLinkParser() {
    }

    // !3d / !4d wins when present - it's the actual pinned place, not just
    // wherever the map camera happened to be centered.
    private static final Pattern PIN_PATTERN =
        Pattern.compile("!3d(-?\\d{1,3}\\.\\d+)!4d(-?\\d{1,3}\\.\\d+)");
    private static final Pattern AT_PATTERN =
        Pattern.compile("@(-?\\d{1,3}\\.\\d+),(-?\\d{1,3}\\.\\d+)");
    private static final Pattern QUERY_PATTERN =
        Pattern.compile("[?&](?:q|ll|query)=(-?\\d{1,3}\\.\\d+),(-?\\d{1,3}\\.\\d+)");

    public static final class LatLng {
        public final double latitude;
        public final double longitude;

        public LatLng(double latitude, double longitude) {
            this.latitude = latitude;
            this.longitude = longitude;
        }
    }

    /**
     * @return the coordinates embedded in the link, or null if none could
     * be found (e.g. a link that only encodes a place name/ID with no
     * visible lat/lng, or the link couldn't be reached at all).
     */
    public static LatLng extract(String mapsLink) {
        if (mapsLink == null || mapsLink.isBlank()) return null;

        LatLng found = tryPatterns(mapsLink);
        if (found != null) return found;

        // Short links (maps.app.goo.gl, goo.gl/maps) don't carry the
        // coordinates themselves - only the server-side redirect target
        // does. Follow up to a few hops looking for them.
        String current = mapsLink;
        for (int hop = 0; hop < 5; hop++) {
            String next = resolveRedirect(current);
            if (next == null || next.equals(current)) break;
            found = tryPatterns(next);
            if (found != null) return found;
            current = next;
        }
        return null;
    }

    private static LatLng tryPatterns(String url) {
        Matcher m = PIN_PATTERN.matcher(url);
        if (m.find()) return toLatLng(m);

        m = AT_PATTERN.matcher(url);
        if (m.find()) return toLatLng(m);

        m = QUERY_PATTERN.matcher(url);
        if (m.find()) return toLatLng(m);

        return null;
    }

    private static LatLng toLatLng(Matcher m) {
        try {
            double lat = Double.parseDouble(m.group(1));
            double lng = Double.parseDouble(m.group(2));
            if (isPlausible(lat, lng)) {
                return new LatLng(lat, lng);
            }
        } catch (NumberFormatException ignored) {
            // fall through
        }
        return null;
    }

    private static boolean isPlausible(double lat, double lng) {
        // Rules out (0,0) and any obviously out-of-range junk.
        return (lat != 0.0 || lng != 0.0)
                && lat >= -90 && lat <= 90
                && lng >= -180 && lng <= 180;
    }

    private static String resolveRedirect(String url) {
        try {
            HttpClient client = HttpClient.newBuilder()
                    .followRedirects(HttpClient.Redirect.NEVER)
                    .connectTimeout(Duration.ofSeconds(5))
                    .build();
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(5))
                    .GET()
                    .build();
            HttpResponse<Void> response = client.send(request, HttpResponse.BodyHandlers.discarding());
            int status = response.statusCode();
            if (status >= 300 && status < 400) {
                return response.headers().firstValue("Location").orElse(null);
            }
        } catch (Exception e) {
            // Network hiccup, malformed URL, or the link host is
            // unreachable from this server - just means auto-extraction
            // doesn't succeed; the caller falls back to whatever
            // latitude/longitude the contributor typed manually.
        }
        return null;
    }
}
