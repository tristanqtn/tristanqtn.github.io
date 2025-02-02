// xss.js
(function () {
  alert("XSS Triggered!");
  // Exfiltration possible
  console.log("ici");
})();
