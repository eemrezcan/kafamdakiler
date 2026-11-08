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
