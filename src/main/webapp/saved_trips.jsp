<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="com.backpackr.model.User" %>
<%@ page import="com.backpackr.model.Trip" %>
<%@ page import="com.backpackr.model.TripStop" %>
<%@ page import="com.backpackr.dao.TripDAO" %>
<%@ page import="com.backpackr.dao.TripStopDAO" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.LinkedHashSet" %>
<%@ page import="java.util.Comparator" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%@ page import="com.backpackr.util.HtmlUtils" %>

<%
    // Session validation
    User currentUser = (User) session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    String activePage = "savedtrips"; // no matching sidebar item, so nothing is force-highlighted

    TripDAO tripDAO = new TripDAO();
    TripStopDAO tripStopDAO = new TripStopDAO();

    // ---- Load every trip belonging to this user, plus its stops, once ----
    List<Trip> allTrips = tripDAO.getTripsByUser(currentUser.getUserId());

    // ---- Read toolbar params ----
    String q = request.getParameter("q");
    String destinationFilter = request.getParameter("destination");
    String sort = request.getParameter("sort");
    if (sort == null || sort.trim().isEmpty()) sort = "latest";
    if (destinationFilter == null) destinationFilter = "All";

    // ---- Distinct destinations across the user's own trips (dynamic, not hardcoded) ----
    LinkedHashSet<String> destinationSet = new LinkedHashSet<>();
    for (Trip t : allTrips) {
        if (t.getStartLocation() != null && !t.getStartLocation().trim().isEmpty()) {
            destinationSet.add(t.getStartLocation());
        }
    }

    // ---- Filter ----
    List<Trip> filtered = new ArrayList<>();
    for (Trip t : allTrips) {
        boolean matchesQuery = (q == null || q.trim().isEmpty())
                || (t.getTripName() != null && t.getTripName().toLowerCase().contains(q.trim().toLowerCase()))
                || (t.getStartLocation() != null && t.getStartLocation().toLowerCase().contains(q.trim().toLowerCase()));
        boolean matchesDestination = "All".equalsIgnoreCase(destinationFilter)
                || (t.getStartLocation() != null && t.getStartLocation().equalsIgnoreCase(destinationFilter));
        if (matchesQuery && matchesDestination) {
            filtered.add(t);
        }
    }

    // ---- Sort ----
    switch (sort) {
        case "oldest":
            filtered.sort(Comparator.comparingInt(Trip::getTripId));
            break;
        case "name":
            filtered.sort(Comparator.comparing(t -> t.getTripName() == null ? "" : t.getTripName().toLowerCase()));
            break;
        case "budget_high":
            filtered.sort((a, b) -> Double.compare(b.getTotalBudget(), a.getTotalBudget()));
            break;
        case "budget_low":
            filtered.sort(Comparator.comparingDouble(Trip::getTotalBudget));
            break;
        case "latest":
        default:
            filtered.sort((a, b) -> Integer.compare(b.getTripId(), a.getTripId()));
            break;
    }

    SimpleDateFormat displayDateFormat = new SimpleDateFormat("MMM dd, yyyy");
    String fallbackCover = "https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=800&q=80";
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backpackr - Saved Trips</title>
    <link rel="stylesheet" href="css/style.css?v=3">
    <link rel="stylesheet" href="css/saved_trips.css?v=3">
</head>
<body class="st-theme">

