<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="com.backpackr.model.User" %>
<%@ page import="com.backpackr.model.Place" %>
<%@ page import="com.backpackr.model.Trip" %>
<%@ page import="com.backpackr.dao.SavedPlaceDAO" %>
<%@ page import="com.backpackr.dao.TripDAO" %>
<%@ page import="java.util.List" %>
<%@ page import="com.backpackr.util.HtmlUtils" %>

<%
    User currentUser = (User) session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    String activePage = "saved";

    SavedPlaceDAO savedPlaceDAO = new SavedPlaceDAO();
    List<Place> savedPlaces = savedPlaceDAO.getSavedPlaces(currentUser.getUserId());
    // REDESIGN: cards below now reuse the shared _place_card.jsp component
    // (same one the homepage/profile use) instead of a second, separately
    // maintained copy of the card markup - which also means this page
    // picks up features that copy never had, like the "View on Google
    // Maps" link and live star ratings.
    List<Integer> savedIds = savedPlaceDAO.getSavedPlaceIds(currentUser.getUserId());

    TripDAO tripDAO = new TripDAO();
    List<Trip> myTrips = tripDAO.getTripsByUser(currentUser.getUserId());
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backpackr - Saved Places</title>
    <link rel="stylesheet" href="css/style.css?v=3">
</head>
<body>

<div class="app-container">

    <%@ include file="_sidebar.jsp" %>

    <main class="main-content">
        <!-- REDESIGN: hero banner, same gradient-card language used on
             add_place.jsp/profile.jsp, instead of a plain text header. -->
        <div class="page-hero">
            <h1>🔖 Saved Places</h1>
            <p>Every place you've bookmarked while browsing, ready whenever you plan your next trip.</p>
            <% if (!savedPlaces.isEmpty()) { %>
                <span class="page-hero-count"><%= savedPlaces.size() %> place<%= savedPlaces.size() == 1 ? "" : "s" %> saved</span>
            <% } %>
        </div>

        <section class="grid-container">
            <% if (savedPlaces.isEmpty()) { %>
                <div class="empty-state" style="grid-column: 1 / -1;">
                    <h3>Nothing saved yet</h3>
                    <p>Tap the bookmark icon on any place card while searching to save it here.</p>
                    <a href="home.jsp" class="btn btn-primary">🔍 Discover Places</a>
                </div>
            <% } else {
                for (Place p : savedPlaces) {
                    request.setAttribute("cardPlace", p);
                    request.setAttribute("cardSavedIds", savedIds);
                    request.setAttribute("cardMyTrips", myTrips);
            %>
                <jsp:include page="_place_card.jsp" flush="true" />
            <% } } %>
        </section>
    </main>

</div>

<div id="toast" class="toast"></div>
<script src="js/script.js"></script>
</body>
</html>
