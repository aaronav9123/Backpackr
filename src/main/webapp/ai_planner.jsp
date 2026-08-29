<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="com.backpackr.model.User" %>
<%@ page import="com.backpackr.model.Trip" %>
<%@ page import="com.backpackr.dao.TripDAO" %>
<%@ page import="com.backpackr.util.HtmlUtils" %>

<%
    User currentUser = (User) session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    String activePage = "trips";

    int tripId;
    try {
        tripId = Integer.parseInt(request.getParameter("tripId"));
    } catch (Exception e) {
        response.sendRedirect("trips.jsp?error=Missing+trip");
        return;
    }

    TripDAO tripDAO = new TripDAO();
    Trip trip = tripDAO.getTripById(tripId);
    if (trip == null || trip.getUserId() != currentUser.getUserId()) {
        response.sendRedirect("trips.jsp?error=Trip+not+found");
        return;
    }
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backpackr - AI Trip Planner</title>
    <link rel="stylesheet" href="css/style.css?v=3">
</head>
<body>

<div class="app-container">

    <%@ include file="_sidebar.jsp" %>

    <main class="main-content">
        <header class="page-header">
            <div class="page-title">
                <h1>🤖 AI Trip Planner</h1>
                <p>Planning: <strong><%= HtmlUtils.esc(trip.getTripName()) %></strong> &bull; <%= HtmlUtils.esc(trip.getStartLocation()) %> &bull; <%= trip.getTotalDays() %> days &bull; Rs. <%= (int) trip.getTotalBudget() %></p>
            </div>
        </header>

        <% if (request.getParameter("error") != null) { %>
            <div class="alert alert-error">❌ <%= HtmlUtils.esc(request.getParameter("error")) %></div>
        <% } %>

        <div class="form-card pref-form" style="max-width: 640px;">
            <p style="color:var(--text-muted); margin-bottom:24px; font-size:0.9rem;">
                Gemini will build a day-wise itinerary using places already in Backpackr's
                community database — including any you've already added with "+" — and will
                fit everything within your trip's budget and day count where possible.
            </p>

            <form action="aiPlan" method="post">
                <input type="hidden" name="tripId" value="<%= tripId %>">

                <div class="form-group">
                    <label class="form-label pref-label">🚗 Travel Mode</label>
                    <select name="travelMode" class="form-control">
                        <option>Car</option>
                        <option>Bike</option>
                        <option>Public Transport</option>
                        <option>Walking</option>
                    </select>
                </div>

                <div class="form-group">
                    <label class="form-label pref-label">👥 Who's Traveling</label>
                    <select name="groupType" class="form-control">
                        <option>Solo</option>
                        <option>Couple</option>
                        <option>Family</option>
                        <option>Friends</option>
                    </select>
                </div>

                <div class="form-group">
                    <label class="form-label pref-label">❤️ Interests</label>
                    <input type="text" name="interests" class="form-control"
                           placeholder="e.g. Nature, Food, Adventure, History" value="Nature, Food">
                </div>

                <div class="form-group">
                    <label class="form-label pref-label">⚡ Adventure Level</label>
                    <select name="adventureLevel" class="form-control">
                        <option>Relaxed</option>
                        <option selected>Moderate</option>
                        <option>High</option>
                    </select>
                </div>

                <button type="submit" class="btn btn-primary btn-block" style="margin-top: 10px;">
                    ✨ Generate My Itinerary
                </button>
            </form>
        </div>
    </main>

</div>

</body>
</html>
