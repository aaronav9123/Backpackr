package com.backpackr.controller;

import java.io.IOException;

import com.backpackr.dao.UserDAO;
import com.backpackr.model.User;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/login")
public class LoginServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        // 1. Get login form data
        String email = request.getParameter("email");
        String password = request.getParameter("password");

        UserDAO dao = new UserDAO();

        // 2. Validate user
        User user = dao.validateUser(email, password);

        if (user != null) {

            // 3. Create session
            // BUG FIX (Security - session fixation): a brand-new session is
            // now started on every successful login instead of reusing
            // whatever session (if any) the browser already had. Without
            // this, an attacker who tricks a victim into using a
            // session ID the attacker already knows (classic session
            // fixation) could hijack the victim's freshly-authenticated
            // session once they log in.
            HttpSession oldSession = request.getSession(false);
            if (oldSession != null) {
                oldSession.invalidate();
            }
            HttpSession session = request.getSession(true);
            session.setAttribute("currentUser", user);

            // optional: session timeout (30 min)
            session.setMaxInactiveInterval(30 * 60);

            // 4. Redirect to home page (after login)
            response.sendRedirect("home.jsp");

        } else {

            // 5. Invalid login
            request.setAttribute("error", "Invalid email or password");
            request.getRequestDispatcher("login.jsp").forward(request, response);
        }
    }
}