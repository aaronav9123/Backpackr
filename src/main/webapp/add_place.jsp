<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="com.backpackr.model.User" %>
<%@ page import="com.backpackr.util.HtmlUtils" %>

<%
    User currentUser = (User) session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    String activePage = "addplace";
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backpackr - Add a Place</title>
    <link rel="stylesheet" href="css/style.css?v=3">
</head>
<body>

<div class="app-container">

    <%@ include file="_sidebar.jsp" %>

    <main class="main-content">
        <header class="page-header">
            <div class="page-title">
                <h1>Add a Place ➕</h1>
                <p>Found a hidden gem, budget stay, or great food spot? Share it — it goes live instantly, no approval needed.</p>
            </div>
        </header>

        <% if (request.getParameter("error") != null) { %>
            <div class="alert alert-error">❌ <%= HtmlUtils.esc(request.getParameter("error")) %></div>
        <% } %>

        <div class="add-place-wrapper">
            <div class="add-place-card">
                <div class="add-place-banner">
                    <h2>📍 Share a New Place</h2>
                    <p>
                        Help fellow backpackers discover amazing places.
                        Your contribution becomes instantly available to the community.
                    </p>
                </div>

                <div class="add-place-form">
                    <form action="addPlace" method="post" enctype="multipart/form-data">

                        <!-- Section 1: Basic Information -->
                        <div class="form-section">
                            <div class="form-section-title">Basic Information</div>
                            
                            <div class="form-group">
                                <label class="form-label" for="placeName">Place Name *</label>
                                <input type="text" id="placeName" name="placeName" class="form-control"
                                       placeholder="e.g. Cherai Beach Sunset Point" required>
                            </div>

                            <div class="form-row-2">
                                <div class="form-group">
                                    <label class="form-label" for="category">Category *</label>
                                    <select id="category" name="category" class="form-control" required>
                                        <option value="Hidden Gem">💎 Hidden Gem</option>
                                        <option value="Local Attraction">🏛️ Local Attraction / Tourist Place</option>
                                        <option value="Budget Food">🍜 Budget Food / Restaurant / Cafe</option>
                                        <option value="Scenic Spot">🌅 Scenic Spot / Viewpoint</option>
                                        <option value="Budget Stay">🛏️ Budget Stay</option>
                                        <option value="Shopping">🛍️ Shopping Place</option>
                                    </select>
                                </div>
                                <div class="form-group">
                                    <label class="form-label" for="estimatedCost">Estimated Cost (Rs)</label>
                                    <input type="number" id="estimatedCost" name="estimatedCost" class="form-control"
                                           min="0" placeholder="e.g. 250">
                                </div>
                            </div>

                            <div class="form-group">
                                <label class="form-label" for="description">Description</label>
                                <textarea id="description" name="description" class="form-control" rows="3"
                                          placeholder="What makes this place worth visiting?"></textarea>
                            </div>
                        </div>

                        <!-- Section 2: Location Details -->
                        <div class="form-section">
                            <div class="form-section-title">Location Details</div>

                            <div class="form-row-2">
                                <div class="form-group">
                                    <label class="form-label" for="district">District *</label>
                                    <input type="text" id="district" name="district" class="form-control" placeholder="e.g. Ernakulam" required>
                                </div>
                                <div class="form-group">
                                    <label class="form-label" for="state">State *</label>
                                    <input type="text" id="state" name="state" class="form-control" placeholder="e.g. Kerala" required>
                                </div>
                            </div>

                            <div class="form-group">
                                <label class="form-label" for="address">Address</label>
                                <input type="text" id="address" name="address" class="form-control" placeholder="Street / landmark">
                            </div>

                            <div class="form-group">
                                <label class="form-label" for="mapsLink">Google Maps Link</label>
                                <input type="url" id="mapsLink" name="mapsLink" class="form-control" placeholder="Paste a share link from Google Maps (Share &rarr; Copy link)">
                                <small class="form-hint">
                                    <%-- BUG FIX (Location accuracy / MAPS_LINK not saved): pasting a
                                         Google Maps share link is now the easiest way to pin an accurate
                                         location - the server reads the coordinates straight out of the
                                         link, and also keeps the link itself so the place page can link
                                         back to it. Leave Latitude/Longitude blank if you paste a link
                                         here. --%>
                                    We'll read the exact coordinates from this link automatically - you can leave
                                    Latitude/Longitude blank below if you paste a link here.
                                </small>
                            </div>

                            <div class="form-row-2">
                                <div class="form-group">
                                    <label class="form-label" for="latitude">Latitude <span style="font-weight:400;">(only needed if no Maps link above)</span></label>
                                    <input type="text" id="latitude" name="latitude" class="form-control" placeholder="e.g. 9.9816">
                                </div>
                                <div class="form-group">
                                    <label class="form-label" for="longitude">Longitude <span style="font-weight:400;">(only needed if no Maps link above)</span></label>
                                    <input type="text" id="longitude" name="longitude" class="form-control" placeholder="e.g. 76.2999">
                                </div>
                            </div>
                        </div>

                        <!-- Section 3: Visiting Information -->
                        <div class="form-section">
                            <div class="form-section-title">Visiting Information</div>

                            <div class="form-row-2">
                                <div class="form-group">
                                    <label class="form-label" for="openingTime">Opening Time</label>
                                    <input type="text" id="openingTime" name="openingTime" class="form-control" placeholder="e.g. 9:00 AM - 6:00 PM">
                                </div>
                                <div class="form-group">
                                    <label class="form-label" for="bestTime">Best Time to Visit</label>
                                    <input type="text" id="bestTime" name="bestTime" class="form-control" placeholder="e.g. Early morning, Nov-Feb">
                                </div>
                            </div>
                        </div>

                        <!-- Section 4: Photo Section -->
                        <div class="form-section">
                            <div class="form-section-title">Photo</div>
                            <div class="image-upload-box">
                                <div class="form-group" style="margin-bottom: 0;">
                                    <input type="file" id="image" name="image" accept="image/*" class="form-control">
                                </div>
                                <p style="margin-top:15px;color:#94A3B8;">
                                    Upload a clear photo to help travellers identify this place.
                                </p>
                            </div>
                        </div>

                        <!-- Action Submit Group -->
                        <div class="publish-area">
                            <button type="submit" class="btn btn-primary publish-btn">
                                ✨ Publish Place
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </main>

</div>

</body>
</html>