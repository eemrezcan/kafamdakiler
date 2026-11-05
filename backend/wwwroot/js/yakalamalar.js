// Captures page: the quick capture box at the top of the list.

(function () {
  var form = document.querySelector('[data-kd-composer]');
  if (!form) return;

  var text = form.querySelector('[data-kd-composer-metin]');
  var file = form.querySelector('[data-kd-composer-file]');
  var preview = form.querySelector('[data-kd-composer-preview]');
  var save = form.querySelector('[data-kd-composer-save]');
  var previewUrl = null;

  // Text or photo: the server checks the same rule, this only saves a round trip.
  function update() {
    save.disabled = text.value.trim() === '' && file.files.length === 0;
  }

  // The box grows with the text instead of showing a scroll bar.
  function grow() {
    text.style.height = 'auto';
    text.style.height = text.scrollHeight + 'px';
  }

  function showPreview() {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    previewUrl = file.files.length ? URL.createObjectURL(file.files[0]) : null;
    preview.hidden = !previewUrl;
    if (previewUrl) preview.querySelector('img').src = previewUrl;
    update();
  }

  text.addEventListener('input', function () { grow(); update(); });
  file.addEventListener('change', showPreview);

  form.querySelector('[data-kd-composer-remove]').addEventListener('click', function () {
    file.value = '';
    showPreview();
    text.focus();
  });

  // Ctrl+Enter (Cmd+Enter on a Mac) saves, so the hand stays on the keyboard.
  text.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && (e.ctrlKey || e.metaKey) && !save.disabled) form.requestSubmit(save);
  });

  // The moment of capture is the browser's clock at save time, not when the page was opened.
  form.addEventListener('submit', function () {
    form.querySelector('[data-kd-composer-now]').value = new Date().toISOString();
    save.disabled = true;
  });

  update();
})();
