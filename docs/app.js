/* Interactive behaviour for the Azure Trusted Signing guide.
   Vanilla JS, no dependencies, no build step. */
(function () {
  'use strict';

  var $ = function (sel, ctx) { return (ctx || document).querySelector(sel); };
  var $$ = function (sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); };

  function el(tag, attrs, children) {
    var node = document.createElement(tag);
    if (attrs) {
      Object.keys(attrs).forEach(function (k) {
        if (k === 'class') node.className = attrs[k];
        else if (k === 'text') node.textContent = attrs[k];
        else node.setAttribute(k, attrs[k]);
      });
    }
    (children || []).forEach(function (c) { node.appendChild(c); });
    return node;
  }

  /* ---------- Smooth-scroll navigation ---------- */
  function initNav() {
    $$('[data-target]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var target = document.getElementById(btn.getAttribute('data-target'));
        if (!target) return;
        var reduceMotion = false;
        try { reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches; } catch (e) { /* ignore */ }
        target.scrollIntoView({ behavior: reduceMotion ? 'auto' : 'smooth', block: 'start' });
        target.focus({ preventScroll: true });
      });
    });
  }

  /* ---------- Theme toggle ---------- */
  function initTheme() {
    var toggle = $('#themeToggle');
    var stored = null;
    try { stored = localStorage.getItem('ats-theme'); } catch (e) { /* ignore */ }
    if (stored) document.documentElement.setAttribute('data-theme', stored);
    toggle.addEventListener('click', function () {
      var current = document.documentElement.getAttribute('data-theme') === 'light' ? 'dark' : 'light';
      document.documentElement.setAttribute('data-theme', current);
      try { localStorage.setItem('ats-theme', current); } catch (e) { /* ignore */ }
    });
  }

  /* ---------- Animated stat counters ---------- */
  function initCounters() {
    var nums = $$('.stat-num');
    var reduceMotion = false;
    try { reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches; } catch (e) { /* ignore */ }
    if (reduceMotion || !('IntersectionObserver' in window)) {
      nums.forEach(function (n) { n.textContent = n.getAttribute('data-count'); });
      return;
    }
    var obs = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        var node = entry.target;
        var target = parseInt(node.getAttribute('data-count'), 10) || 0;
        var start = null;
        function step(ts) {
          if (!start) start = ts;
          var p = Math.min((ts - start) / 900, 1);
          node.textContent = Math.round(p * target);
          if (p < 1) requestAnimationFrame(step);
        }
        requestAnimationFrame(step);
        obs.unobserve(node);
      });
    }, { threshold: 0.4 });
    nums.forEach(function (n) { obs.observe(n); });
  }

  /* ---------- Signing flow explorer ---------- */
  function initFlow() {
    var steps = $$('.flow-step');
    var detail = $('#flowDetail');
    function show(idx) {
      steps.forEach(function (s, i) { s.classList.toggle('is-active', i === idx); });
      var data = FLOW_STEPS[idx];
      detail.innerHTML = '';
      detail.appendChild(el('h3', { text: data.title }));
      detail.appendChild(el('p', { text: data.body }));
    }
    steps.forEach(function (s, i) {
      s.setAttribute('role', 'button');
      s.setAttribute('tabindex', '0');
      s.addEventListener('click', function () { show(i); });
      s.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); show(i); }
      });
    });
    show(0);
  }

  /* ---------- Use-case cards + filtering ---------- */
  function initUseCases() {
    var grid = $('#useCaseGrid');
    USE_CASES.forEach(function (uc) {
      var card = el('article', { class: 'card', 'data-tag': uc.tag }, [
        el('div', { class: 'card-icon', 'aria-hidden': 'true', text: uc.icon }),
        el('h3', { text: uc.title }),
        el('p', { text: uc.body }),
        el('span', { class: 'card-tag', text: uc.tag.replace('-', ' ') })
      ]);
      grid.appendChild(card);
    });
    $$('.chip').forEach(function (chip) {
      chip.addEventListener('click', function () {
        $$('.chip').forEach(function (c) { c.classList.remove('is-on'); });
        chip.classList.add('is-on');
        var f = chip.getAttribute('data-filter');
        $$('.card', grid).forEach(function (card) {
          var show = f === 'all' || card.getAttribute('data-tag') === f;
          card.classList.toggle('is-hidden', !show);
        });
      });
    });
  }

  /* ---------- Integration explorer ---------- */
  function initIntegrations() {
    var list = $('#integrationList');
    var detail = $('#integrationDetail');
    function render(item) {
      detail.innerHTML = '';
      detail.appendChild(el('h3', { text: item.icon + '  ' + item.label }));
      detail.appendChild(el('p', { class: 'integration-summary', text: item.summary }));
      var pre = el('pre', { class: 'code', 'data-lang': item.lang });
      pre.appendChild(el('code', { text: item.code }));
      detail.appendChild(pre);
      if (item.note) detail.appendChild(el('p', { class: 'integration-note', text: item.note }));
    }
    INTEGRATIONS.forEach(function (item, i) {
      var tabId = 'integration-tab-' + item.id;
      var li = el('li', {
        class: 'integration-item',
        role: 'tab',
        id: tabId,
        tabindex: i === 0 ? '0' : '-1',
        'aria-controls': 'integrationDetail',
        'aria-selected': i === 0 ? 'true' : 'false'
      });
      li.appendChild(el('span', { class: 'ii-icon', 'aria-hidden': 'true', text: item.icon }));
      li.appendChild(el('span', { text: item.label }));
      function select() {
        $$('.integration-item', list).forEach(function (x) {
          x.classList.remove('is-on');
          x.setAttribute('aria-selected', 'false');
          x.setAttribute('tabindex', '-1');
        });
        li.classList.add('is-on');
        li.setAttribute('aria-selected', 'true');
        li.setAttribute('tabindex', '0');
        detail.setAttribute('aria-labelledby', tabId);
        li.focus({ preventScroll: true });
        render(item);
      }
      li.addEventListener('click', select);
      li.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); select(); }
      });
      if (i === 0) { li.classList.add('is-on'); detail.setAttribute('aria-labelledby', tabId); }
      list.appendChild(li);
    });
    render(INTEGRATIONS[0]);
  }

  /* ---------- Limitations lists ---------- */
  function initLimitations() {
    var good = $('#fitGood');
    var bad = $('#fitBad');
    FIT_GOOD.forEach(function (t) { good.appendChild(el('li', { text: t })); });
    FIT_BAD.forEach(function (t) { bad.appendChild(el('li', { text: t })); });
  }

  /* ---------- Decision quiz ---------- */
  function initQuiz() {
    var qEl = $('#quizQuestion');
    var optEl = $('#quizOptions');
    var barEl = $('#quizBar');
    var restart = $('#quizRestart');
    var index = 0;
    var scores = {};

    function renderQuestion() {
      var item = QUIZ[index];
      barEl.style.width = (index / QUIZ.length * 100) + '%';
      qEl.textContent = (index + 1) + '. ' + item.q;
      optEl.innerHTML = '';
      item.options.forEach(function (opt) {
        var b = el('button', { class: 'quiz-option', type: 'button', text: opt.t });
        b.addEventListener('click', function () {
          scores[opt.score] = (scores[opt.score] || 0) + 1;
          index++;
          if (index < QUIZ.length) renderQuestion();
          else renderResult();
        });
        optEl.appendChild(b);
      });
      restart.hidden = index === 0;
    }

    function pickResult() {
      // Any explicit "no/test" answer takes precedence over a generic yes.
      var priority = ['no-tls', 'no-doc', 'no-key', 'test', 'yes'];
      for (var i = 0; i < priority.length; i++) {
        if (scores[priority[i]]) return priority[i];
      }
      return 'yes';
    }

    function renderResult() {
      barEl.style.width = '100%';
      var key = pickResult();
      var r = QUIZ_RESULTS[key];
      qEl.textContent = '';
      optEl.innerHTML = '';
      var card = el('div', { class: 'quiz-result' }, [
        el('div', { class: 'quiz-result-icon', 'aria-hidden': 'true', text: r.icon }),
        el('h3', { text: r.title }),
        el('p', { text: r.body })
      ]);
      optEl.appendChild(card);
      restart.hidden = false;
    }

    restart.addEventListener('click', function () {
      index = 0; scores = {}; renderQuestion();
    });
    renderQuestion();
  }

  /* ---------- Resources ---------- */
  function initResources() {
    var list = $('#resourceList');
    RESOURCES.forEach(function (r) {
      var a = el('a', { href: r.u, target: '_blank', rel: 'noopener', text: r.t });
      list.appendChild(el('li', null, [a]));
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    initNav();
    initTheme();
    initCounters();
    initFlow();
    initUseCases();
    initIntegrations();
    initLimitations();
    initQuiz();
    initResources();
  });
})();
