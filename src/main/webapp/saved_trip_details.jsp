<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="com.backpackr.model.User" %>
<%@ page import="com.backpackr.model.Trip" %>
<%@ page import="com.backpackr.model.TripStop" %>
<%@ page import="com.backpackr.dao.TripDAO" %>
<%@ page import="com.backpackr.dao.TripStopDAO" %>
<%@ page import="com.backpackr.util.AIPlannerService" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.LinkedHashMap" %>
<%@ page import="java.util.Map" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%@ page import="com.backpackr.util.HtmlUtils" %>

<%!
    // Generates a friendly suggested time slot for a stop based on its
    // position within its day. There is no time-of-day column on
    // TRIP_STOPS, so this is a deterministic display schedule (starting at
    // 9:00 AM, ~3.5 hrs apart) computed from real stop order/day data
    // rather than any fixed per-trip value.
    private String suggestedStopTime(int indexInDay) {
        int totalMinutes = 9 * 60 + (indexInDay * 210); // 9:00 AM + 3h30m per stop
        totalMinutes = totalMinutes % (24 * 60);
        int hour24 = totalMinutes / 60;
        int minute = totalMinutes % 60;
        String ampm = (hour24 >= 12) ? "PM" : "AM";
        int hour12 = hour24 % 12;
        if (hour12 == 0) hour12 = 12;
        return String.format("%d:%02d %s", hour12, minute, ampm);
    }
%>

<%
    // Session validation
    User currentUser = (User) session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    String activePage = "savedtrips";

    String tripIdParam = request.getParameter("tripId");
    if (tripIdParam == null || tripIdParam.trim().isEmpty()) {
        response.sendRedirect("saved_trips.jsp?error=No+trip+specified");
        return;
    }

    TripDAO tripDAO = new TripDAO();
    TripStopDAO tripStopDAO = new TripStopDAO();

    int tripId;
    try {
        tripId = Integer.parseInt(tripIdParam);
    } catch (NumberFormatException e) {
        response.sendRedirect("saved_trips.jsp?error=Invalid+trip");
        return;
    }

    Trip trip = tripDAO.getTripById(tripId);
    if (trip == null || trip.getUserId() != currentUser.getUserId()) {
        response.sendRedirect("saved_trips.jsp?error=Trip+not+found");
        return;
    }

    List<TripStop> stops = tripStopDAO.getStopsForTrip(tripId);

    // Group by day, preserving day order (DAO already orders by day then stop order)
    Map<Integer, List<TripStop>> byDay = new LinkedHashMap<>();
    for (TripStop s : stops) {
        byDay.computeIfAbsent(s.getDayNumber(), k -> new java.util.ArrayList<>()).add(s);
    }

    // Cover image: first stop's image, reusing existing PLACES.IMAGE_URL data
    String coverImage = "https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=1600&q=80";
    for (TripStop s : stops) {
        if (s.getImageUrl() != null && !s.getImageUrl().trim().isEmpty()) {
            coverImage = s.getImageUrl();
            break;
        }
    }

    double[] breakdown = AIPlannerService.estimateBudgetBreakdown(trip.getTotalBudget());
    double transportEst = breakdown[0];
    double stayEst = breakdown[1];
    double foodEst = breakdown[2];

    SimpleDateFormat displayDateFormat = new SimpleDateFormat("MMM dd, yyyy");
    String createdStr = (trip.getCreatedDate() != null) ? displayDateFormat.format(trip.getCreatedDate()) : "";
    // TRIPS has no UPDATED_DATE column in the existing schema (which we are
    // not modifying), so "last updated" reflects the same real created-date
    // value until an update-tracking column exists.
    String updatedStr = createdStr;

    boolean openEditOnLoad = "1".equals(request.getParameter("edit"));

    String notes = (trip.getAiSummary() != null && !trip.getAiSummary().trim().isEmpty())
            ? trip.getAiSummary()
            : "No notes yet for this trip. Use \"Plan with AI\" from My Trips to generate personalized notes and tips.";
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backpackr - <%= HtmlUtils.esc(trip.getTripName()) %></title>
    <link rel="stylesheet" href="css/style.css?v=3">
    <link rel="stylesheet" href="css/saved_trips.css?v=3">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
</head>
<body class="st-theme">

