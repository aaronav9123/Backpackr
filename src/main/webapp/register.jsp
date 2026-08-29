<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="com.backpackr.util.HtmlUtils" %>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Backpackr - Register</title>

<style>
:root {
    --card-dark: #17233A;
    --primary-green: #22C55E;
    --primary-hover: #15803D;
    --text-white: #FFFFFF;
    --text-muted: #E2E8F0;
}

* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
    font-family: Arial, sans-serif;
}

body {
    background: linear-gradient(rgba(0, 0, 0, 0.45), rgba(0, 0, 0, 0.55)), 
                url('https://images.unsplash.com/photo-1501555088652-021faa106b9b?auto=format&fit=crop&w=1920&q=80') no-repeat center center fixed;
    background-size: cover;
    color: var(--text-white);
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
}

.dashboard-layout {
    display: flex;
    width: 100%;
    max-width: 1200px;
    padding: 0 40px;
    align-items: center;
    justify-content: space-between;
    gap: 40px;
}

.project-showcase {
    flex: 1.2;
    max-width: 600px;
}

.logo-brand {
    font-size: 2.2rem;
    font-weight: bold;
    margin-bottom: 20px;
    text-shadow: 0 2px 10px rgba(0, 0, 0, 0.5);
}

.logo-brand span {
    color: var(--primary-green);
}

.project-showcase h1 {
    font-size: 3.8rem;
    font-weight: bold;
    line-height: 1.15;
    margin-bottom: 20px;
    text-shadow: 0 4px 20px rgba(0, 0, 0, 0.6);
}

.project-showcase h1 span {
    color: var(--primary-green);
}

.project-showcase p {
    color: var(--text-muted);
    font-size: 1.2rem;
    line-height: 1.6;
    text-shadow: 0 2px 12px rgba(0, 0, 0, 0.7);
}

.register-showcase {
    flex: 0.8;
    display: flex;
    justify-content: flex-end;
}

.container {
    background: var(--card-dark);
    padding: 40px 30px;
    border-radius: 18px;
    width: 100%;
    max-width: 380px;
    box-shadow: 0px 15px 35px rgba(0, 0, 0, 0.6);
    border: 1px solid rgba(255, 255, 255, 0.08);
}

h2 {
    text-align: center;
    color: var(--primary-green);
    margin-bottom: 8px;
    font-size: 1.8rem;
}

.form-subtitle {
    text-align: center;
    color: #94A3B8;
    font-size: 0.9rem;
    margin-bottom: 25px;
}

input {
    width: 100%;
    padding: 14px;
    margin: 10px 0;
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    background: #0A101D;
    color: white;
    font-size: 0.95rem;
    transition: border-color 0.2s, box-shadow 0.2s;
}

input:focus {
    outline: none;
    border-color: var(--primary-green);
    box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.15);
}

input::placeholder {
    color: #5A6A85;
}

button {
    width: 100%;
    padding: 14px;
    background: var(--primary-green);
    border: none;
    color: white;
    font-weight: bold;
    border-radius: 8px;
    cursor: pointer;
    font-size: 1rem;
    margin-top: 15px;
    transition: background 0.2s, transform 0.1s;
}

button:hover {
    background: var(--primary-hover);
}

button:active {
    transform: scale(0.99);
}

.alert {
    padding: 12px;
    border-radius: 8px;
    font-size: 0.9rem;
    margin-bottom: 15px;
    text-align: center;
    font-weight: bold;
}

.alert-error {
    background: rgba(239, 68, 68, 0.2);
    border: 1px solid rgba(239, 68, 68, 0.4);
    color: #FCA5A5;
}

@media (max-width: 900px) {
    body {
        padding: 40px 0;
        align-items: flex-start;
    }
    .dashboard-layout {
        flex-direction: column;
        text-align: center;
        padding: 0 20px;
    }
    .project-showcase h1 {
        font-size: 2.6rem;
    }
    .register-showcase {
        width: 100%;
        justify-content: center;
    }
}
</style>
</head>
<body>

<div class="dashboard-layout">

    <section class="project-showcase">
        <div class="logo-brand">🎒 Backpackr<span>.</span></div>
        <h1>Explore Smarter,<br>Spend <span>Better</span></h1>
        <p>A data-driven Web Application engineered to help budget-conscious travelers uncover off-beat locations, secure smart housing, and trace dynamic local itineraries.</p>
    </section>

    <section class="register-showcase">
        <div class="container">
            <h2>Create Account</h2>
            <p class="form-subtitle">Register to begin mapping your journey</p>

            <%-- Action points directly to lowercase /register mapped servlet --%>
            <form action="register" method="post">
                <% if (request.getAttribute("error") != null) { %>
                    <div class="alert alert-error">
                        <%= HtmlUtils.esc(String.valueOf(request.getAttribute("error"))) %>
                    </div>
                <% } %>

                <input type="text"
                       name="name"
                       placeholder="Full Name"
                       required>

                <input type="email"
                       name="email"
                       placeholder="Email Address"
                       required>
                       
                <input type="text"
                       name="mobileNumber"
                       placeholder="Mobile Number"
                       maxlength="10"
                       required>       

                <input type="password"
                       name="password"
                       placeholder="Password"
                       required>

                <button type="submit">
                    Register
                </button>
                
                <div style="text-align:center; margin-top:15px; font-size: 0.9rem; color: #94A3B8;">
                     Already have an account? 
                     <a href="login.jsp"
                        style="color:#22C55E; text-decoration:none; font-weight: bold;">
                        Login
                     </a>
                </div>
            </form>
        </div>
    </section>

</div>

</body>
</html>
