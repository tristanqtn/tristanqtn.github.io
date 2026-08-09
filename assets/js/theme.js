// Theme toggle. The *initial* theme is applied by an inline blocking script in
// _includes/head.html — this file only handles the click, so a slow network
// can't cause a flash of the wrong palette.
(function () {
  var btn = document.getElementById('theme-toggle');
  if (!btn) return;

  var root = document.documentElement;

  function current() {
    if (root.dataset.theme) return root.dataset.theme;
    return window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
  }

  function label() {
    btn.setAttribute('aria-label', 'Switch to the ' +
      (current() === 'dark' ? 'light' : 'dark') + ' theme');
  }

  label();

  btn.addEventListener('click', function () {
    var next = current() === 'dark' ? 'light' : 'dark';
    root.dataset.theme = next;
    try { localStorage.setItem('theme', next); } catch (e) { /* storage off */ }
    label();
  });
})();
