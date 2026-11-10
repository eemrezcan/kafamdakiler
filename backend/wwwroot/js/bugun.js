// Bugün: the calendar button opens the date picker, and picking a date goes to that day.
(function () {
  var girdi = document.querySelector('[data-kd-tarih]');
  var dugme = document.querySelector('[data-kd-tarih-ac]');
  if (!girdi || !dugme) return;

  dugme.addEventListener('click', function () {
    if (typeof girdi.showPicker === 'function') {
      try { girdi.showPicker(); return; } catch (e) { /* falls through to focus */ }
    }
    girdi.focus();
    girdi.click();
  });
  girdi.addEventListener('change', function () {
    if (girdi.value && girdi.form) girdi.form.submit();
  });
})();

// Bugün: the briefing is open on a wide screen and folded on a phone (one summary line).
(function () {
  var brifing = document.querySelector('[data-kd-brifing]');
  if (brifing && window.matchMedia('(min-width: 992px)').matches) brifing.open = true;
})();
