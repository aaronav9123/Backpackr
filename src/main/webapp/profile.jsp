<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="com.backpackr.model.User" %>
<%@ page import="com.backpackr.model.Place" %>
<%@ page import="com.backpackr.model.Trip" %>
<%@ page import="com.backpackr.dao.PlaceDAO" %>
<%@ page import="com.backpackr.dao.TripDAO" %>
<%@ page import="com.backpackr.dao.SavedPlaceDAO" %>
<%@ page import="com.backpackr.util.HtmlUtils" %>
<%@ page import="java.util.List" %>

<%
    User currentUser = (User) session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    String activePage = "profile";

    PlaceDAO placeDAO = new PlaceDAO();
    List<Place> contributedPlaces = placeDAO.getPlacesByUser(currentUser.getUserId());
    int placesContributed = contributedPlaces.size();

    TripDAO tripDAO = new TripDAO();
    List<Trip> myTrips = tripDAO.getTripsByUser(currentUser.getUserId());
    int tripCount = myTrips.size();

    SavedPlaceDAO savedPlaceDAO = new SavedPlaceDAO();
    List<Integer> savedIds = savedPlaceDAO.getSavedPlaceIds(currentUser.getUserId());
    int savedCount = savedIds.size();

    String successMsg = request.getParameter("success");
    String errorMsg = request.getParameter("error");
    // BUG FIX (profile layout looked broken/overlapping): this used to
    // pop the "edit details" form open for ANY error on the page,
    // including a failed PHOTO upload - which has nothing to do with the
    // name/email/mobile form, and made the page look like two sections
    // were overlapping. It now only reopens edit mode when the error
    // actually came from the details form (see ProfileServlet's new
    // "section" parameter).
    boolean reopenDetailsEdit = errorMsg != null && "details".equals(request.getParameter("section"));

    String avatarUrl = (currentUser.getProfileImage() != null && !currentUser.getProfileImage().isBlank())
            ? currentUser.getProfileImage() : null;
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backpackr - Profile</title>
    <%-- BUG FIX (CSS not visibly updating after redeploy): a version
         query string busts the browser's cached copy of style.css so a
         redeploy is guaranteed to be reflected immediately instead of an
         old cached stylesheet silently sticking around. Bump CSS_VERSION
         below whenever style.css changes meaningfully. --%>
    <link rel="stylesheet" href="css/style.css?v=3">
</head>
<body>

