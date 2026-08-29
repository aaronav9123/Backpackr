<%@ page import="com.backpackr.util.HtmlUtils" %>
<%-- Shared sidebar. Include with: String activePage = "home"; before <%@ include file="_sidebar.jsp" %> --%>
<aside class="sidebar">
    <div class="logo-container">🎒 Backpackr<span>.</span></div>
    <ul class="nav-links">
        <li class="<%= "home".equals(activePage) ? "active" : "" %>"><a href="home.jsp">🔍 Home</a></li>
        <li class="<%= "trips".equals(activePage) ? "active" : "" %>"><a href="trips.jsp">✈️ My Trips</a></li>
        <li class="<%= "saved".equals(activePage) ? "active" : "" %>"><a href="saved_places.jsp">🔖 Saved Places</a></li>
        <li class="<%= "addplace".equals(activePage) ? "active" : "" %>"><a href="add_place.jsp">➕ Add Place</a></li>
        <li class="<%= "profile".equals(activePage) ? "active" : "" %>"><a href="profile.jsp">👤 Profile</a></li>
    </ul>
    <div class="user-profile-section">
        <%-- NEW FEATURE (Profile enhancements): show the uploaded profile
             photo here too (falls back to the existing initial-letter
             avatar when none has been set), and link straight to
             profile.jsp - same fix already applied to the homepage's
             navbar avatar, for consistency everywhere the avatar appears. --%>
        <a href="profile.jsp" style="text-decoration:none; display:contents;">
        <% if (currentUser.getProfileImage() != null && !currentUser.getProfileImage().isBlank()) { %>
            <img src="<%= HtmlUtils.esc(currentUser.getProfileImage()) %>" alt="Profile photo" class="user-avatar" style="object-fit:cover;">
        <% } else { %>
            <div class="user-avatar">
                <%= (currentUser.getName() != null && !currentUser.getName().isEmpty()) ? HtmlUtils.esc(currentUser.getName().substring(0, 1).toUpperCase()) : "?" %>
            </div>
        <% } %>
        </a>
        <div class="user-info">
            <span class="user-name"><%= HtmlUtils.esc(currentUser.getName()) %></span>
            <span class="user-role">Explorer</span>
        </div>
        <a href="logout" style="margin-left:auto; font-size:1.2rem; color:var(--danger);" title="Logout">🚪</a>
    </div>
</aside>
