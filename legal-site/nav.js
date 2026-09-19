// The header menu on phones. Four icon links did not fit next to the
// wordmark, so below the CSS breakpoint they collapse behind a Menu button
// and open as a panel where each link keeps its icon and its name.
//
// The panel is only wired up when this runs: without JavaScript the stylesheet
// leaves the plain row of links in place, so the pages stay navigable.
(function () {
  var header = document.querySelector('.site-header');
  if (!header) return;

  var button = header.querySelector('.nav-toggle');
  var menu = header.querySelector('.menu');
  if (!button || !menu) return;

  function setOpen(open) {
    header.setAttribute('data-open', open ? 'true' : 'false');
    button.setAttribute('aria-expanded', open ? 'true' : 'false');
  }

  setOpen(false);

  button.addEventListener('click', function (event) {
    event.stopPropagation();
    setOpen(button.getAttribute('aria-expanded') !== 'true');
  });

  // Picking a link, tapping the page, or Escape all close it again.
  menu.addEventListener('click', function (event) {
    if (event.target.closest('a')) setOpen(false);
  });

  document.addEventListener('click', function (event) {
    if (!header.contains(event.target)) setOpen(false);
  });

  document.addEventListener('keydown', function (event) {
    if (event.key !== 'Escape') return;
    if (button.getAttribute('aria-expanded') !== 'true') return;
    setOpen(false);
    button.focus();
  });

  // Widening past the breakpoint shows the full row again; leaving the panel
  // flagged open would then mean a stray aria-expanded on a hidden button.
  var wide = window.matchMedia('(min-width: 901px)');
  var onWidth = function (event) {
    if (event.matches) setOpen(false);
  };
  if (wide.addEventListener) wide.addEventListener('change', onWidth);
  else if (wide.addListener) wide.addListener(onWidth);
})();
