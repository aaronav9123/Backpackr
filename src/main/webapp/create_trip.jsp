<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="com.backpackr.model.User" %>
<%@ page import="com.backpackr.util.HtmlUtils" %>

<%
    // Session validation
    User currentUser = (User) session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    String activePage = "trips";
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backpackr - Plan Trip</title>
    <link rel="stylesheet" href="css/style.css?v=3">
    <script>
        function selectLocation(loc) {
            document.getElementById('startLocation').value = loc;
            searchPossiblePlaces();
        }

        // NEW FEATURE (per user request): live "places you could visit"
        // preview, driven by Destination + Duration as the person fills
        // the form in - well before the trip is actually created. Reuses
        // the same /planSearch endpoint "Plan with AI" already uses on
        // trips.jsp, in "location" mode, with no tripId (this trip
        // doesn't exist yet, so there's nothing to exclude).
        var searchDebounceTimer = null;
        function debouncedSearch() {
            clearTimeout(searchDebounceTimer);
            searchDebounceTimer = setTimeout(searchPossiblePlaces, 400);
        }

        // NEW FEATURE (per user request): let the person pre-select places
        // from the "Places You Could Visit" preview so they're added to
        // the trip automatically the moment it's created, instead of
        // having to search for them again afterward. Selection is tracked
        // client-side by placeId and survives re-searching (e.g. tweaking
        // Duration re-sizes the recommended count, but doesn't lose picks
        // already made) - only cleared if the person deselects a place
        // themselves.
        var selectedPlaceIds = new Set();
        var selectedPlaceNames = {};

        function updateSelectedSummary() {
            var summaryEl = document.getElementById('selected-places-summary');
            var submitBtn = document.getElementById('createTripSubmitBtn');
            var count = selectedPlaceIds.size;
            if (count === 0) {
                summaryEl.textContent = '';
                submitBtn.textContent = '\u2728 Create & Initialize Trip';
            } else {
                var names = [];
                selectedPlaceIds.forEach(function(id) { names.push(selectedPlaceNames[id]); });
                summaryEl.textContent = count + ' place' + (count === 1 ? '' : 's') + ' selected: ' + names.join(', ');
                submitBtn.textContent = '\u2728 Create Trip with ' + count + ' Place' + (count === 1 ? '' : 's');
            }
        }

        function togglePlaceSelection(placeId, placeName, btnEl, cardEl) {
            if (selectedPlaceIds.has(placeId)) {
                selectedPlaceIds.delete(placeId);
                delete selectedPlaceNames[placeId];
                btnEl.textContent = '+ Add';
                cardEl.classList.remove('plan-result-added');
            } else {
                selectedPlaceIds.add(placeId);
                selectedPlaceNames[placeId] = placeName;
                btnEl.textContent = '\u2713 Added';
                cardEl.classList.add('plan-result-added');
            }
            updateSelectedSummary();
        }

        // Before the create-trip form submits, add one hidden "placeIds"
        // input per selected place so TripServlet can read them all via
        // request.getParameterValues("placeIds") and add them as the
        // trip's first stops right after creating it.
        function attachSelectedPlaceIds(formEl) {
            formEl.querySelectorAll('input[name="placeIds"]').forEach(function(el) { el.remove(); });
            selectedPlaceIds.forEach(function(id) {
                var input = document.createElement('input');
                input.type = 'hidden';
                input.name = 'placeIds';
                input.value = id;
                formEl.appendChild(input);
            });
            return true;
        }

        function escapeCreateTripText(s) {
            var d = document.createElement('div');
            d.textContent = s == null ? '' : s;
            return d.innerHTML;
        }

        function searchPossiblePlaces() {
            var resultsEl = document.getElementById('possible-places-results');
            var location = document.getElementById('startLocation').value.trim();
            var days = parseInt(document.getElementById('totalDays').value, 10);
            if (!days || days < 1) days = 1;

            if (!location) {
                resultsEl.innerHTML = '<div class="plan-results-empty">Enter a destination above to see places you could visit.</div>';
                return;
            }

            resultsEl.innerHTML = '<div class="plan-results-empty">Searching\u2026</div>';

            fetch('planSearch?mode=location&location=' + encodeURIComponent(location))
                .then(function(r) { return r.json(); })
                .then(function(data) {
                    if (!data.success) {
                        resultsEl.innerHTML = '<div class="plan-results-empty">' + escapeCreateTripText(data.error || 'Search failed.') + '</div>';
                        return;
                    }
                    renderPossiblePlaces(data.places, location, days);
                })
                .catch(function() {
                    resultsEl.innerHTML = '<div class="plan-results-empty">Search failed - please try again.</div>';
                });
        }

        function renderPossiblePlaces(places, location, days) {
            var resultsEl = document.getElementById('possible-places-results');
            var noteEl = document.getElementById('possible-places-note');

            if (!places || places.length === 0) {
                noteEl.textContent = '';
                resultsEl.innerHTML = '<div class="plan-results-empty">No places found near "' + escapeCreateTripText(location) + '" yet - you can still create the trip and add places afterward.</div>';
                return;
            }

            // Rough, honest pacing guide - about 2 places per day is a
            // comfortable amount for a backpacking trip; not a real
            // travel-time calculation (there's no trip/anchor point to
            // measure from yet at creation time), just a sizing hint.
            var recommended = Math.max(4, Math.min(12, days * 2));
            var shown = places.slice(0, recommended);

            noteEl.textContent = 'Showing ' + shown.length + ' of ' + places.length + ' places found near "' + location + '" - a comfortable amount for a ' + days + '-day trip.';

            resultsEl.innerHTML = '';
            shown.forEach(function(p) {
                var costText = p.avgCost > 0 ? ('Rs. ' + Math.round(p.avgCost)) : '';
                var metaParts = [p.category, (p.district + ', ' + p.state)];
                if (costText) metaParts.push(costText);

                var card = document.createElement('div');
                card.className = 'plan-result-card';
                var isSelected = selectedPlaceIds.has(p.placeId);
                if (isSelected) card.classList.add('plan-result-added');
                card.innerHTML =
                    '<div class="plan-result-info">' +
                        '<strong>' + escapeCreateTripText(p.placeName) + '</strong>' +
                        '<span class="plan-result-meta">' + escapeCreateTripText(metaParts.join(' \u2022 ')) + '</span>' +
                    '</div>' +
                    '<button type="button" class="btn btn-primary btn-sm">' + (isSelected ? '\u2713 Added' : '+ Add') + '</button>';

                card.querySelector('button').onclick = function() {
                    togglePlaceSelection(p.placeId, p.placeName, card.querySelector('button'), card);
                };
                resultsEl.appendChild(card);
            });
        }
    </script>
