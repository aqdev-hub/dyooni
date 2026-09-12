// Dyooni official pages — shared, minimal, dependency-free.
// Handles: mobile nav toggle, nav scroll shadow, reveal-on-scroll animations, FAQ accordion.
// No analytics, no trackers, no third-party scripts.
document.addEventListener('DOMContentLoaded', function () {
  // Mobile nav toggle
  var ham = document.getElementById('ham');
  var nl = document.getElementById('navLinks');
  if (ham && nl) {
    ham.addEventListener('click', function () {
      nl.classList.toggle('open');
    });
    nl.querySelectorAll('a').forEach(function (a) {
      a.addEventListener('click', function () { nl.classList.remove('open'); });
    });
  }

  // Nav background/shadow once the page scrolls
  var nav = document.querySelector('nav.site-nav');
  if (nav) {
    var onScroll = function () {
      if (window.scrollY > 8) nav.classList.add('scrolled');
      else nav.classList.remove('scrolled');
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  // Reveal-on-scroll: any element with .reveal or .reveal-stagger gets .in once visible
  var revealTargets = document.querySelectorAll('.reveal, .reveal-stagger');
  if (revealTargets.length && 'IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('in');
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
    revealTargets.forEach(function (el) { io.observe(el); });
  } else {
    revealTargets.forEach(function (el) { el.classList.add('in'); });
  }

  // FAQ accordion
  document.querySelectorAll('.faq-item').forEach(function (item) {
    var q = item.querySelector('.faq-q');
    var a = item.querySelector('.faq-a');
    if (!q || !a) return;
    q.addEventListener('click', function () {
      var isOpen = item.classList.contains('open');
      document.querySelectorAll('.faq-item.open').forEach(function (other) {
        if (other !== item) {
          other.classList.remove('open');
          other.querySelector('.faq-a').style.maxHeight = null;
        }
      });
      item.classList.toggle('open', !isOpen);
      a.style.maxHeight = !isOpen ? a.scrollHeight + 'px' : null;
    });
  });
});
