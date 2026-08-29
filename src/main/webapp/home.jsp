<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="com.backpackr.model.User" %>
<%@ page import="com.backpackr.model.Place" %>
<%@ page import="com.backpackr.model.Trip" %>
<%@ page import="com.backpackr.dao.PlaceDAO" %>
<%@ page import="com.backpackr.dao.TripDAO" %>
<%@ page import="com.backpackr.dao.SavedPlaceDAO" %>
<%@ page import="java.util.List" %>
<%@ page import="java.util.LinkedList" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="com.backpackr.util.HtmlUtils" %>

<%
    // Session validation
    User currentUser = (User) session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    // Load filter/search parameters
    String query = request.getParameter("q");
    String category = request.getParameter("category");
    boolean hasQuery = (query != null && !query.trim().isEmpty());
    boolean hasCategory = (category != null && !category.trim().isEmpty() && !category.equalsIgnoreCase("All"));
    // BUG FIX (Feature request - "Recently Added" / "View all" only ever
    // showed 4 places): "View all" used to link to home.jsp?category=All,
    // but category=All was treated identically to "no search yet" (see
    // hasCategory above), so clicking it just reloaded the same homepage
    // teaser view instead of actually listing every place. It's now a
    // distinct ?view=all flag that genuinely lists every contributed place
    // via PlaceDAO.getAllPlaces().
    boolean isViewAll = "all".equalsIgnoreCase(request.getParameter("view"));

    // NEW FEATURE (Multi-user duplicate-place prevention): place_exists.jsp's
    // "View This Place" button links here with ?placeId=, so a single
    // already-existing place can be jumped to directly (via the same
    // PlaceDAO.getPlaceById() the rest of the app already uses) instead of
    // needing a brand-new "place details" page just for this flow.
    String placeIdParam = request.getParameter("placeId");
    boolean hasPlaceId = placeIdParam != null && !placeIdParam.trim().isEmpty();
    Place singlePlace = null;
    if (hasPlaceId) {
        try {
            singlePlace = new PlaceDAO().getPlaceById(Integer.parseInt(placeIdParam.trim()));
        } catch (NumberFormatException ignored) {
            singlePlace = null;
        }
        hasPlaceId = singlePlace != null;
    }

    boolean hasSearched = hasQuery || hasCategory || isViewAll || hasPlaceId;

    PlaceDAO placeDAO = new PlaceDAO();
    List<Place> places = new ArrayList<>();

    if (hasPlaceId) {
        places.add(singlePlace);
    } else if (hasSearched) {
        if (hasQuery && hasCategory) {
            places = placeDAO.searchPlacesByCategory(query, category);
        } else if (hasQuery) {
            places = placeDAO.searchPlaces(query);
        } else if (hasCategory) {
            places = placeDAO.getPlacesByCategory(category);
        } else {
            places = placeDAO.getAllPlaces();
        }
    }
    if (category == null) category = "All";

    // Track "recently searched" in session (max 5, most recent first)
    @SuppressWarnings("unchecked")
    LinkedList<String> recentSearches = (LinkedList<String>) session.getAttribute("recentSearches");
    if (recentSearches == null) {
        recentSearches = new LinkedList<>();
    }
    if (hasQuery) {
        recentSearches.remove(query);
        recentSearches.addFirst(query);
        while (recentSearches.size() > 5) {
            recentSearches.removeLast();
        }
        session.setAttribute("recentSearches", recentSearches);
    }

    // Popular searches - derived live from the database, never hardcoded
    List<String> popularLocations = placeDAO.getPopularLocations(6);

    // Load user's trips for the "Add to Trip" control
    TripDAO tripDAO = new TripDAO();
    List<Trip> myTrips = tripDAO.getTripsByUser(currentUser.getUserId());

    // Which of the visible places has the current user already saved
    SavedPlaceDAO savedPlaceDAO = new SavedPlaceDAO();
    List<Integer> savedIds = savedPlaceDAO.getSavedPlaceIds(currentUser.getUserId());

    // Homepage-only data: only fetched when we're on the welcome screen,
    // not while showing search results.
    int totalPlaces = placeDAO.getTotalPlaceCount();
    List<Place> trendingPlaces = hasSearched ? new ArrayList<Place>() : placeDAO.getTopRatedPlaces(4);
    // BUG FIX (Feature request): "Recently Added" now shows 6 places
    // directly on the homepage instead of 4; "View all" (below) covers
    // seeing everything beyond that.
    List<Place> recentPlaces = hasSearched ? new ArrayList<Place>() : placeDAO.getRecentPlaces(6);
