// Reminder form: the "Kime" field shows only while the type is "Söz".

(function () {
  var tur = document.querySelector('[data-kd-reminder-tur]');
  var kime = document.querySelector('[data-kd-reminder-kime]');
  if (!tur || !kime) return;

  function guncelle() {
    kime.hidden = tur.value !== 'Soz';
  }

  tur.addEventListener('change', guncelle);
  guncelle();
})();
