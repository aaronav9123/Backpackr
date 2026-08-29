package com.backpackr.controller;

import java.io.IOException;

import com.backpackr.dao.SavedPlaceDAO;
import com.backpackr.model.User;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/save")
public class SavedPlaceServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private SavedPlaceDAO savedPlaceDAO = new SavedPlaceDAO();

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
            boolean nowSaved = savedPlaceDAO.toggleSave(user.getUserId(), placeId);
            response.getWriter().write("{\"success\":true,\"saved\":" + nowSaved + "}");
        } catch (Exception e) {
            e.printStackTrace();
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            response.getWriter().write("{\"success\":false,\"message\":\"Unexpected error\"}");
        }
    }
}