</head>
<body>

<div class="app-container">

    <%@ include file="_sidebar.jsp" %>

    <!-- Main Content Workspace -->
    <main class="main-content">

        <!-- REDESIGN: gradient hero banner replaces the plain text header,
             same visual language as add_place.jsp/saved_places.jsp. -->
        <div class="page-hero">
            <h1>➕ Create New Trip</h1>
            <p>Set your destination, budget, and days - Backpackr (and the AI planner) takes it from there.</p>
        </div>

        <!-- Feedback Alert banners -->
        <% if (request.getParameter("error") != null) { %>
            <div class="alert alert-error">
                ❌ <%= HtmlUtils.esc(request.getParameter("error")) %>
            </div>
        <% } %>

        <!-- Creation Form Card -->
        <div class="form-card">
            <form action="trip" method="post" id="createTripForm" onsubmit="return attachSelectedPlaceIds(this);">
                <input type="hidden" name="action" value="create">

                <div class="form-group">
                    <label class="form-label" for="tripName">Trip Title <span style="font-weight:400; color:var(--text-muted);">(optional)</span></label>
                    <input type="text" id="tripName" name="tripName" class="form-control" 
                           placeholder="e.g. My Sunny Summer Getaway">
                </div>

                <div class="form-group">
                    <label class="form-label" for="startLocation">Destination Location</label>
                    <input type="text" id="startLocation" name="startLocation" class="form-control" 
                           placeholder="Enter City, Region or State" oninput="debouncedSearch()">
                    
                    <div class="presets-container">
                        <span class="preset-badge" onclick="selectLocation('Goa')">🌴 Goa</span>
                        <span class="preset-badge" onclick="selectLocation('Mumbai')">🏙️ Mumbai</span>
                        <span class="preset-badge" onclick="selectLocation('Kerala')">🚣 Kerala</span>
                    </div>
                </div>

                <div class="form-group" style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">
                    <div>
                        <label class="form-label" for="totalBudget">Total Budget (Rs) <span style="font-weight:400; color:var(--text-muted);">(optional)</span></label>
                        <input type="number" id="totalBudget" name="totalBudget" class="form-control" 
                               min="0" max="1000000" placeholder="e.g. 5000 (defaults to 0)">
                    </div>
                    <div>
                        <label class="form-label" for="totalDays">Duration (Days)</label>
                        <input type="number" id="totalDays" name="totalDays" class="form-control" 
                               min="1" max="90" placeholder="e.g. 3 (defaults to 1)" value="3" oninput="debouncedSearch()">
                    </div>
                </div>

                <%-- NEW FEATURE (per user request): reflects places
                     selected from the "Places You Could Visit" preview
                     below - see togglePlaceSelection()/updateSelectedSummary()
                     in the script above. --%>
                <div class="plan-anchor-note" id="selected-places-summary"></div>

                <button type="submit" class="btn btn-primary btn-block" style="margin-top: 10px;" id="createTripSubmitBtn">
                    ✨ Create & Initialize Trip
                </button>
            </form>
        </div>

        <%--
            NEW FEATURE (per user request): live preview of places the
            person could visit, updating as Destination/Duration change -
            well before the trip is actually created. Title never factors
            into this (it has no geographic meaning), matching "title
            should not matter".
        --%>
        <div class="form-card" style="margin-top: 24px;">
            <div class="profile-details-header">
                <h3>🗺️ Places You Could Visit</h3>
            </div>
            <div class="plan-anchor-note" id="possible-places-note"></div>
            <div class="plan-modal-results" style="padding:0; max-height:none;" id="possible-places-results">
                <div class="plan-results-empty">Enter a destination above to see places you could visit.</div>
            </div>
        </div>

    </main>

</div>

</body>
</html>