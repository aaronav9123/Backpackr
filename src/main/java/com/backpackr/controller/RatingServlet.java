package com.backpackr.controller;

import java.io.IOException;

import com.backpackr.dao.PlaceDAO;
import com.backpackr.dao.RatingDAO;
import com.backpackr.model.Place;
import com.backpackr.model.User;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/rate")
public class RatingServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private RatingDAO ratingDAO = new RatingDAO();
    private PlaceDAO placeDAO = new PlaceDAO();

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("application/json");
        HttpSession session = request.getSession(false);
        User user = (session != null) ? (User) session.getAttribute("currentUser") : null;

        if (user == null) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.getWriter().write("{\"success\":false,\"message\":\"Please log in\"}");
            return;
        }

        try {
            int placeId = Integer.parseInt(request.getParameter("placeId"));
            int stars = Integer.parseInt(request.getParameter("stars"));

            if (stars < 1 || stars > 5) {
                response.getWriter().write("{\"success\":false,\"message\":\"Invalid rating\"}");
                return;
            }

            boolean saved = ratingDAO.rate(placeId, user.getUserId(), stars);
            if (!saved) {
                response.getWriter().write("{\"success\":false,\"message\":\"Could not save rating\"}");
                return;
            }

            Place refreshed = placeDAO.getPlaceById(placeId);
            String json = String.format(
                "{\"success\":true,\"avgRating\":%.1f,\"ratingCount\":%d}",
                refreshed != null ? refreshed.getAvgRating() : stars,
                refreshed != null ? refreshed.getRatingCount() : 1
            );
            response.getWriter().write(json);
        } catch (Exception e) {
            e.printStackTrace();
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            response.getWriter().write("{\"success\":false,\"message\":\"Unexpected error\"}");
        }
    }
}