<div class="app-container">

    <%@ include file="_sidebar.jsp" %>

    <main class="main-content">
        <header class="page-header">
            <div class="page-title">
                <h1>My Profile 👤</h1>
                <p>Your Backpackr explorer identity.</p>
            </div>
        </header>

        <% if (successMsg != null) { %>
            <div class="alert alert-success">✅ <%= HtmlUtils.esc(successMsg) %></div>
        <% } %>
        <% if (errorMsg != null) { %>
            <div class="alert alert-error">❌ <%= HtmlUtils.esc(errorMsg) %></div>
        <% } %>

        <!-- REDESIGN: hero banner (same gradient-card language as
             add_place.jsp's "Share a New Place" banner) showing the
             avatar, name, and quick stats up top. -->
        <div class="profile-hero">
            <div class="profile-hero-avatar-wrap">
                <% if (avatarUrl != null) { %>
                    <img src="<%= HtmlUtils.esc(avatarUrl) %>" alt="Profile photo" class="profile-hero-avatar-img">
                <% } else { %>
                    <div class="profile-hero-avatar-fallback">
                        <%= (currentUser.getName() != null && !currentUser.getName().isEmpty()) ? HtmlUtils.esc(currentUser.getName().substring(0, 1).toUpperCase()) : "?" %>
                    </div>
                <% } %>
                <!-- NEW FEATURE (Profile enhancements): photo change is its
                     own always-available action (a small camera badge on
                     the avatar), independent of the Name/Email/Mobile
                     "Edit" toggle below - matches how most apps separate
                     "change picture" from "edit details". -->
                <form action="profile" method="post" enctype="multipart/form-data" id="photoForm">
                    <input type="hidden" name="action" value="uploadPhoto">
                    <input type="file" name="photo" id="photoInput" accept="image/*" style="display:none;" onchange="document.getElementById('photoForm').submit();">
                    <button type="button" class="profile-hero-camera-btn" onclick="document.getElementById('photoInput').click();" title="Change photo">📷</button>
                </form>
            </div>
            <div class="profile-hero-info">
                <h2><%= HtmlUtils.esc(currentUser.getName()) %></h2>
                <p><%= HtmlUtils.esc(currentUser.getEmail()) %></p>
                <div class="profile-hero-stats">
                    <span>🗺️ <strong><%= placesContributed %></strong> places contributed</span>
                    <span>✈️ <strong><%= tripCount %></strong> trips planned</span>
                    <span>🔖 <strong><%= savedCount %></strong> places saved</span>
                </div>
            </div>
        </div>

        <!-- REDESIGN + functional change (per user request): profile
             details are shown READ-ONLY by default with a small "Edit"
             button, instead of always sitting in editable input boxes.
             Clicking "Edit" swaps to the form below it; "Cancel" swaps
             back without submitting anything. Pure CSS/JS toggle - no
             page reload, and works with JavaScript off too (the edit
             form is still reachable, it just starts open instead of
             hidden, since the toggle script never runs). -->
        <div class="form-card" style="max-width: 560px;">

            <div class="profile-details-header">
                <h3>Profile Details</h3>
                <button type="button" class="btn btn-secondary btn-sm" id="editToggleBtn" onclick="toggleProfileEdit(true)">✏️ Edit</button>
            </div>

            <div id="profileViewMode">
                <div class="profile-detail-row">
                    <span class="profile-detail-label">Name</span>
                    <span class="profile-detail-value"><%= HtmlUtils.esc(currentUser.getName()) %></span>
                </div>
                <div class="profile-detail-row">
                    <span class="profile-detail-label">Email</span>
                    <span class="profile-detail-value"><%= HtmlUtils.esc(currentUser.getEmail()) %></span>
                </div>
                <div class="profile-detail-row">
                    <span class="profile-detail-label">Mobile Number</span>
                    <span class="profile-detail-value"><%= (currentUser.getMobileNumber() != null && !currentUser.getMobileNumber().isBlank()) ? HtmlUtils.esc(currentUser.getMobileNumber()) : "Not provided" %></span>
                </div>
                <div class="profile-detail-row">
                    <span class="profile-detail-label">Member Since</span>
                    <span class="profile-detail-value"><%= currentUser.getJoinedDate() != null ? currentUser.getJoinedDate().toString() : "-" %></span>
                </div>
            </div>

            <form action="profile" method="post" id="profileEditMode" style="display:none;">
                <input type="hidden" name="action" value="updateInfo">

                <div class="form-group">
                    <label class="form-label" for="name">Name</label>
                    <input type="text" id="name" name="name" class="form-control" value="<%= HtmlUtils.esc(currentUser.getName()) %>" required>
                </div>

                <div class="form-group">
                    <label class="form-label" for="email">Email</label>
                    <input type="email" id="email" name="email" class="form-control" value="<%= HtmlUtils.esc(currentUser.getEmail()) %>" required>
                </div>

                <div class="form-group">
                    <label class="form-label" for="mobileNumber">Mobile Number</label>
                    <input type="text" id="mobileNumber" name="mobileNumber" class="form-control"
                           value="<%= currentUser.getMobileNumber() != null ? HtmlUtils.esc(currentUser.getMobileNumber()) : "" %>"
                           placeholder="Not provided">
                </div>

                <div style="display:flex; gap:12px;">
                    <button type="submit" class="btn btn-primary" style="flex:1;">💾 Save Changes</button>
                    <button type="button" class="btn btn-secondary" onclick="toggleProfileEdit(false)">Cancel</button>
                </div>
            </form>
        </div>

        <!-- Places this user has contributed - reuses the same
             _place_card.jsp include as the homepage/search results, so
             rating, saving, and "Add to Trip" all work here too. -->
        <% if (!contributedPlaces.isEmpty()) { %>
            <header class="page-header" style="max-width: 900px; margin-top: 40px;">
                <div class="page-title">
                    <h1>🗺️ Places You've Contributed</h1>
                </div>
            </header>
            <section class="grid-container" style="max-width: 900px;">
                <%
                    for (Place p : contributedPlaces) {
                        request.setAttribute("cardPlace", p);
                        request.setAttribute("cardSavedIds", savedIds);
                        request.setAttribute("cardMyTrips", myTrips);
                %>
                    <jsp:include page="_place_card.jsp" flush="true" />
                <% } %>
            </section>
        <% } else { %>
            <div class="form-card" style="max-width: 900px; margin-top: 40px; text-align:center; color:var(--text-muted);">
                You haven't added any places yet. <a href="add_place.jsp" style="color:var(--primary-green); font-weight:600;">Share your first discovery →</a>
            </div>
        <% } %>
    </main>

</div>

<script>
    function toggleProfileEdit(editing) {
        document.getElementById('profileViewMode').style.display = editing ? 'none' : 'block';
        document.getElementById('profileEditMode').style.display = editing ? 'block' : 'none';
        document.getElementById('editToggleBtn').style.display = editing ? 'none' : 'inline-flex';
    }
    <% if (reopenDetailsEdit) { %>
    toggleProfileEdit(true);
    <% } %>
</script>

</body>
</html>
