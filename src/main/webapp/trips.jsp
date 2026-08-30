<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="com.backpackr.model.User" %>
<%@ page import="com.backpackr.model.Trip" %>
<%@ page import="com.backpackr.model.TripStop" %>
<%@ page import="com.backpackr.dao.TripDAO" %>
<%@ page import="com.backpackr.dao.TripStopDAO" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.LinkedHashMap" %>
<%@ page import="java.util.Map" %>
<%@ page import="com.backpackr.util.HtmlUtils" %>

<%
    // Session validation
    User currentUser = (User) session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    String activePage = "trips";

    TripDAO tripDAO = new TripDAO();
    TripStopDAO tripStopDAO = new TripStopDAO();
    List<Trip> myTrips = tripDAO.getTripsByUser(currentUser.getUserId());
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backpackr - My Trips</title>
    <link rel="stylesheet" href="css/style.css?v=3">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

    <link rel="stylesheet" href="https://unpkg.com/leaflet-routing-machine@3.2.12/dist/leaflet-routing-machine.css" />
    <script src="https://unpkg.com/leaflet-routing-machine@3.2.12/dist/leaflet-routing-machine.js"></script>
</head>
<body>

<div class="app-container">

    <%@ include file="_sidebar.jsp" %>

    <!-- Main Content Workspace -->
    <main class="main-content">

        <!-- Header -->
        <header class="page-header">
            <div class="page-title">
                <h1>My Trips ✈️</h1>
                <p>Manage your itineraries, view your route on the map, and let AI plan for you.</p>
            </div>
            <div style="display:flex; gap:10px;">

                <a href="saved_trips.jsp" class="btn btn-secondary">🔖 Saved Trips Gallery</a>
                <a href="create_trip.jsp" class="btn btn-primary">➕ Create New Trip</a>
            </div>
        </header>

        <!-- Feedback Alert banners -->
        <% if (request.getParameter("success") != null) { %>
            <div class="alert alert-success">✅ <%= HtmlUtils.esc(request.getParameter("success")) %></div>
        <% } %>
        <% if (request.getParameter("error") != null) { %>
            <div class="alert alert-error">❌ <%= HtmlUtils.esc(request.getParameter("error")) %></div>
        <% } %>

        <!-- Trips List -->
        <section>
            <%
                if (myTrips.isEmpty()) {
            %>
                <div class="empty-state">
                    <h3>No trips planned yet</h3>
                    <p>Create a trip first, then search for local spots to add stops, or let AI plan it for you instantly.</p>
                    <a href="create_trip.jsp" class="btn btn-primary">Create Your First Trip</a>
                </div>
            <%
                } else {
                    for (Trip t : myTrips) {
                        List<TripStop> stops = tripStopDAO.getStopsForTrip(t.getTripId());

                        // Group stops by AI day number (defaults to Day 1 if not AI-planned)
                        Map<Integer, List<TripStop>> byDay = new LinkedHashMap<>();
                        for (TripStop s : stops) {
                            byDay.computeIfAbsent(s.getDayNumber(), k -> new java.util.ArrayList<>()).add(s);
                        }


                        double estimatedTripCost = 0;
                        for (TripStop s : stops) {
                            estimatedTripCost += s.getAvgCost();
                        }
                        boolean hasCostData = estimatedTripCost > 0;
            %>
                <article class="trip-card">
                    <div class="trip-header">
                        <div class="trip-title-details">
                            <h2>🗺️ <%= HtmlUtils.esc(t.getTripName()) %></h2>
                            <div class="trip-stats">
                                <% if (t.getStartLocation() != null && !t.getStartLocation().isBlank()) { %>
                                    <div class="trip-stat-item">📍 Destination: <span class="highlight"><%= HtmlUtils.esc(t.getStartLocation()) %></span></div>
                                <% } %>
                                <% if (hasCostData) { %>
                                    <div class="trip-stat-item">💰 Estimated Cost: <span class="highlight">Rs. <%= (int) estimatedTripCost %></span></div>
                                <% } %>
                                <div class="trip-stat-item">📅 Duration: <span class="highlight"><%= t.getTotalDays() %> days</span></div>
                                <div class="trip-stat-item">🎒 Stops: <span class="highlight"><%= stops.size() %></span></div>
                            </div>
                        </div>

                        <!-- Action Buttons -->
                        <div class="trip-actions">
                            <a href="saved_trip_details.jsp?tripId=<%= t.getTripId() %>" class="btn btn-secondary btn-sm">
                                🔎 View Details
                            </a>
 
                            <button type="button" class="btn btn-secondary btn-sm" style="color: #C4B5FD; border-color: rgba(139, 92, 246, 0.3);" onclick="openPlanModal_<%= t.getTripId() %>()">
                                🤖 Plan with AI
                            </button>

                            <form action="trip" method="post" style="display:inline;" onsubmit="return confirm('Are you sure you want to delete this entire trip?');">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="tripId" value="<%= t.getTripId() %>">
                                <button type="submit" class="btn btn-danger btn-sm">🗑️ Delete Trip</button>
                            </form>
                        </div>
                    </div>

                    <% if (t.getAiSummary() != null && !t.getAiSummary().trim().isEmpty()) { %>
                        <div class="ai-summary-banner">🤖 <%= HtmlUtils.esc(t.getAiSummary()) %></div>
                    <% } %>


                    <% if (stops.isEmpty()) { %>
                        <div style="padding: 4px 0 16px; text-align: center; color: var(--text-muted); font-size: 0.9rem;">
                            No stops added yet - search for places and tap <strong>➕ Add to Trip</strong>, or use <strong>Plan with AI</strong> above to find some.
                        </div>
                    <% } %>

                        <!-- Route Map (Leaflet + OpenStreetMap - no API key required) -->

                        <div class="trip-map-wrap">
                            <div class="trip-nav-toolbar">
                                <button type="button" class="btn-locate" id="locate-btn-<%= t.getTripId() %>" onclick="backpackrStartLiveNav_<%= t.getTripId() %>()">
                                    📍 Use My Current Location
                                </button>
                                <div class="route-summary-badge" id="route-summary-<%= t.getTripId() %>" style="display:none;"></div>
                            </div>
                            <div id="map-<%= t.getTripId() %>" class="trip-map"></div>
                            <div class="route-status" id="route-status-<%= t.getTripId() %>"></div>
                        </div>


                        <div class="nav-modal" id="nav-modal-<%= t.getTripId() %>">
                            <div class="nav-modal-topbar">
                                <div class="nav-modal-route-info" id="nav-modal-info-<%= t.getTripId() %>"></div>
                                <button type="button" class="nav-modal-close" onclick="document.getElementById('nav-modal-<%= t.getTripId() %>').classList.remove('open');">✕</button>
                            </div>
                            <div class="nav-modal-body">
                                <div class="nav-modal-steps" id="nav-modal-steps-<%= t.getTripId() %>"></div>
                                <div class="nav-modal-map" id="nav-modal-map-<%= t.getTripId() %>"></div>
                            </div>
                        </div>


                        <div class="nav-modal" id="plan-modal-<%= t.getTripId() %>">
                            <div class="nav-modal-topbar">
                                <div class="nav-modal-route-info"><span>🤖 Plan with AI</span></div>
                                <button type="button" class="nav-modal-close" onclick="document.getElementById('plan-modal-<%= t.getTripId() %>').classList.remove('open');">✕</button>
                            </div>
                            <div class="plan-modal-body">
                                <div class="plan-modal-controls">
                                    <div class="plan-mode-tabs">
                                        <button type="button" class="plan-mode-tab active" data-mode="distance" onclick="setPlanMode_<%= t.getTripId() %>('distance')">📏 Distance</button>
                                        <button type="button" class="plan-mode-tab" data-mode="time" onclick="setPlanMode_<%= t.getTripId() %>('time')">⏱️ Time</button>
                                        <button type="button" class="plan-mode-tab" data-mode="location" onclick="setPlanMode_<%= t.getTripId() %>('location')">📍 Location</button>
                                    </div>

                                    <div class="plan-mode-field" data-mode-field="distance">
                                        <label class="form-label">Within how many km?</label>
                                        <input type="number" class="form-control" id="plan-radiusKm-<%= t.getTripId() %>" value="25" min="1" max="500">
                                    </div>
                                    <div class="plan-mode-field" data-mode-field="time" style="display:none;">
                                        <label class="form-label">Reachable within how many minutes?</label>
                                        <input type="number" class="form-control" id="plan-maxMinutes-<%= t.getTripId() %>" value="30" min="1" max="600">
                                    </div>
                                    <div class="plan-mode-field" data-mode-field="location" style="display:none;">
                                        <label class="form-label">Search by district, state, or place name</label>
                                        <input type="text" class="form-control" id="plan-location-<%= t.getTripId() %>" placeholder="e.g. Kollam, Kerala">
                                    </div>

                                    <div class="plan-anchor-note" id="plan-anchor-note-<%= t.getTripId() %>"></div>

                                    <button type="button" class="btn btn-primary" style="width:100%;" onclick="runPlanSearch_<%= t.getTripId() %>()" id="plan-search-btn-<%= t.getTripId() %>">
                                        🔎 Find Places
                                    </button>
                                </div>
                                <div class="plan-modal-results" id="plan-results-<%= t.getTripId() %>">
                                    <div class="plan-results-empty">Choose a mode and search to see matching places here.</div>
                                </div>
                            </div>
                        </div>

                        <!-- Day-wise itinerary -->
                        <%
                            for (Map.Entry<Integer, List<TripStop>> entry : byDay.entrySet()) {
                                boolean showDayHeader = byDay.size() > 1;
                        %>
                            <div class="day-group">
                                <% if (showDayHeader) { %>
                                    <div class="day-group-title">📅 Day <%= entry.getKey() %></div>
                                <% } %>
                                <div class="timeline">
                                    <%
                                        List<TripStop> dayStops = entry.getValue();
                                        for (int i = 0; i < dayStops.size(); i++) {
                                            TripStop stop = dayStops.get(i);
                                            String catClass = "badge-gem";
                                            if ("Budget Food".equals(stop.getCategory())) catClass = "badge-food";
                                            else if ("Local Attraction".equals(stop.getCategory())) catClass = "badge-attraction";
                                            else if ("Scenic Spot".equals(stop.getCategory())) catClass = "badge-scenic";
                                    %>
                                        <div class="timeline-item">
                                            <div class="timeline-marker" data-order="<%= stop.getStopOrder() %>"></div>
                                            <div class="timeline-content">
                                                <div class="timeline-place-info">
                                                    <div class="timeline-place-thumb" style="background-image: url('<%= stop.getImageUrl() %>');"></div>
                                                    <div class="timeline-place-meta">
                                                        <h4>
                                                            <%= HtmlUtils.esc(stop.getPlaceName()) %>
                                                            <span class="timeline-place-category <%= catClass %>" style="padding: 2px 6px; font-size:0.65rem; border-radius: 4px; color:white;">
                                                                <%= HtmlUtils.esc(stop.getCategory()) %>
                                                            </span>
                                                        </h4>
                                                        <%
                                                            boolean stopHasLocation = (stop.getLatitude() != 0.0 || stop.getLongitude() != 0.0)
                                                                    && stop.getLatitude() >= -90 && stop.getLatitude() <= 90
                                                                    && stop.getLongitude() >= -180 && stop.getLongitude() <= 180;
                                                        %>
                                                        <%-- BUG FIX (Location accuracy): showing "Coordinates: 0.000, 0.000"
                                                             for every stop with no real location looked like the app itself
                                                             was broken. Now says plainly that the location hasn't been
                                                             pinned instead of printing a fake-looking coordinate pair. --%>
                                                        <p>📍 District: <%= HtmlUtils.esc(stop.getDistrict()) %> &bull;
                                                        <% if (stopHasLocation) { %>
                                                            Coordinates: <%= String.format("%.3f", stop.getLatitude()) %>, <%= String.format("%.3f", stop.getLongitude()) %>
                                                        <% } else { %>
                                                            <span style="color:#DC2626;">Location not pinned yet</span>
                                                        <% } %>
                                                        </p>
                                                        <% if (stop.getAiNote() != null && !stop.getAiNote().trim().isEmpty()) { %>
                                                            <p class="ai-note">🤖 <%= HtmlUtils.esc(stop.getAiNote()) %></p>
                                                        <% } %>
                                                    </div>
                                                </div>
                                                <div>
                                                    <form action="trip" method="post" style="display:inline;">
                                                        <input type="hidden" name="action" value="deleteStop">
                                                        <input type="hidden" name="stopId" value="<%= stop.getStopId() %>">
                                                        <input type="hidden" name="tripId" value="<%= t.getTripId() %>">
                                                        <button type="submit" class="btn btn-danger btn-sm" style="padding: 6px 12px; font-size: 0.8rem;">Remove</button>
                                                    </form>
                                                </div>
                                            </div>
                                        </div>
                                    <% } %>
                                </div>
                            </div>
                        <% } %>

                        <script>
                        (function() {
                            var tripId = <%= t.getTripId() %>;
                            var stops = [
                                <%
                                    for (int i = 0; i < stops.size(); i++) {
                                        TripStop s = stops.get(i);
                                %>
                                { name: "<%= HtmlUtils.escJs(s.getPlaceName()) %>", lat: <%= s.getLatitude() %>, lng: <%= s.getLongitude() %>, order: <%= s.getStopOrder() %> }<%= (i < stops.size() - 1) ? "," : "" %>
                                <% } %>
                            ];

                            var mapEl = document.getElementById('map-' + tripId);
                            var locateBtn = document.getElementById('locate-btn-' + tripId);
                            var summaryEl = document.getElementById('route-summary-' + tripId);
                            var statusEl = document.getElementById('route-status-' + tripId);
                            var navModalEl = document.getElementById('nav-modal-' + tripId);
                            var navModalInfoEl = document.getElementById('nav-modal-info-' + tripId);
                            var navModalStepsEl = document.getElementById('nav-modal-steps-' + tripId);
                            var navModalMapEl = document.getElementById('nav-modal-map-' + tripId);


                            var map = null;
                            var validStops = [];
                            var routingControl = null;
                            var userMarker = null;
                            var watchId = null;
                            var lastRecalcLatLng = null;

                            var lastRoute = null;
                            var navModalMap = null;
                            var navModalRouteLayer = null;
                            var navModalMarkers = [];
                            var navModalFormatter = null;


                            var baseStraightLineRoute = null;

                            var youAreHereIcon = L.divIcon({
                                className: 'you-are-here-icon',
                                html: '<span class="you-are-here-pulse"></span><span class="you-are-here-dot"></span>',
                                iconSize: [22, 22],
                                iconAnchor: [11, 11]
                            });

                            function metersToText(m) {
                                return m >= 1000 ? (m / 1000).toFixed(1) + ' km' : Math.round(m) + ' m';
                            }
                            function secondsToText(s) {
                                var mins = Math.round(s / 60);
                                if (mins < 60) return mins + ' min';
                                var hrs = Math.floor(mins / 60);
                                var rem = mins % 60;
                                return hrs + ' hr ' + (rem > 0 ? rem + ' min' : '');
                            }
                            function haversineMeters(a, b) {
                                var R = 6371000, rad = Math.PI / 180;
                                var dLat = (b.lat - a.lat) * rad, dLng = (b.lng - a.lng) * rad;
                                var s = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                                    Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
                                return 2 * R * Math.atan2(Math.sqrt(s), Math.sqrt(1 - s));
                            }
                            function describeGeoError(err) {
                                switch (err.code) {
                                    case err.PERMISSION_DENIED:
                                        return 'Location access was denied - allow location access in your browser to use live navigation.';
                                    case err.POSITION_UNAVAILABLE:
                                        return 'Your location is currently unavailable. Try again in a moment.';
                                    case err.TIMEOUT:
                                        return 'Timed out getting your location. Try again.';
                                    default:
                                        return 'Could not get your location.';
                                }
                            }


                            function iconForInstruction(instr) {
                                var type = (instr.type || '').toLowerCase();
                                var modifier = (instr.modifier || '').toLowerCase();
                                if (type === 'depart') return '\uD83D\uDFE2';
                                if (type === 'arrive') return '\uD83C\uDFC1';
                                if (type === 'roundabout' || type === 'rotary') return '\uD83D\uDD04';
                                if (modifier.indexOf('left') !== -1) return '\u2B05\uFE0F';
                                if (modifier.indexOf('right') !== -1) return '\u27A1\uFE0F';
                                if (modifier.indexOf('uturn') !== -1) return '\u21A9\uFE0F';
                                return '\u2B06\uFE0F';
                            }


                            function renderNavModalContent() {
                                if (!lastRoute) return;

                                if (!navModalFormatter) {
                                    navModalFormatter = new L.Routing.Formatter();
                                }

                                // --- Top bar distance/time ---
                                var summary = lastRoute.summary;
                                navModalInfoEl.innerHTML =
                                    '<span>\uD83D\uDE97 ' + metersToText(summary.totalDistance) + '</span>' +
                                    '<span>\u23F1\uFE0F ' + secondsToText(summary.totalTime) + '</span>';

                                // --- Turn-by-turn steps list ---
                                navModalStepsEl.innerHTML = '';
                                (lastRoute.instructions || []).forEach(function(instr, i) {
                                    var text = navModalFormatter.formatInstruction(instr, i);
                                    var distanceText = instr.distance > 0 ? navModalFormatter.formatDistance(instr.distance, 1) : '';
                                    var stepEl = document.createElement('div');
                                    stepEl.className = 'nav-step';
                                    stepEl.innerHTML =
                                        '<span class="nav-step-icon">' + iconForInstruction(instr) + '</span>' +
                                        '<span class="nav-step-text"></span>' +
                                        '<span class="nav-step-distance"></span>';
                                    // Set text via textContent (not innerHTML) so
                                    // nothing in a road/place name from the
                                    // routing service can inject markup.
                                    stepEl.querySelector('.nav-step-text').textContent = text;
                                    stepEl.querySelector('.nav-step-distance').textContent = distanceText;
                                    navModalStepsEl.appendChild(stepEl);
                                });

                                // --- Focused route map ---
                                if (!navModalMap) {
                                    navModalMap = L.map(navModalMapEl);
                                    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                                        attribution: '&copy; OpenStreetMap contributors',
                                        maxZoom: 18
                                    }).addTo(navModalMap);
                                }

                                if (navModalRouteLayer) {
                                    navModalMap.removeLayer(navModalRouteLayer);
                                }
                                navModalMarkers.forEach(function(m) { navModalMap.removeLayer(m); });
                                navModalMarkers = [];

                                navModalRouteLayer = L.polyline(lastRoute.coordinates, { color: '#22C55E', weight: 5, opacity: 0.9 }).addTo(navModalMap);

                                var startMarker = L.marker(lastRoute.coordinates[0], { icon: youAreHereIcon, zIndexOffset: 1000 })
                                    .addTo(navModalMap).bindPopup('<b>\uD83D\uDCCD You are here</b>');
                                navModalMarkers.push(startMarker);

                                validStops.forEach(function(s) {
                                    var stopMarker = L.marker([s.lat, s.lng]).addTo(navModalMap)
                                        .bindPopup('<b>' + s.order + '. ' + s.name + '</b>');
                                    navModalMarkers.push(stopMarker);
                                });

                                navModalMap.fitBounds(navModalRouteLayer.getBounds(), { padding: [30, 30] });
                            }

                            function openNavModal() {
                                if (!lastRoute) return;
                                navModalEl.classList.add('open');
                                renderNavModalContent();
                                // Leaflet maps initialized while their
                                // container is display:none report a zero
                                // size - now that the modal is visible,
                                // force it to re-measure and redraw.
                                if (navModalMap) {
                                    setTimeout(function() { navModalMap.invalidateSize(); }, 50);
                                }
                            }

                            function buildOrUpdateRoute(current) {

                                if (baseStraightLineRoute) {
                                    map.removeLayer(baseStraightLineRoute);
                                    baseStraightLineRoute = null;
                                }

                                var waypoints = [L.latLng(current.lat, current.lng)];
                                validStops.forEach(function(s) { waypoints.push(L.latLng(s.lat, s.lng)); });

                                if (routingControl) {
                                    routingControl.setWaypoints(waypoints);
                                    return;
                                }

                                routingControl = L.Routing.control({
                                    waypoints: waypoints,
                                    router: L.Routing.osrmv1({ serviceUrl: 'https://router.project-osrm.org/route/v1' }),
                                    routeWhileDragging: false,
                                    draggableWaypoints: false,
                                    addWaypoints: false,
                                    fitSelectedRoutes: true,
                                    show: false,

                                    collapsible: false,
                                    lineOptions: { styles: [{ color: '#22C55E', weight: 5, opacity: 0.9 }] },

                                    createMarker: function() { return null; }
                                });

                                routingControl.on('routesfound', function(e) {
                                    lastRoute = e.routes[0];
                                    var summary = lastRoute.summary;
                                    summaryEl.style.display = 'flex';
                                    summaryEl.innerHTML =
                                        '<span>\uD83D\uDE97 ' + metersToText(summary.totalDistance) + '</span>' +
                                        '<span>\u23F1\uFE0F ' + secondsToText(summary.totalTime) + '</span>' +
                                        '<button type="button" class="btn-directions-toggle">\uD83E\uDDED Directions</button>';
                                    var toggleBtn = summaryEl.querySelector('.btn-directions-toggle');
                                    toggleBtn.onclick = openNavModal;
                                    statusEl.textContent = '';


                                    if (navModalEl.classList.contains('open')) {
                                        renderNavModalContent();
                                    }
                                });

                                routingControl.on('routingerror', function() {
                                    statusEl.textContent = 'Could not calculate a road route right now - showing straight-line stops only.';
                                });

                                routingControl.addTo(map);
                            }

                            function onPositionUpdate(position, isFirstFix) {
                                var current = { lat: position.coords.latitude, lng: position.coords.longitude };

                                if (!userMarker) {
                                    userMarker = L.marker([current.lat, current.lng], { icon: youAreHereIcon, zIndexOffset: 1000 })
                                        .addTo(map)
                                        .bindPopup('<b>\uD83D\uDCCD You are here</b>');
                                } else {
                                    userMarker.setLatLng([current.lat, current.lng]);
                                }


                                if (isFirstFix || !lastRecalcLatLng || haversineMeters(lastRecalcLatLng, current) > 40) {
                                    lastRecalcLatLng = current;
                                    buildOrUpdateRoute(current);
                                }
                            }


                            window['backpackrStartLiveNav_' + tripId] = function() {
                                if (!navigator.geolocation) {
                                    if (statusEl) statusEl.textContent = 'Your browser does not support geolocation.';
                                    return;
                                }
                                if (!map) {
                                    if (statusEl) statusEl.textContent = 'None of this trip has no accurate location yet, so live navigation is not available.';
                                    return;
                                }
                                locateBtn.disabled = true;
                                locateBtn.textContent = '\uD83D\uDCCD Locating\u2026';
                                statusEl.textContent = '';

                                navigator.geolocation.getCurrentPosition(
                                    function(position) {
                                        locateBtn.textContent = '\uD83D\uDCCD Live Navigation Active';
                                        onPositionUpdate(position, true);


                                        if (watchId === null) {
                                            watchId = navigator.geolocation.watchPosition(
                                                function(pos) { onPositionUpdate(pos, false); },
                                                function(err) { statusEl.textContent = describeGeoError(err); },
                                                { enableHighAccuracy: true, maximumAge: 5000, timeout: 15000 }
                                            );
                                        }
                                    },
                                    function(err) {
                                        locateBtn.disabled = false;
                                        locateBtn.textContent = '\uD83D\uDCCD Use My Current Location';
                                        statusEl.textContent = describeGeoError(err);
                                    },
                                    { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
                                );
                            };

                            // ================================================================
                            // "Plan with AI" modal (distance / time / location search)
                            // ================================================================
                            var planMode = 'distance';
                            var planAnchor = null; // { lat, lng, source: 'live'|'stop', name }

                            function updatePlanAnchorNote() {
                                var noteEl = document.getElementById('plan-anchor-note-' + tripId);
                                if (!noteEl) return;
                                if (planMode === 'location') {
                                    noteEl.textContent = '';
                                } else if (planAnchor && planAnchor.source === 'live') {
                                    noteEl.textContent = '\uD83D\uDCCD Searching from your current location.';
                                } else if (planAnchor && planAnchor.source === 'stop') {
                                    noteEl.textContent = '\uD83D\uDCCD Current location is not available - searching from ' + planAnchor.name + ' instead.';
                                } else {
                                    noteEl.textContent = '\uD83D\uDCCD Allow location access, or add a stop to this trip first, to search by distance/time.';
                                }
                            }

                            function useFirstStopAsPlanAnchor() {
                                if (validStops.length > 0) {
                                    planAnchor = { lat: validStops[0].lat, lng: validStops[0].lng, source: 'stop', name: validStops[0].name };
                                } else {
                                    planAnchor = null;
                                }
                                updatePlanAnchorNote();
                            }

                            function resolvePlanAnchor() {
                                if (navigator.geolocation) {
                                    navigator.geolocation.getCurrentPosition(
                                        function(pos) {
                                            planAnchor = { lat: pos.coords.latitude, lng: pos.coords.longitude, source: 'live', name: 'your location' };
                                            updatePlanAnchorNote();
                                        },
                                        function() { useFirstStopAsPlanAnchor(); },
                                        { enableHighAccuracy: true, timeout: 8000, maximumAge: 60000 }
                                    );
                                } else {
                                    useFirstStopAsPlanAnchor();
                                }
                            }


                            window['openPlanModal_' + tripId] = function() {
                                document.getElementById('plan-modal-' + tripId).classList.add('open');
                                resolvePlanAnchor();
                            };

                            window['setPlanMode_' + tripId] = function(mode) {
                                planMode = mode;
                                var modalEl = document.getElementById('plan-modal-' + tripId);
                                modalEl.querySelectorAll('.plan-mode-tab').forEach(function(btn) {
                                    btn.classList.toggle('active', btn.getAttribute('data-mode') === mode);
                                });
                                modalEl.querySelectorAll('[data-mode-field]').forEach(function(field) {
                                    field.style.display = (field.getAttribute('data-mode-field') === mode) ? 'block' : 'none';
                                });
                                updatePlanAnchorNote();
                            };

                            function escapePlanText(s) {
                                var d = document.createElement('div');
                                d.textContent = s == null ? '' : s;
                                return d.innerHTML;
                            }

                            function renderPlanResults(places) {
                                var resultsEl = document.getElementById('plan-results-' + tripId);
                                if (!places || places.length === 0) {
                                    resultsEl.innerHTML = '<div class="plan-results-empty">No matching places found - try a wider range or different criteria.</div>';
                                    return;
                                }
                                resultsEl.innerHTML = '';
                                places.forEach(function(p) {
                                    var distanceText = (p.distanceKm >= 0)
                                        ? (p.distanceKm < 1 ? Math.round(p.distanceKm * 1000) + ' m away' : p.distanceKm.toFixed(1) + ' km away')
                                        : '';
                                    var metaParts = [p.category, (p.district + ', ' + p.state)];
                                    if (distanceText) metaParts.push(distanceText);

                                    var card = document.createElement('div');
                                    card.className = 'plan-result-card';
                                    card.innerHTML =
                                        '<div class="plan-result-info">' +
                                            '<strong>' + escapePlanText(p.placeName) + '</strong>' +
                                            '<span class="plan-result-meta">' + escapePlanText(metaParts.join(' \u2022 ')) + '</span>' +
                                        '</div>' +
                                        '<button type="button" class="btn btn-primary btn-sm">+ Add</button>';

                                    card.querySelector('button').onclick = function() {
                                        addPlanResultToTrip(p.placeId, card);
                                    };
                                    resultsEl.appendChild(card);
                                });
                            }

                            function addPlanResultToTrip(placeId, cardEl) {
                                var btn = cardEl.querySelector('button');
                                btn.disabled = true;
                                btn.textContent = 'Adding\u2026';

                                var params = new URLSearchParams();
                                params.set('action', 'addStopAjax');
                                params.set('placeId', placeId);
                                params.set('tripId', tripId);

                                fetch('trip', {
                                    method: 'POST',
                                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                                    body: params.toString()
                                })
                                    .then(function(r) { return r.json(); })
                                    .then(function(data) {
                                        if (data.success) {
                                            btn.textContent = '\u2713 Added';
                                            cardEl.classList.add('plan-result-added');

                                            setTimeout(function() { window.location.reload(); }, 600);
                                        } else {
                                            btn.disabled = false;
                                            btn.textContent = '+ Add';
                                        }
                                    })
                                    .catch(function() {
                                        btn.disabled = false;
                                        btn.textContent = '+ Add';
                                    });
                            }

                            window['runPlanSearch_' + tripId] = function() {
                                var resultsEl = document.getElementById('plan-results-' + tripId);
                                var url = 'planSearch?tripId=' + tripId + '&mode=' + planMode;

                                if (planMode === 'location') {
                                    var loc = document.getElementById('plan-location-' + tripId).value.trim();
                                    if (!loc) {
                                        resultsEl.innerHTML = '<div class="plan-results-empty">Please enter a location to search for.</div>';
                                        return;
                                    }
                                    url += '&location=' + encodeURIComponent(loc);
                                } else {
                                    if (!planAnchor) {
                                        resultsEl.innerHTML = '<div class="plan-results-empty">Could not determine a starting point - allow location access, or add a stop to this trip first.</div>';
                                        return;
                                    }
                                    url += '&lat=' + planAnchor.lat + '&lng=' + planAnchor.lng;
                                    if (planMode === 'distance') {
                                        url += '&radiusKm=' + document.getElementById('plan-radiusKm-' + tripId).value;
                                    } else {
                                        url += '&maxMinutes=' + document.getElementById('plan-maxMinutes-' + tripId).value;
                                    }
                                }

                                resultsEl.innerHTML = '<div class="plan-results-empty">Searching\u2026</div>';

                                fetch(url)
                                    .then(function(r) { return r.json(); })
                                    .then(function(data) {
                                        if (!data.success) {
                                            resultsEl.innerHTML = '<div class="plan-results-empty">' + escapePlanText(data.error || 'Search failed.') + '</div>';
                                            return;
                                        }
                                        renderPlanResults(data.places);
                                    })
                                    .catch(function() {
                                        resultsEl.innerHTML = '<div class="plan-results-empty">Search failed - please try again.</div>';
                                    });
                            };


                            if (!mapEl) return;
                            if (stops.length === 0) {

                                mapEl.innerHTML = '<div style="display:flex; align-items:center; justify-content:center; height:100%; color:#64748B; font-size:0.9rem; text-align:center; padding:20px;">\uD83D\uDDFA\uFE0F Add a stop to this trip to see it on the map here.</div>';
                                return;
                            }


                            function isPlausible(lat, lng) {
                                return (lat !== 0 || lng !== 0) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
                            }
                            validStops = stops.filter(function(s) { return isPlausible(s.lat, s.lng); });

                            if (validStops.length === 0) {

                                mapEl.innerHTML = '<div style="display:flex; align-items:center; justify-content:center; height:100%; color:#64748B; font-size:0.9rem; text-align:center; padding:20px;">\uD83D\uDCCD None of the stops in this trip have an accurate location yet.<br>Edit them with a Google Maps link to see them here.</div>';
                                return;
                            }

                            map = L.map(mapEl).setView([validStops[0].lat, validStops[0].lng], 9);
                            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                                attribution: '&copy; OpenStreetMap contributors',
                                maxZoom: 18
                            }).addTo(map);

                            var latlngs = [];
                            validStops.forEach(function(s) {
                                var marker = L.marker([s.lat, s.lng]).addTo(map);
                                marker.bindPopup('<b>' + s.order + '. ' + s.name + '</b>');
                                latlngs.push([s.lat, s.lng]);
                            });

                            if (latlngs.length > 1) {
                                baseStraightLineRoute = L.polyline(latlngs, { color: '#22C55E', weight: 4, opacity: 0.8 }).addTo(map);
                                map.fitBounds(baseStraightLineRoute.getBounds(), { padding: [30, 30] });
                            }
                        })();
                        </script>
                </article>
            <%
                    }
                }
            %>
        </section>

    </main>

</div>

</body>
</html>