%>


<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backpackr - Explore More. Spend Less. Experience Real.</title>
    <link rel="stylesheet" href="css/style.css?v=3">
    <link rel="stylesheet" href="css/homepage.css?v=3">
</head>
<body class="light-mode">

<!-- ============================================================ -->
<!-- NAVBAR                                                        -->
<!-- ============================================================ -->
<nav class="navbar-light">
    <a href="home.jsp" class="navbar-brand">
        <span class="logo-badge">🎒</span> Backpackr
    </a>
    <div class="navbar-links">
        <a href="home.jsp" class="active">🏠 Home</a>
        <a href="trips.jsp">✈️ My Trips</a>
        <a href="saved_places.jsp">🔖 Saved Places</a>
        <a href="add_place.jsp">➕ Add Place</a>
        <a href="trips.jsp">🤖 AI Planner</a>
    </div>
    <div class="navbar-actions">
        <a href="add_place.jsp" class="btn btn-primary btn-sm" style="border-radius:12px;">✨ Share a Place</a>
        <div class="dropdown">
            <%-- BUG FIX (Navigation): the avatar circle used to be a plain
                 <div> with no link of its own - the only way to reach
                 Profile was via the hover/focus dropdown underneath it,
                 which doesn't reliably open on a simple click (especially
                 on touch devices, or a fast click instead of a hover). It's
                 now wrapped in a real link straight to profile.jsp, so
                 clicking it always works; the hover dropdown below still
                 offers the extra Saved Places / Logout shortcuts. --%>
            <%-- NEW FEATURE (Profile enhancements): show the uploaded
                 profile photo here too when one is set, same as the
                 sidebar avatar on every other page. --%>
            <a href="profile.jsp" class="navbar-avatar" tabindex="0" title="View Profile"
               <% if (currentUser.getProfileImage() != null && !currentUser.getProfileImage().isBlank()) { %>
                   style="background-image:url('<%= HtmlUtils.esc(currentUser.getProfileImage()) %>'); background-size:cover; background-position:center;"
               <% } %>><%
                if (currentUser.getProfileImage() == null || currentUser.getProfileImage().isBlank()) {
                    out.print((currentUser.getName() != null && !currentUser.getName().isEmpty()) ? HtmlUtils.esc(currentUser.getName().substring(0, 1).toUpperCase()) : "?");
                }
            %></a>
            <div class="dropdown-menu">
                <a href="profile.jsp">👤 Profile</a>
                <a href="saved_places.jsp">🔖 Saved Places</a>
                <a href="logout">🚪 Logout</a>
            </div>
        </div>
    </div>
</nav>

<!-- Success/Error Feedback -->
<%-- BUG FIX (Security - reflected XSS): success/error banners echo back a
     query-string parameter. Without escaping, a crafted link like
     home.jsp?error=<script>...</script> would execute in the visitor's
     browser the moment they clicked it (or the page auto-redirected here). --%>
<% if (request.getParameter("success") != null) { %>
    <div class="alert alert-success" style="margin: 16px 40px 0;">✅ <%= HtmlUtils.esc(request.getParameter("success")) %></div>
<% } %>
<% if (request.getParameter("error") != null) { %>
    <div class="alert alert-error" style="margin: 16px 40px 0;">❌ <%= HtmlUtils.esc(request.getParameter("error")) %></div>
<% } %>

