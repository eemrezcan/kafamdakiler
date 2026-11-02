// Habit pages: show or hide form sections by the chosen option, and draw the charts.

(function () {
  // <div data-kd-when="Input.Siklik=BelirliGunler"> is shown only while that field has that value.
  // Hidden sections are also disabled, so their fields are not posted.
  function valueOf(name) {
    var field = document.querySelector(
      'input[name="' + name + '"]:checked, input[type="hidden"][name="' + name + '"], select[name="' + name + '"]');
    return field ? field.value : '';
  }

  function apply() {
    document.querySelectorAll('[data-kd-when]').forEach(function (section) {
      var rule = section.getAttribute('data-kd-when').split('=');
      var show = valueOf(rule[0]) === rule[1];
      section.hidden = !show;
      section.querySelectorAll('input, select, textarea').forEach(function (field) {
        field.disabled = !show;
      });
    });
  }

  document.addEventListener('change', apply);
  apply();
})();

// Charts: window.kdCharts.draw(canvasId, config) builds the chart with the theme colors
// and rebuilds it when the light/dark mode changes.
window.kdCharts = (function () {
  var charts = [];

  function css(name, el) {
    return getComputedStyle(el || document.documentElement).getPropertyValue(name).trim();
  }

  // hue: the habit color of the panel around the canvas (kd-c-*), violet when there is none.
  function theme(canvas) {
    var hue = css('--kd-hue', canvas) || css('--kd-violet');
    return { text: css('--kd-text-muted'), line: css('--kd-line'), accent: css('--kd-violet'), pink: css('--kd-pink'),
             hue: hue, hueSoft: hue.length === 7 ? hue + '99' : hue };
  }

  function draw(canvasId, build) {
    var canvas = document.getElementById(canvasId);
    if (!canvas || typeof Chart === 'undefined') return;
    var entry = { canvas: canvas, build: build, chart: null };
    charts.push(entry);
    render(entry);
  }

  function render(entry) {
    if (entry.chart) entry.chart.destroy();
    var colors = theme(entry.canvas);
    var config = entry.build(colors);
    config.options = config.options || {};
    config.options.maintainAspectRatio = false;
    config.options.color = colors.text;
    entry.chart = new Chart(entry.canvas, config);
  }

  new MutationObserver(function () { charts.forEach(render); })
    .observe(document.documentElement, { attributes: true, attributeFilter: ['data-bs-theme'] });

  return { draw: draw };
})();
