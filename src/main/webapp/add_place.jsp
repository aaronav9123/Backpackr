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
    <style>
        /* Page Background */
        body {
            background: linear-gradient(rgba(15, 23, 42, 0.75), rgba(15, 23, 42, 0.85)),
                        url('https://images.unsplash.com/photo-1488646953014-85cb44e25828?auto=format&fit=crop&w=1920&q=80') center/cover no-repeat fixed;
            min-height: 100vh;
        }

        .main-content {
            background: transparent;
        }

        /* Glassmorphic Dark Container matching Sidebar Theme */
        .add-place-card {
            background: rgba(17, 24, 39, 0.85);
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            border: 1px solid rgba(255, 255, 255, 0.12);
            border-radius: 16px;
            box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.4), 0 8px 10px -6px rgba(0, 0, 0, 0.3);
            overflow: hidden;
        }

        .add-place-banner {
            background: linear-gradient(135deg, rgba(37, 99, 235, 0.9), rgba(29, 78, 216, 0.8));
            padding: 2rem;
            color: #ffffff;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }

        .add-place-banner h2 {
            color: #ffffff !important;
            margin-bottom: 8px;
        }

        .add-place-banner p {
            color: rgba(255, 255, 255, 0.85) !important;
        }

        .add-place-form {
            padding: 2rem;
        }

        /* Form Labels & Headings Fix */
        .form-section-title {
            color: #38bdf8 !important; /* Bright cyan accent for section titles */
            font-size: 1.15rem;
            font-weight: 600;
            border-left: 4px solid #38bdf8;
            padding-left: 10px;
            margin-bottom: 1.25rem;
        }

        .form-label {
            color: #e2e8f0 !important; /* Clear light slate text */
            font-weight: 500;
            margin-bottom: 6px;
            display: block;
        }

        /* Input Controls Styling Fix */
        .add-place-form .form-control {
            background-color: rgba(15, 23, 42, 0.8) !important;
            border: 1px solid rgba(255, 255, 255, 0.2) !important;
            color: #f8fafc !important;
            border-radius: 8px;
            padding: 10px 14px;
            width: 100%;
            transition: all 0.2s ease;
        }

        .add-place-form .form-control:focus {
            border-color: #38bdf8 !important;
            outline: none;
            box-shadow: 0 0 0 3px rgba(56, 189, 248, 0.25);
        }

        .add-place-form .form-control::placeholder {
            color: #94a3b8 !important;
        }

        .add-place-form select.form-control option {
            background-color: #0f172a;
            color: #f8fafc;
        }

        .form-hint {
            color: #94a3b8 !important;
            display: block;
            margin-top: 4px;
        }

        .image-upload-box {
            background: rgba(15, 23, 42, 0.5);
            border: 2px dashed rgba(255, 255, 255, 0.2);
            padding: 1.5rem;
            border-radius: 10px;
            text-align: center;
        }

        .publish-btn {
            background: linear-gradient(135deg, #2563eb, #1d4ed8);
            color: #ffffff;
            font-weight: 600;
            padding: 12px 28px;
            border-radius: 8px;
            border: none;
            cursor: pointer;
            box-shadow: 0 4px 12px rgba(37, 99, 235, 0.3);
            transition: transform 0.15s ease, box-shadow 0.15s ease;
        }

        .publish-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 16px rgba(37, 99, 235, 0.4);
        }
    </style>
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
                                    We'll read the exact coordinates from this link automatically - you can leave
                                    Latitude/Longitude blank below if you paste a link here.
                                </small>
                            </div>

                            <div class="form-row-2">
                                <div class="form-group">
                                    <label class="form-label" for="latitude">Latitude <span style="font-weight:400; opacity: 0.8;">(only needed if no Maps link above)</span></label>
                                    <input type="text" id="latitude" name="latitude" class="form-control" placeholder="e.g. 9.9816">
                                </div>
                                <div class="form-group">
                                    <label class="form-label" for="longitude">Longitude <span style="font-weight:400; opacity: 0.8;">(only needed if no Maps link above)</span></label>
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
                                <p style="margin-top:15px;color:#94a3b8;">
                                    Upload a clear photo to help travellers identify this place.
                                </p>
                            </div>
                        </div>

                        <!-- Action Submit Group -->
                        <div class="publish-area" style="margin-top: 2rem;">
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