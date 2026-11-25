// Please see documentation at https://learn.microsoft.com/aspnet/core/client-side/bundling-and-minification
// for details on configuring this project to bundle and minify static web assets.

// Write your JavaScript code.

// A modal written inside a card is moved to <body> when it opens, so the card's own layout cannot clip or offset it.
// The habit color (--kd-hue) comes from the card, so it is written on the modal before it leaves the card.
document.addEventListener('show.bs.modal', function (e) {
  var modal = e.target;
  if (modal.parentElement === document.body) return;
  var hue = getComputedStyle(modal).getPropertyValue('--kd-hue').trim();
  if (hue) modal.style.setProperty('--kd-hue', hue);
  document.body.appendChild(modal);
});
