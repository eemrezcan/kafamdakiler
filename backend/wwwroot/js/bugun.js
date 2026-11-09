// Bugün: the "Ekle" form shows the due-day field only when the target is a project task (a plan line has no due day).
// Without JavaScript the field simply stays visible and is ignored for a plan line.
(function () {
  var form = document.querySelector('[data-kd-ekle]');
  if (!form) return;
  var hedef = form.querySelector('[data-kd-ekle-hedef]');
  var bitis = form.querySelector('[data-kd-ekle-bitis]');
  if (!hedef || !bitis) return;

  function guncelle() {
    var gorev = hedef.value.indexOf('proje:') === 0;
    bitis.hidden = !gorev;
    if (!gorev) bitis.value = '';
  }

  hedef.addEventListener('change', guncelle);
  guncelle();
})();

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
