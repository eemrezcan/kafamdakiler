// Reminder form: the "Kime" field shows only while the type is "Söz"; the interval and count show only while "Israrlı" is on.

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

(function () {
  var tekrar = document.querySelector('[data-kd-reminder-tekrar]');
  var not = document.querySelector('[data-kd-reminder-ay-notu]');
  if (!tekrar || !not) return;

  function guncelle() {
    not.hidden = tekrar.value !== 'Aylik';
  }

  tekrar.addEventListener('change', guncelle);
  guncelle();
})();

(function () {
  var israrli = document.querySelector('[data-kd-reminder-israrli]');
  var ayar = document.querySelector('[data-kd-reminder-israr-ayar]');
  if (!israrli || !ayar) return;

  function guncelle() {
    ayar.hidden = !israrli.checked;
  }

  israrli.addEventListener('change', guncelle);
  guncelle();
})();