<div class="app-container">

    <%@ include file="_sidebar.jsp" %>

    <main class="main-content">

        <a href="saved_trips.jsp" class="st-back-link">← Back to Saved Trips</a>

        <% if (request.getParameter("success") != null) { %>
            <div class="alert alert-success">✅ <%= HtmlUtils.esc(request.getParameter("success")) %></div>
        <% } %>
        <% if (request.getParameter("error") != null) { %>
            <div class="alert alert-error">❌ <%= HtmlUtils.esc(request.getParameter("error")) %></div>
        <% } %>

        <div class="st-detail-topbar">
            <div></div>
            <div class="st-detail-actions">
                <button type="button" class="btn btn-secondary" onclick="openEditModal()">✏️ Edit Trip</button>
                <button type="button" class="btn btn-secondary" onclick="shareTrip()">🔗 Share</button>
                <form action="trip" method="post" onsubmit="return confirm('Delete this trip? This cannot be undone.');">
                    <input type="hidden" name="action" value="delete">
                    <input type="hidden" name="tripId" value="<%= trip.getTripId() %>">
                    <input type="hidden" name="redirect" value="saved_trips.jsp">
                    <button type="submit" class="btn btn-danger">🗑️ Delete</button>
                </form>
            </div>
        </div>

        <!-- Hero banner -->
        <div class="st-hero" style="background-image: url('<%= HtmlUtils.esc(coverImage) %>');">
            <div class="st-hero-content">
                <div class="st-hero-title-row">
                    <h1><%= HtmlUtils.esc(trip.getTripName()) %></h1>
                    <% if (trip.getStartLocation() != null && !trip.getStartLocation().trim().isEmpty()) { %>
                        <span class="st-badge st-hero-badge"><%= HtmlUtils.esc(trip.getStartLocation()) %></span>
                    <% } %>
                </div>
                <div class="st-hero-stats">
                    <span>⏱️ <%= trip.getTotalDays() %> Day<%= trip.getTotalDays() == 1 ? "" : "s" %></span>
                    <span>💰 Rs. <%= (int) trip.getTotalBudget() %> Budget</span>
                    <span>📍 <%= stops.size() %> Stop<%= stops.size() == 1 ? "" : "s" %></span>
                </div>
                <div class="st-hero-dates">Created on <%= createdStr %> &bull; Last updated on <%= updatedStr %></div>
            </div>
        </div>

        <div class="st-detail-grid">
            <!-- Left column -->
            <div>
                <div class="st-panel">
                    <h3>Itinerary Stops</h3>

                    <% if (stops.isEmpty()) { %>
                        <p style="color:#64748B; font-size:0.9rem;">No stops added to this trip yet.</p>
                    <% } else {
                        for (Map.Entry<Integer, List<TripStop>> entry : byDay.entrySet()) {
                            List<TripStop> dayStops = entry.getValue();
                    %>
                        <% if (byDay.size() > 1) { %>
                            <div class="day-group-title" style="margin-top: 18px;">📅 Day <%= entry.getKey() %></div>
                        <% } %>
                        <div class="st-timeline">
                            <%
                                for (int i = 0; i < dayStops.size(); i++) {
                                    TripStop stop = dayStops.get(i);
                                    String catClass = "badge-gem";
                                    if ("Budget Food".equals(stop.getCategory())) catClass = "badge-food";
                                    else if ("Local Attraction".equals(stop.getCategory())) catClass = "badge-attraction";
                                    else if ("Scenic Spot".equals(stop.getCategory())) catClass = "badge-scenic";
                            %>
                                <div class="st-timeline-item">
                                    <div class="st-timeline-marker"><%= stop.getStopOrder() %></div>
                                    <div class="st-timeline-body">
                                        <div class="st-timeline-info">
                                            <h4>
                                                <%= HtmlUtils.esc(stop.getPlaceName()) %>
                                                <span class="st-timeline-category <%= catClass %>"><%= HtmlUtils.esc(stop.getCategory()) %></span>
                                            </h4>
                                            <p><%= HtmlUtils.esc(stop.getDistrict()) %><%= (stop.getState() != null && !stop.getState().trim().isEmpty()) ? ", " + HtmlUtils.esc(stop.getState()) : "" %> &bull; Day <%= stop.getDayNumber() %> &bull; <%= suggestedStopTime(i) %></p>
                                        </div>
                                        <div class="st-timeline-thumb" style="background-image: url('<%= HtmlUtils.esc(stop.getImageUrl()) %>');"></div>
                                    </div>
                                </div>
                            <% } %>
                        </div>
                    <% } } %>
                </div>

                <div class="st-panel">
                    <h3>Notes</h3>
                    <p class="st-notes-text"><%= HtmlUtils.esc(notes) %></p>
                </div>
            </div>

            <!-- Right column -->
            <div>
                <div class="st-panel">
                    <h3>Map Overview</h3>
                    <div id="tripMap" class="st-map-box"></div>
                </div>

                <div class="st-panel">
                    <h3>Budget Summary</h3>
                    <div class="st-budget-row st-budget-highlight">
                        <span>Estimated Budget</span>
                        <strong>Rs. <%= (int) trip.getTotalBudget() %></strong>
                    </div>
                    <div class="st-budget-row">
                        <span>Total Stops</span>
                        <strong><%= stops.size() %></strong>
                    </div>
                    <div class="st-budget-row">
                        <span>Transport (Est.)</span>
                        <strong>Rs. <%= (int) transportEst %></strong>
                    </div>
                    <div class="st-budget-row">
                        <span>Stay (Est.)</span>
                        <strong>Rs. <%= (int) stayEst %></strong>
                    </div>
                    <div class="st-budget-row">
                        <span>Food (Est.)</span>
                        <strong>Rs. <%= (int) foodEst %></strong>
                    </div>
                </div>
            </div>
        </div>

    </main>

