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
    <link rel="stylesheet" href="css/style.css?v=3">
    <style>
        /* Page Background (Dark Nature/Travel Overlay) */
        body {
            background: linear-gradient(rgba(10, 25, 20, 0.82), rgba(15, 23, 42, 0.90)),
                        url('https://images.unsplash.com/photo-1511497584788-876761c12986?auto=format&fit=crop&w=1920&q=80') center/cover no-repeat fixed;
            min-height: 100vh;
        }

        .main-content {
            background: transparent;
        }

        /* Hero Banner - Vibrant Forest Green Theme */
        .profile-hero {
            background: linear-gradient(135deg, rgba(16, 185, 129, 0.9), rgba(5, 150, 105, 0.85));
            border-radius: 16px;
            padding: 2.2rem;
            display: flex;
            align-items: center;
            gap: 2rem;
            box-shadow: 0 10px 25px -5px rgba(5, 150, 105, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.15);
            margin-bottom: 2rem;
        }

        .profile-hero-avatar-wrap {
            position: relative;
            flex-shrink: 0;
        }

        .profile-hero-avatar-img, .profile-hero-avatar-fallback {
            width: 100px;
            height: 100px;
            border-radius: 50%;
            object-fit: cover;
            border: 3px solid rgba(255, 255, 255, 0.8);
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
        }

        .profile-hero-avatar-fallback {
            background: #047857;
            color: #ffffff;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 2.5rem;
            font-weight: 700;
        }

        .profile-hero-camera-btn {
            position: absolute;
            bottom: 2px;
            right: 2px;
            background: #ffffff;
            border: none;
            border-radius: 50%;
            width: 32px;
            height: 32px;
            cursor: pointer;
            box-shadow: 0 2px 8px rgba(0,0,0,0.3);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.9rem;
            transition: transform 0.15s ease;
        }

        .profile-hero-camera-btn:hover {
            transform: scale(1.1);
        }

        .profile-hero-info h2 {
            color: #ffffff !important;
            font-size: 1.75rem;
            margin-bottom: 4px;
            text-shadow: 0 2px 4px rgba(0,0,0,0.2);
        }

        .profile-hero-info p {
            color: rgba(255, 255, 255, 0.9) !important;
            margin-bottom: 12px;
        }

        .profile-hero-stats {
            display: flex;
            gap: 1.25rem;
            flex-wrap: wrap;
        }

        .profile-hero-stats span {
            background: rgba(0, 0, 0, 0.25);
            padding: 6px 14px;
            border-radius: 20px;
            color: #ffffff;
            font-size: 0.88rem;
            backdrop-filter: blur(4px);
        }

        /* Glassmorphic Dark Card */
        .form-card {
            background: rgba(15, 23, 42, 0.85) !important;
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            border: 1px solid rgba(255, 255, 255, 0.12) !important;
            border-radius: 16px;
            padding: 2rem;
            box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.4);
        }

        .profile-details-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 1.5rem;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
            padding-bottom: 1rem;
        }

        .profile-details-header h3 {
            color: #34d399 !important; /* Emerald green accent */
            margin: 0;
            font-size: 1.25rem;
        }

        /* Read-Only Details Rows */
        .profile-detail-row {
            display: flex;
            justify-content: space-between;
            padding: 12px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.06);
        }

        .profile-detail-label {
            color: #94a3b8;
            font-weight: 500;
        }

        .profile-detail-value {
            color: #f8fafc;
            font-weight: 600;
        }

        /* Edit Form Inputs */
        .form-label {
            color: #e2e8f0 !important;
            margin-bottom: 6px;
            display: block;
        }

        .form-control {
            background-color: rgba(10, 20, 30, 0.8) !important;
            border: 1px solid rgba(255, 255, 255, 0.2) !important;
            color: #f8fafc !important;
            border-radius: 8px;
            padding: 10px 14px;
            width: 100%;
        }

        .form-control:focus {
            border-color: #34d399 !important;
            outline: none;
            box-shadow: 0 0 0 3px rgba(52, 211, 153, 0.25);
        }

        /* Buttons */
        .btn-primary {
            background: linear-gradient(135deg, #10b981, #059669) !important;
            color: #ffffff !important;
            border: none;
            border-radius: 8px;
            padding: 10px 20px;
            font-weight: 600;
            cursor: pointer;
            box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
            transition: all 0.2s ease;
        }

        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 16px rgba(16, 185, 129, 0.4);
        }

        .btn-secondary {
            background: rgba(255, 255, 255, 0.1) !important;
            color: #e2e8f0 !important;
            border: 1px solid rgba(255, 255, 255, 0.2) !important;
            border-radius: 8px;
            padding: 8px 16px;
            cursor: pointer;
            transition: background 0.2s ease;
        }

        .btn-secondary:hover {
            background: rgba(255, 255, 255, 0.2) !important;
        }

        .page-title h1, .page-title p {
            color: #ffffff;
            text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
        }
    </style>
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

        <!-- Hero banner showing profile avatar, name, and user stats -->
        <div class="profile-hero">
            <div class="profile-hero-avatar-wrap">
                <% if (avatarUrl != null) { %>
                    <img src="<%= HtmlUtils.esc(avatarUrl) %>" alt="Profile photo" class="profile-hero-avatar-img">
                <% } else { %>
                    <div class="profile-hero-avatar-fallback">
                        <%= (currentUser.getName() != null && !currentUser.getName().isEmpty()) ? HtmlUtils.esc(currentUser.getName().substring(0, 1).toUpperCase()) : "?" %>
                    </div>
                <% } %>
                
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

        <!-- Profile details view/edit form card -->
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

                <div class="form-group" style="margin-bottom: 1rem;">
                    <label class="form-label" for="name">Name</label>
                    <input type="text" id="name" name="name" class="form-control" value="<%= HtmlUtils.esc(currentUser.getName()) %>" required>
                </div>

                <div class="form-group" style="margin-bottom: 1rem;">
                    <label class="form-label" for="email">Email</label>
                    <input type="email" id="email" name="email" class="form-control" value="<%= HtmlUtils.esc(currentUser.getEmail()) %>" required>
                </div>

                <div class="form-group" style="margin-bottom: 1.5rem;">
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

        <!-- Contributed places list section -->
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
            <div class="form-card" style="max-width: 900px; margin-top: 40px; text-align:center; color:#94a3b8;">
                You haven't added any places yet. <a href="add_place.jsp" style="color:#34d399; font-weight:600; text-decoration:none;">Share your first discovery →</a>
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