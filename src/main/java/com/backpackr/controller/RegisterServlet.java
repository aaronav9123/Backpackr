package com.backpackr.controller;

import java.io.IOException;
import java.util.regex.Pattern;

import com.backpackr.dao.UserDAO;
import com.backpackr.model.User;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@WebServlet("/register")
public class RegisterServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    // BUG FIX (Missing validation - Registration): a simple, dependency-free
    // e-mail shape check. This is intentionally permissive (it is not meant
    // to be a full RFC 5322 validator) - it just catches obviously malformed
    // input before it reaches the database.
    private static final Pattern EMAIL_PATTERN =
        Pattern.compile("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$");

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        // 1. Get form data (matches form input names)
        String name = trim(request.getParameter("name"));
        String email = trim(request.getParameter("email"));
        String password = request.getParameter("password");
        String mobile = trim(request.getParameter("mobileNumber"));

        // BUG FIX (Missing validation - Registration): RegisterServlet used
        // to trust every field blindly and insert it straight into Oracle.
        // Empty names/emails, malformed e-mails, one-character passwords,
        // and non-numeric "mobile numbers" were all silently accepted. Basic
        // server-side checks now run before anything reaches the database
        // (the HTML5 "required" attributes on register.jsp only protect
        // against accidental empty submits from the normal browser form -
        // they do nothing against a direct POST, so this validation must
        // also live server-side).
        if (name == null || name.isEmpty()
                || email == null || email.isEmpty()
                || password == null || password.isEmpty()
                || mobile == null || mobile.isEmpty()) {
            request.setAttribute("error", "Please fill in all fields.");
            request.getRequestDispatcher("register.jsp").forward(request, response);
            return;
        }
        if (!EMAIL_PATTERN.matcher(email).matches()) {
            request.setAttribute("error", "Please enter a valid email address.");
            request.getRequestDispatcher("register.jsp").forward(request, response);
            return;
        }
        if (password.length() < 6) {
            request.setAttribute("error", "Password must be at least 6 characters long.");
            request.getRequestDispatcher("register.jsp").forward(request, response);
            return;
        }
        if (!mobile.matches("[0-9+\\-() ]{7,15}")) {
            request.setAttribute("error", "Please enter a valid mobile number.");
            request.getRequestDispatcher("register.jsp").forward(request, response);
            return;
        }

        // 2. Create User object
        User user = new User();
        user.setName(name);
        user.setEmail(email);
        user.setPassword(password);
        user.setMobileNumber(mobile);

        UserDAO dao = new UserDAO();

        // 3. Check duplicate email first
        if (dao.emailExists(email)) {
            request.setAttribute("error", "Email already registered!");
            request.getRequestDispatcher("register.jsp").forward(request, response);
            return;
        }

        // 4. Register user
        boolean success = dao.registerUser(user);

        if (success) {
            request.setAttribute("message", "Registration successful! Please login.");
            request.getRequestDispatcher("login.jsp").forward(request, response);
        } else {
            request.setAttribute("error", "Registration failed. Try again.");
            request.getRequestDispatcher("register.jsp").forward(request, response);
        }
    }

    private String trim(String value) {
        return value == null ? null : value.trim();
    }
}