</div>

<!-- Edit Trip Modal -->
<div class="st-modal-overlay" id="editModalOverlay">
    <div class="st-modal">
        <h3>Edit Trip</h3>
        <form action="trip" method="post">
            <input type="hidden" name="action" value="update">
            <input type="hidden" name="tripId" value="<%= trip.getTripId() %>">
            <input type="hidden" name="redirect" value="saved_trip_details.jsp?tripId=<%= trip.getTripId() %>">

            <div class="form-group">
                <label class="form-label" for="editTripName">Trip Title</label>
                <input type="text" id="editTripName" name="tripName" class="form-control" value="<%= HtmlUtils.esc(trip.getTripName()) %>" required>
            </div>
            <div class="form-group">
                <label class="form-label" for="editStartLocation">Destination</label>
                <input type="text" id="editStartLocation" name="startLocation" class="form-control" value="<%= HtmlUtils.esc(trip.getStartLocation()) %>" required>
            </div>
            <div class="form-group" style="display:grid; grid-template-columns:1fr 1fr; gap:16px;">
                <div>
                    <label class="form-label" for="editTotalBudget">Budget (Rs)</label>
                    <input type="number" id="editTotalBudget" name="totalBudget" class="form-control" min="500" max="1000000" value="<%= (int) trip.getTotalBudget() %>" required>
                </div>
                <div>
                    <label class="form-label" for="editTotalDays">Duration (Days)</label>
                    <input type="number" id="editTotalDays" name="totalDays" class="form-control" min="1" max="90" value="<%= trip.getTotalDays() %>" required>
                </div>
            </div>

            <div class="st-modal-actions">
                <button type="button" class="btn btn-secondary" onclick="closeEditModal()">Cancel</button>
                <button type="submit" class="btn btn-primary">Save Changes</button>
            </div>
        </form>
    </div>
</div>

<div id="toast" class="toast"></div>

<script>
    function openEditModal() {
        document.getElementById('editModalOverlay').classList.add('st-open');
    }
    function closeEditModal() {
        document.getElementById('editModalOverlay').classList.remove('st-open');
    }
    <% if (openEditOnLoad) { %>
        window.addEventListener('DOMContentLoaded', openEditModal);
    <% } %>

    function shareTrip() {
        const url = window.location.href;
        if (navigator.share) {
            navigator.share({ title: "<%= HtmlUtils.escJs(trip.getTripName()) %>", url: url }).catch(function() {});
        } else if (navigator.clipboard) {
            navigator.clipboard.writeText(url).then(function() {
                var toast = document.getElementById('toast');
                if (toast) {
                    toast.textContent = 'Link copied to clipboard 🔗';
                    toast.classList.add('show');
                    setTimeout(function() { toast.classList.remove('show'); }, 2500);
                }
            });
        }
    }

    (function() {
        var stops = [
            <%
                for (int i = 0; i < stops.size(); i++) {
                    TripStop s = stops.get(i);
            %>
            { name: "<%= HtmlUtils.escJs(s.getPlaceName()) %>", lat: <%= s.getLatitude() %>, lng: <%= s.getLongitude() %>, order: <%= s.getStopOrder() %> }<%= (i < stops.size() - 1) ? "," : "" %>
            <% } %>
        ];

        var mapEl = document.getElementById('tripMap');
        if (!mapEl || stops.length === 0) {
            if (mapEl) mapEl.innerHTML = '<div style="display:flex;align-items:center;justify-content:center;height:100%;color:#94A3B8;font-size:0.85rem;">No stops to show on the map yet.</div>';
            return;
        }

        var map = L.map(mapEl).setView([stops[0].lat, stops[0].lng], 9);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy; OpenStreetMap contributors',
            maxZoom: 18
        }).addTo(map);

        var latlngs = [];
        stops.forEach(function(s) {
            var marker = L.marker([s.lat, s.lng]).addTo(map);
            marker.bindPopup('<b>' + s.order + '. ' + s.name + '</b>');
            latlngs.push([s.lat, s.lng]);
        });

        if (latlngs.length > 1) {
            var route = L.polyline(latlngs, { color: '#22C55E', weight: 4, opacity: 0.8 }).addTo(map);
            map.fitBounds(route.getBounds(), { padding: [30, 30] });
        }
    })();
</script>

</body>
</html>
