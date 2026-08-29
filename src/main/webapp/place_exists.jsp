<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="com.backpackr.model.User" %>
<%@ page import="com.backpackr.model.Place" %>
<%@ page import="com.backpackr.model.Trip" %>
<%@ page import="com.backpackr.dao.PlaceDAO" %>
<%@ page import="com.backpackr.dao.TripDAO" %>
<%@ page import="com.backpackr.dao.SavedPlaceDAO" %>
<%@ page import="java.util.List" %>
<%@ page import="com.backpackr.util.HtmlUtils" %>

<%
    // NEW FEATURE (Multi-user duplicate-place prevention): AddPlaceServlet
    // redirects here instead of saving a new PLACES row whenever the
    // coordinates just submitted land within the configured radius of a
    // place that's already on the map (see PlaceDAO.findNearbyDuplicate()).
    // The submitted data itself stays server-side, in the session
    // (AddPlaceServlet's PENDING_PLACE_SESSION_KEY) - this page only needs
    // the id of the existing match to show it and to let the two buttons
    // below tell AddPlaceServlet what to do with that pending submission.
    User currentUser = (User) session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    String activePage = "addplace";

    Place pendingSubmission = (Place) session.getAttribute("pendingPlaceContribution");
    Integer pendingExistingId = (Integer) session.getAttribute("pendingExistingPlaceId");

    String existingIdParam = request.getParameter("existingId");
    if (existingIdParam == null || existingIdParam.trim().isEmpty()) {
        response.sendRedirect("add_place.jsp");
        return;
    }

    int existingId;
    try {
        existingId = Integer.parseInt(existingIdParam.trim());
    } catch (NumberFormatException e) {
        response.sendRedirect("add_place.jsp");
        return;
    }

    PlaceDAO placeDAO = new PlaceDAO();
    Place existingPlace = placeDAO.getPlaceById(existingId);
    if (existingPlace == null) {
        // Nothing left to show (e.g. the place was removed in the meantime) -
        // send the user back to try adding it fresh.
        response.sendRedirect("add_place.jsp?error=" + java.net.URLEncoder.encode(
                "That place could no longer be found - please try again", "UTF-8"));
        return;
    }

    // Whether the pending submission in session actually still matches what
    // this page is showing - if the session expired, or a different tab
    // triggered a different match, hide the "contribute" button rather than
    // let it post something stale.
    boolean canContribute = pendingSubmission != null
            && pendingExistingId != null
            && pendingExistingId.intValue() == existingId;

    TripDAO tripDAO = new TripDAO();
    List<Trip> myTrips = tripDAO.getTripsByUser(currentUser.getUserId());
    SavedPlaceDAO savedPlaceDAO = new SavedPlaceDAO();
    List<Integer> savedIds = savedPlaceDAO.getSavedPlaceIds(currentUser.getUserId());
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backpackr - This Place Already Exists</title>
    <link rel="stylesheet" href="css/style.css?v=3">
</head>
<body>

<div class="app-container">

    <%@ include file="_sidebar.jsp" %>

    <main class="main-content">
        <header class="page-header">
            <div class="page-title">
                <h1>📍 Looks Like This Place Is Already On The Map</h1>
                <p>
                    <% if (pendingSubmission != null && pendingSubmission.getPlaceName() != null) { %>
                        You entered <strong><%= HtmlUtils.esc(pendingSubmission.getPlaceName()) %></strong>, but we
                        found an existing place at essentially the same location.
                    <% } else { %>
                        We found an existing place at essentially the same location you submitted.
                    <% } %>
                    Adding it again would create a duplicate, so nothing has been saved yet.
                </p>
            </div>
        </header>

        <div class="add-place-wrapper">
            <div class="add-place-card">
                <div class="add-place-banner">
                    <h2>🗺️ Existing Place</h2>
                    <p>Here's what the community already has for this spot.</p>
                </div>

                <div class="add-place-form">
                    <div class="homepage-grid" style="grid-template-columns: minmax(260px, 420px); justify-content: center;">
                        <%
                            request.setAttribute("cardPlace", existingPlace);
                            request.setAttribute("cardSavedIds", savedIds);
                            request.setAttribute("cardMyTrips", myTrips);
                        %>
                        <jsp:include page="_place_card.jsp" flush="true" />
                    </div>

                    <div class="publish-area" style="flex-direction: column; gap: 12px; align-items: center;">
                        <a href="home.jsp?placeId=<%= existingPlace.getPlaceId() %>" class="btn btn-secondary publish-btn">
                            👀 View This Place
                        </a>

                        <% if (canContribute) { %>
                            <form action="addPlace" method="post" style="width: 100%; display: contents;">
                                <input type="hidden" name="confirmAction" value="contribute">
                                <input type="hidden" name="existingPlaceId" value="<%= existingId %>">
                                <button type="submit" class="btn btn-primary publish-btn">
                                    🤝 Add My Info To This Place
                                </button>
                            </form>
                            <form action="addPlace" method="post" style="width: 100%; display: contents;">
                                <input type="hidden" name="confirmAction" value="cancel">
                                <button type="submit" class="btn btn-secondary publish-btn" style="background:transparent;">
                                    ✖️ Never Mind, Discard What I Typed
                                </button>
                            </form>
                        <% } else { %>
                            <p class="muted-note">
                                Your original details couldn't be recovered (maybe your session expired) -
                                <a href="add_place.jsp">go back and try adding your info again</a>.
                            </p>
                        <% } %>
                    </div>
                </div>
            </div>
        </div>
    </main>

</div>

<div id="toast" class="toast"></div>
<script src="js/script.js"></script>
</body>
</html>
