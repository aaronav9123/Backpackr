<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="com.backpackr.model.Place" %>
<%@ page import="com.backpackr.model.Trip" %>
<%@ page import="java.util.List" %>
<%@ page import="com.backpackr.util.HtmlUtils" %>
<%
    // Expected request attributes, set by the including page:
    //   cardPlace   -> com.backpackr.model.Place
    //   cardSavedIds -> List<Integer> (place ids the current user saved)
    //   cardMyTrips -> List<Trip> (current user's trips, for the "+" control)
    Place p = (Place) request.getAttribute("cardPlace");
    @SuppressWarnings("unchecked")
    List<Integer> cardSavedIds = (List<Integer>) request.getAttribute("cardSavedIds");
    @SuppressWarnings("unchecked")
    List<Trip> cardMyTrips = (List<Trip>) request.getAttribute("cardMyTrips");

    String categoryClass = "badge-gem";
    if ("Budget Food".equals(p.getCategory())) categoryClass = "badge-food";
    else if ("Local Attraction".equals(p.getCategory())) categoryClass = "badge-attraction";
    else if ("Scenic Spot".equals(p.getCategory())) categoryClass = "badge-scenic";
    boolean isSaved = cardSavedIds != null && cardSavedIds.contains(p.getPlaceId());
    // BUG FIX (per user request): this used to fall back to
    // AIPlannerService.getEstimatedCost(category) - a guessed cost by
    // category (e.g. 500 for "Hidden Gem") - whenever a place had no
    // community-submitted cost. That made it look like "500" was some kind
    // of default form value, when it was really just a display guess. A
    // place with no submitted cost now honestly shows 0 instead of a
    // guessed number.
    double displayCost = p.getAvgCost();
%>
<%-- BUG FIX (Security - stored XSS): every user-controlled field below
     (place name/description/address/image URL/category, contributor name,
     trip names) now goes through HtmlUtils.esc() before being written into
     HTML, and through HtmlUtils.escJs() when written into a JS argument.
     "Add Place" publishes instantly with no moderation, so without this a
     place submitted with a <script> tag in its description would execute
     for every visitor who views it. --%>
<article class="place-card" data-place-id="<%= p.getPlaceId() %>">
    <div class="place-card-img" style="background-image: url('<%= HtmlUtils.esc(p.getImageUrl()) %>');">
        <span class="place-category-badge <%= categoryClass %>"><%= HtmlUtils.esc(p.getCategory()) %></span>
        <button type="button" class="bookmark-btn <%= isSaved ? "saved" : "" %>"
                onclick="toggleSave(this, <%= p.getPlaceId() %>)" title="Save place">
            <%= isSaved ? "🔖" : "📑" %>
        </button>
    </div>
    <div class="place-card-body">
        <h3 class="place-card-title"><%= HtmlUtils.esc(p.getPlaceName()) %></h3>
        <div class="place-card-location">
            📍 <strong><%= HtmlUtils.esc(p.getDistrict()) %>, <%= HtmlUtils.esc(p.getState()) %></strong>
            <% if (p.getAddress() != null) { %> &bull; <%= HtmlUtils.esc(p.getAddress()) %><% } %>
            <%-- BUG FIX (Security - XSS via javascript: URL): only ever
                 render this as a link if it's actually an http(s) URL.
                 HtmlUtils.esc() escapes HTML special characters, but a
                 value like "javascript:alert(1)" is already "safe" HTML
                 text - the risk is in the URL *scheme*, not the markup, so
                 escaping alone doesn't stop it. AddPlaceServlet also now
                 rejects non-http(s) maps links at submission time; this
                 check is defense-in-depth in case any old row was saved
                 before that validation existed. --%>
            <% if (p.getMapsLink() != null && (p.getMapsLink().startsWith("http://") || p.getMapsLink().startsWith("https://"))) { %>
                &bull; <a href="<%= HtmlUtils.esc(p.getMapsLink()) %>" target="_blank" rel="noopener" class="maps-link">🗺️ View on Google Maps</a>
            <% } %>
        </div>
        <p class="place-card-desc"><%= HtmlUtils.esc(p.getDescription()) %></p>

        <div class="rating-row" data-place-id="<%= p.getPlaceId() %>">
            <span class="stars" data-rating="<%= p.getAvgRating() %>">
                <% for (int s = 1; s <= 5; s++) { %>
                    <span class="star <%= s <= Math.round(p.getAvgRating()) ? "filled" : "" %>"
                          onclick="submitRating(<%= p.getPlaceId() %>, <%= s %>, this)">★</span>
                <% } %>
            </span>
            <span class="rating-count">
                <%= p.getRatingCount() > 0 ? String.format("%.1f (%d)", p.getAvgRating(), p.getRatingCount()) : "No ratings yet" %>
            </span>
        </div>

        <div class="contributor-row">
            🧑‍🤝‍🧑 Added by <strong><%= p.getAddedByName() != null ? HtmlUtils.esc(p.getAddedByName()) : "Backpackr Community" %></strong>
        </div>

        <div class="place-card-footer">
            <div class="place-cost">
                Cost: <span>Rs. <%= (int) displayCost %></span>
            </div>

            <% if (cardMyTrips == null || cardMyTrips.size() <= 1) {
                Integer soloTripId = (cardMyTrips == null || cardMyTrips.isEmpty()) ? null : cardMyTrips.get(0).getTripId();
            %>
                <button type="button" class="btn btn-primary btn-sm"
                        onclick="addToTrip(<%= p.getPlaceId() %>, <%= soloTripId %>, this)">➕ Add to Trip</button>
            <% } else { %>
                <div class="add-trip-dropdown">
                    <button type="button" class="btn btn-primary btn-sm">➕ Add to Trip</button>
                    <div class="dropdown-menu">
                        <% for (Trip t : cardMyTrips) { %>
                            <a href="javascript:void(0)" onclick="addToTrip(<%= p.getPlaceId() %>, <%= t.getTripId() %>, this)">
                                <%= HtmlUtils.esc(t.getTripName()) %>
                            </a>
                        <% } %>
                    </div>
                </div>
            <% } %>
        </div>
    </div>
</article>
