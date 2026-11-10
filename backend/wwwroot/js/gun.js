// Bugün and Takvim: the reminder fields of a form. The weekly days show only while the repeat is "Her hafta", and the fields of the
// new-item form show only while "Hatırlatıcı kur" is ticked. Without JavaScript everything stays visible and the server ignores what
// does not apply (days for another repeat, the fields of an unticked reminder).
(function () {
  function gunleriGuncelle(kutu) {
    var tekrar = kutu.querySelector('[data-kd-hat-tekrar]');
    var gunler = kutu.querySelector('[data-kd-hat-gunler]');
    if (!tekrar || !gunler) return;
    gunler.hidden = tekrar.value !== 'haftalik';
  }

  document.querySelectorAll('[data-kd-hat-alanlar]').forEach(function (kutu) {
    var tekrar = kutu.querySelector('[data-kd-hat-tekrar]');
    if (tekrar) tekrar.addEventListener('change', function () { gunleriGuncelle(kutu); });
    gunleriGuncelle(kutu);
  });

  document.querySelectorAll('[data-kd-yeni-oge]').forEach(function (form) {
    var ac = form.querySelector('[data-kd-hat-ac]');
    var kutu = form.querySelector('[data-kd-hat-kutu]');
    if (!ac || !kutu) return;
    function guncelle() { kutu.hidden = !ac.checked; }
    ac.addEventListener('change', guncelle);
    guncelle();
  });
})();
