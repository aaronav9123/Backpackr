<%@ page import="java.sql.Connection" %>
<%@ page import="com.backpackr.model.User" %>
<%@ page import="com.backpackr.util.DBConnection" %>
<%@ page contentType="text/html; charset=UTF-8" %>
<%--
    BUG FIX (Security - debug page exposed to anyone, unauthenticated):
    this developer diagnostic page used to be reachable by anyone who
    guessed the URL, with no login check, and printed the raw
    exception message (e.getMessage()) straight into the page - which can
    leak internal details such as the JDBC URL/host/port on a connection
    failure. It's still useful to keep around for verifying the database
    connection after a deploy, so rather than deleting it (per "do not
    remove existing features unless necessary") it now requires a logged-in
    session like every other page, and no longer echoes raw exception text
    to the browser (the full stack trace is still logged server-side via
    e.printStackTrace() for whoever has console/log access).
--%>
<%
    User currentUser = (User) session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }
%>
<!DOCTYPE html>
<html>
<head>
    <title>DB Test</title>
</head>
<body>
<%
    Connection con = null;
    try {
        con = DBConnection.getConnection();
        if (con != null) {
            out.println("<h2 style='color: green;'>Database Connected Successfully!</h2>");
        } else {
            out.println("<h2 style='color: red;'>Database Connection Failed! Check the server log/console.</h2>");
        }
    } catch (Exception e) {
        e.printStackTrace();
        out.println("<h2 style='color: red;'>A database error occurred. Check the server log/console for details.</h2>");
    } finally {
        if (con != null) {
            try { con.close(); } catch (Exception e) { }
        }
    }
%>
</body>
</html>
