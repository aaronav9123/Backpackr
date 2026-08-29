<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="com.backpackr.model.User" %>
<%--
    BUG FIX (UX - index.jsp always bounced logged-in users to login.jsp):
    this welcome/entry page used to unconditionally redirect to login.jsp,
    even for a user who already had a valid session - forcing an
    already-authenticated visitor back through the login form every time
    they hit the app's root URL. It now checks the session first, exactly
    like every other page in the app does, and only sends anonymous
    visitors to login.jsp.
--%>
<%
    User currentUser = (User) session.getAttribute("currentUser");
    if (currentUser != null) {
        response.sendRedirect("home.jsp");
    } else {
        response.sendRedirect("login.jsp");
    }
%>