<div class="app-container">

    <%@ include file="_sidebar.jsp" %>

    <main class="main-content">

        <header class="page-header">
            <div class="page-title">
                <h1>Saved Trips 🔖</h1>
                <p>All your saved travel plans in one place.</p>
            </div>
            <a href="create_trip.jsp" class="btn btn-primary">➕ Create New Trip</a>
        </header>

        <% if (request.getParameter("success") != null) { %>
            <div class="alert alert-success">✅ <%= HtmlUtils.esc(request.getParameter("success")) %></div>
        <% } %>
        <% if (request.getParameter("error") != null) { %>
            <div class="alert alert-error">❌ <%= HtmlUtils.esc(request.getParameter("error")) %></div>
        <% } %>

        <!-- Toolbar: search / destination filter / sort / view toggle -->
        <form class="st-toolbar" method="get" action="saved_trips.jsp" id="toolbarForm">
            <div class="st-search-box">
                <span class="st-search-icon">🔍</span>
                <input type="text" class="st-input" name="q" placeholder="Search saved trips..."
                       value="<%= (q != null) ? HtmlUtils.esc(q) : "" %>" onkeyup="if(event.key==='Enter'){document.getElementById('toolbarForm').submit();}">
            </div>

            <select class="st-select" name="destination" onchange="document.getElementById('toolbarForm').submit()">
                <option value="All" <%= "All".equalsIgnoreCase(destinationFilter) ? "selected" : "" %>>All Destinations</option>
                <% for (String dest : destinationSet) { %>
                    <option value="<%= HtmlUtils.esc(dest) %>" <%= dest.equalsIgnoreCase(destinationFilter) ? "selected" : "" %>><%= HtmlUtils.esc(dest) %></option>
                <% } %>
            </select>

            <select class="st-select" name="sort" onchange="document.getElementById('toolbarForm').submit()">
                <option value="latest" <%= "latest".equals(sort) ? "selected" : "" %>>Sort: Latest</option>
                <option value="oldest" <%= "oldest".equals(sort) ? "selected" : "" %>>Sort: Oldest</option>
                <option value="name" <%= "name".equals(sort) ? "selected" : "" %>>Sort: Name (A-Z)</option>
                <option value="budget_high" <%= "budget_high".equals(sort) ? "selected" : "" %>>Sort: Budget (High-Low)</option>
                <option value="budget_low" <%= "budget_low".equals(sort) ? "selected" : "" %>>Sort: Budget (Low-High)</option>
            </select>

            <div class="st-view-toggle">
                <button type="button" id="gridBtn" onclick="setView('grid')" title="Grid view">▦</button>
                <button type="button" id="listBtn" class="active" onclick="setView('list')" title="List view">☰</button>
            </div>
        </form>

        <% if (filtered.isEmpty()) { %>
            <div class="empty-state">
                <h3><%= allTrips.isEmpty() ? "No saved trips yet" : "No trips match your search" %></h3>
                <p><%= allTrips.isEmpty()
                        ? "Create a trip and it will show up here so you can revisit your plans any time."
                        : "Try a different search term, destination, or clear your filters." %></p>
                <a href="create_trip.jsp" class="btn btn-primary">Create Your First Trip</a>
            </div>
        <% } else { %>
            <section class="st-trip-list" id="tripList">
                <%
                    for (Trip t : filtered) {
                        List<TripStop> stops = tripStopDAO.getStopsForTrip(t.getTripId());
                        String cover = fallbackCover;
                        for (TripStop s : stops) {
                            if (s.getImageUrl() != null && !s.getImageUrl().trim().isEmpty()) {
                                cover = s.getImageUrl();
                                break;
                            }
                        }
                        String createdStr = (t.getCreatedDate() != null) ? displayDateFormat.format(t.getCreatedDate()) : "";
                %>
                    <article class="st-trip-card">
                        <div class="st-trip-thumb" style="background-image: url('<%= HtmlUtils.esc(cover) %>');"></div>

                        <div class="st-trip-info">
                            <div class="st-trip-name-row">
                                <h2><%= HtmlUtils.esc(t.getTripName()) %></h2>
                                <% if (t.getStartLocation() != null && !t.getStartLocation().trim().isEmpty()) { %>
                                    <span class="st-badge"><%= HtmlUtils.esc(t.getStartLocation()) %></span>
                                <% } %>
                            </div>
                            <div class="st-trip-meta">
                                <span>⏱️ <strong><%= t.getTotalDays() %> Day<%= t.getTotalDays() == 1 ? "" : "s" %></strong></span>
                                <span>💰 <strong>Rs. <%= (int) t.getTotalBudget() %></strong></span>
                                <span>📍 <strong><%= stops.size() %> Stop<%= stops.size() == 1 ? "" : "s" %></strong></span>
                            </div>
                            <div class="st-trip-created">Created on <%= createdStr %></div>
                        </div>

                        <div class="st-trip-actions">
                            <a href="saved_trip_details.jsp?tripId=<%= t.getTripId() %>" class="btn btn-primary btn-sm">View Trip</a>
                            <a href="saved_trip_details.jsp?tripId=<%= t.getTripId() %>&edit=1" class="btn btn-secondary btn-sm">✏️ Edit</a>
                            <form action="trip" method="post" onsubmit="return confirm('Delete this saved trip? This cannot be undone.');">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="tripId" value="<%= t.getTripId() %>">
                                <input type="hidden" name="redirect" value="saved_trips.jsp">
                                <button type="submit" class="btn btn-danger btn-sm" style="width:100%;">🗑️ Delete</button>
                            </form>
                        </div>
                    </article>
                <% } %>
            </section>
        <% } %>

    </main>

</div>

<script>
    function setView(mode) {
        const list = document.getElementById('tripList');
        const gridBtn = document.getElementById('gridBtn');
        const listBtn = document.getElementById('listBtn');
        if (!list) return;
        if (mode === 'grid') {
            list.classList.add('st-grid');
            gridBtn.classList.add('active');
            listBtn.classList.remove('active');
        } else {
            list.classList.remove('st-grid');
            listBtn.classList.add('active');
            gridBtn.classList.remove('active');
        }
    }
</script>

</body>
</html>
