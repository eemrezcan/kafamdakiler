// Please see documentation at https://learn.microsoft.com/aspnet/core/client-side/bundling-and-minification
// for details on configuring this project to bundle and minify static web assets.

// Write your JavaScript code.

// A modal written inside a card is moved to <body> when it opens, so the card's own layout cannot clip or offset it.
document.addEventListener('show.bs.modal', function (e) {
  if (e.target.parentElement !== document.body) document.body.appendChild(e.target);
});
