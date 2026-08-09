// Copy-to-clipboard for the curl one-liner, the sha256 digest, and every code
// block in an article. Progressive enhancement: without JS the text is still
// there and still selectable.
(function () {
  function flash(btn, msg) {
    var original = btn.textContent;
    btn.textContent = msg;
    btn.setAttribute('data-copied', '');
    setTimeout(function () {
      btn.textContent = original;
      btn.removeAttribute('data-copied');
    }, 1400);
  }

  function copy(text, btn) {
    if (!navigator.clipboard) { flash(btn, 'no clipboard'); return; }
    navigator.clipboard.writeText(text).then(
      function () { flash(btn, 'copied'); },
      function () { flash(btn, 'failed'); }
    );
  }

  // Buttons declared in markup, pointing at a target via data-copy.
  document.querySelectorAll('.copy-btn[data-copy]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var target = document.querySelector(btn.getAttribute('data-copy'));
      if (target) copy(target.textContent.trim(), btn);
    });
  });

  // Article code blocks get a button injected. Preview pages already have the
  // curl box, and their line-number gutter would end up in the copied text.
  document.querySelectorAll('.prose .highlighter-rouge').forEach(function (block) {
    var pre = block.querySelector('pre');
    if (!pre) return;

    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'copy-btn code-copy';
    btn.textContent = 'copy';
    btn.addEventListener('click', function () { copy(pre.textContent, btn); });

    block.classList.add('has-copy');
    block.appendChild(btn);
  });
})();
