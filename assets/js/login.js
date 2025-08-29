// --- login.js ---
document.addEventListener("DOMContentLoaded", () => {
    const loginForm = document.getElementById("login-form");
    const registerForm = document.getElementById("register-form");
  
    // Utility to display errors in a <div class="error-messages"></div>
    function displayErrors(container, errors) {
      container.innerHTML = ""; // clear previous errors
      Object.entries(errors).forEach(([field, messages]) => {
        const msgArray = Array.isArray(messages) ? messages : [messages];
        msgArray.forEach(msg => {
          const div = document.createElement("div");
          div.classList.add("error-message");
          div.textContent = `${field}: ${msg}`;
          container.appendChild(div);
        });
      });
    }
  
    // ------------------ Login ------------------
    if (loginForm) {
      loginForm.addEventListener("submit", async (e) => {
        e.preventDefault();
        const email = loginForm.querySelector("input[name='email']").value;
        const password = loginForm.querySelector("input[name='password']").value;
        const errorContainer = loginForm.querySelector(".error-messages");
  
        try {
          const res = await fetch("/api/game/login", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email, password })
          });
  
          const data = await res.json();
  
          if (res.ok && data.status === "ok") {
            // Save token and redirect or update UI
            localStorage.setItem("authToken", data.token);
            window.location.href = "/dashboard"; // example
          } else {
            displayErrors(errorContainer, data.errors || { login: "Unknown error" });
          }
        } catch (err) {
          displayErrors(errorContainer, { network: "Network error" });
        }
      });
    }
  
    // ------------------ Register ------------------
    if (registerForm) {
      registerForm.addEventListener("submit", async (e) => {
        e.preventDefault();
        const email = registerForm.querySelector("input[name='email']").value;
        const password = registerForm.querySelector("input[name='password']").value;
        const name = registerForm.querySelector("input[name='name']").value;
        const errorContainer = registerForm.querySelector(".error-messages");
  
        try {
          const res = await fetch("/api/game/register", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email, password, name })
          });
  
          const data = await res.json();
  
          if (res.ok && data.status === "ok") {
            // Save token and redirect or update UI
            localStorage.setItem("authToken", data.token);
            window.location.href = "/dashboard"; // example
          } else {
            displayErrors(errorContainer, data.errors || { register: "Unknown error" });
          }
        } catch (err) {
          displayErrors(errorContainer, { network: "Network error" });
        }
      });
    }
  });
  