<% if (!hasSearched) { %>

    <!-- ============================================================ -->
    <!-- HERO                                                          -->
    <!-- ============================================================ -->
    <section class="hero-banner">
        <div class="hero-banner-inner">
            <span class="hero-eyebrow">🌍 Hey <%= HtmlUtils.esc(currentUser.getName()) %>, welcome back</span>
            <h1>Explore More.<br>Spend Less.<br><span class="accent-line">Experience Real.</span></h1>
            <p class="hero-subtitle">Discover hidden places, local food, budget stays and travel routes recommended by real travelers — not travel agencies.</p>
            <div class="hero-cta-row">
                <a href="#discover" class="btn btn-primary">Start Exploring</a>
                <a href="trips.jsp" class="btn btn-secondary">🤖 Plan with AI</a>
            </div>
        </div>
    </section>

    <!-- Floating search card -->
    <div class="homepage-search-card">
        <form action="home.jsp" method="get" class="homepage-search-form" id="discover">
            <div class="field">
                <label>Where to</label>
                <input type="text" name="q" placeholder="Search a district, state or place..." autofocus>
            </div>
            <div class="field">
                <label>Category</label>
                <select name="category">
                    <option value="All">Any category</option>
                    <option value="Hidden Gem">💎 Hidden Gems</option>
                    <option value="Local Attraction">🏛️ Attractions</option>
                    <option value="Budget Food">🍜 Food Spots</option>
                    <option value="Scenic Spot">🌅 Viewpoints</option>
                    <option value="Budget Stay">🛏️ Budget Stays</option>
                    <option value="Shopping">🛍️ Shopping</option>
                </select>
            </div>
            <button type="submit" class="btn btn-primary">🔍 Explore</button>
        </form>

        <div class="feature-strip">
            <div class="feature-pill"><span class="icon">🤖</span><span><strong>AI Planner</strong><span class="subtext">Smart itineraries</span></span></div>
            <div class="feature-pill"><span class="icon">💰</span><span><strong>Budget Friendly</strong><span class="subtext">Save more</span></span></div>
            <div class="feature-pill"><span class="icon">🌍</span><span><strong>Community Driven</strong><span class="subtext">Real contributions</span></span></div>
            <div class="feature-pill"><span class="icon">💎</span><span><strong>Hidden Gems</strong><span class="subtext">Off the beaten path</span></span></div>
        </div>
    </div>

    <!-- Recently searched / popular searches -->
    <section class="homepage-section" style="padding-top:30px;">
        <div class="hero-columns">
            <div class="hero-column">
                <h4>🕓 Recently Searched</h4>
                <% if (recentSearches.isEmpty()) { %>
                    <p class="muted-note">Nothing yet — try searching a district above.</p>
                <% } else { %>
                    <div class="chip-list">
                        <% for (String r : recentSearches) { %>
                            <a class="preset-badge" href="home.jsp?q=<%= java.net.URLEncoder.encode(r, "UTF-8") %>"><%= HtmlUtils.esc(r) %></a>
                        <% } %>
                    </div>
                <% } %>
            </div>
            <div class="hero-column">
                <h4>🔥 Popular Searches</h4>
                <% if (popularLocations.isEmpty()) { %>
                    <p class="muted-note">Be the first to add a place and start the map!</p>
                <% } else { %>
                    <div class="chip-list">
                        <% for (String loc : popularLocations) { %>
                            <a class="preset-badge" href="home.jsp?q=<%= java.net.URLEncoder.encode(loc, "UTF-8") %>">📍 <%= HtmlUtils.esc(loc) %></a>
                        <% } %>
                    </div>
                <% } %>
            </div>
        </div>
    </section>

    <% if (totalPlaces == 0) { %>

        <!-- ============================================================ -->
        <!-- PLATFORM-WIDE EMPTY STATE - nobody has contributed anything   -->
        <!-- ============================================================ -->
        <div class="platform-empty-state">
            <div class="empty-illustration">🧭🎒✨</div>
            <h3>No adventures shared yet.</h3>
            <p>Be the first traveler to inspire the community.</p>
            <a href="add_place.jsp" class="btn btn-primary">➕ Upload a Place</a>
        </div>

    <% } else { %>

        <!-- ============================================================ -->
        <!-- TRENDING IN THE COMMUNITY - top rated places                 -->
        <!-- ============================================================ -->
        <% if (!trendingPlaces.isEmpty()) { %>
        <section class="homepage-section">
            <div class="homepage-section-head">
                <div>
                    <h2>🔥 Trending in the Community</h2>
                    <p>Highest-rated spots, straight from fellow travelers.</p>
                </div>
                <a href="home.jsp?view=all">View all</a>
            </div>
            <div class="homepage-grid">
                <% for (Place p : trendingPlaces) {
                    request.setAttribute("cardPlace", p);
                    request.setAttribute("cardSavedIds", savedIds);
                    request.setAttribute("cardMyTrips", myTrips);
                %>
                    <jsp:include page="_place_card.jsp" flush="true" />
                <% } %>
            </div>
        </section>
        <% } %>

        <!-- ============================================================ -->
        <!-- RECENTLY ADDED - newest community uploads                    -->
        <!-- ============================================================ -->
        <section class="homepage-section">
            <div class="homepage-section-head">
                <div>
                    <h2>🆕 Recently Added</h2>
                    <p>Fresh finds, uploaded by the community.</p>
                </div>
                <a href="home.jsp?view=all">View all</a>
            </div>
            <div class="homepage-grid">
                <% for (Place p : recentPlaces) {
                    request.setAttribute("cardPlace", p);
                    request.setAttribute("cardSavedIds", savedIds);
                    request.setAttribute("cardMyTrips", myTrips);
                %>
                    <jsp:include page="_place_card.jsp" flush="true" />
                <% } %>
            </div>
        </section>

        <div class="roadmap-note">
            📌 <strong>Coming next:</strong> Local Food, Budget Stays, Travel Stories and a Local Businesses
            directory will appear here once their own community tables are built — they'll pull from real
            uploads the same way these sections do, never hardcoded.
        </div>

    <% } %>

<% } else { %>

    <!-- ============================================================ -->
    <!-- SEARCH RESULTS - everything below comes from the database    -->
    <!-- ============================================================ -->
    <header class="homepage-section" style="padding-bottom:0;">
        <div class="homepage-section-head">
            <div>
                <h1 style="font-size:1.7rem; font-weight:800; color:#0F172A;"><%= hasPlaceId ? HtmlUtils.esc(singlePlace.getPlaceName()) : hasQuery ? ("Results for \"" + HtmlUtils.esc(query) + "\"") : (isViewAll ? "All Places" : HtmlUtils.esc(category)) %></h1>
                <p><%= hasPlaceId ? "Here's the existing community listing for this spot." : (places.size() + " community-contributed spot" + (places.size() == 1 ? "" : "s") + " found.") %></p>
            </div>
            <a href="home.jsp" class="btn btn-secondary">← Back to Home</a>
        </div>
    </header>

    <section class="filter-panel" style="margin: 0 40px;">
        <form action="home.jsp" method="get" class="search-form">
            <input type="text" name="q" class="search-input"
                   placeholder="Refine your search..." value="<%= (query != null) ? HtmlUtils.esc(query) : "" %>">
            <button type="submit" class="btn btn-primary">Search</button>
        </form>

        <div class="category-filters">
            <a href="home.jsp<%= hasQuery ? "?q=" + java.net.URLEncoder.encode(query, "UTF-8") : "" %>" class="filter-chip <%= !hasCategory ? "active" : "" %>">All Spots</a>
            <a href="home.jsp?category=Hidden+Gem<%= hasQuery ? "&q=" + java.net.URLEncoder.encode(query, "UTF-8") : "" %>" class="filter-chip <%= ("Hidden Gem".equals(category)) ? "active" : "" %>">💎 Hidden Gems</a>
            <a href="home.jsp?category=Local+Attraction<%= hasQuery ? "&q=" + java.net.URLEncoder.encode(query, "UTF-8") : "" %>" class="filter-chip <%= ("Local Attraction".equals(category)) ? "active" : "" %>">🏛️ Attractions</a>
            <a href="home.jsp?category=Budget+Food<%= hasQuery ? "&q=" + java.net.URLEncoder.encode(query, "UTF-8") : "" %>" class="filter-chip <%= ("Budget Food".equals(category)) ? "active" : "" %>">🍜 Food</a>
            <a href="home.jsp?category=Scenic+Spot<%= hasQuery ? "&q=" + java.net.URLEncoder.encode(query, "UTF-8") : "" %>" class="filter-chip <%= ("Scenic Spot".equals(category)) ? "active" : "" %>">🌅 Scenic</a>
        </div>
    </section>

    <section class="homepage-grid homepage-section" style="padding-top:24px;">
        <%
            if (places.isEmpty()) {
        %>
            <div class="empty-state" style="grid-column: 1 / -1;">
                <h3>No spots found here yet</h3>
                <p>Nobody has contributed this place yet — be the first!</p>
                <a href="add_place.jsp" class="btn btn-primary">➕ Add This Place</a>
            </div>
        <%
            } else {
                for (Place p : places) {
                    request.setAttribute("cardPlace", p);
                    request.setAttribute("cardSavedIds", savedIds);
                    request.setAttribute("cardMyTrips", myTrips);
        %>
            <jsp:include page="_place_card.jsp" flush="true" />
        <%
                }
            }
        %>
    </section>

<% } %>

<!-- Floating Action Buttons -->
<div class="fab-stack">
    <a href="trips.jsp" class="fab fab-secondary" title="AI Trip Planner">🤖</a>
    <a href="add_place.jsp" class="fab fab-primary" title="Add a Place">➕</a>
</div>

<div id="toast" class="toast"></div>

<script src="js/script.js"></script>
</body>
</html>
