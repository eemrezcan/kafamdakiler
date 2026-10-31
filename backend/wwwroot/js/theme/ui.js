// Small UI behaviours for theme components (K-0021).
// Show / hide password: a button with data-kd-password-toggle inside .kd-field-control
// switches the input next to it between password and text. A text button swaps its
// label ("Göster" / "Gizle"); an icon button swaps its icon.
(() => {
  document.querySelectorAll("[data-kd-password-toggle]").forEach((button) => {
    const input = button.closest(".kd-field-control")?.querySelector("input");
    const icon = button.querySelector("use");
    if (!input) {
      return;
    }

    button.setAttribute("aria-pressed", "false");
    button.addEventListener("click", () => {
      const show = input.type === "password";
      input.type = show ? "text" : "password";
      button.setAttribute("aria-pressed", String(show));
      button.setAttribute("aria-label", show ? "Şifreyi gizle" : "Şifreyi göster");
      if (icon) {
        icon.setAttribute("href", `/img/icons.svg#${show ? "eye-off" : "eye"}`);
      } else {
        button.textContent = show ? "Gizle" : "Göster";
      }
    });
  });
})();
