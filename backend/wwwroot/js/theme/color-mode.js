// Light / dark / system color mode on top of Bootstrap 5.3 (K-0022).
// Loaded synchronously in <head> so the theme is set before the first paint.
// The default is "auto" (follow the device); the choice lives in the settings drawer.
(() => {
  const storageKey = "kd-theme";
  const modes = ["auto", "light", "dark"];
  const media = window.matchMedia("(prefers-color-scheme: dark)");

  const getStored = () => {
    try {
      return localStorage.getItem(storageKey);
    } catch {
      return null;
    }
  };

  const setStored = (value) => {
    try {
      if (value === "auto") {
        localStorage.removeItem(storageKey);
      } else {
        localStorage.setItem(storageKey, value);
      }
    } catch {
      // Storage can be blocked (private mode); the choice then lasts for this page only.
    }
  };

  const getPreferred = () => {
    const stored = getStored();
    return modes.includes(stored) ? stored : "auto";
  };

  const resolve = (mode) => (mode === "auto" ? (media.matches ? "dark" : "light") : mode);

  const apply = (mode) => {
    document.documentElement.setAttribute("data-bs-theme", resolve(mode));
  };

  const showActive = (mode) => {
    document.querySelectorAll("input[data-kd-theme-value]").forEach((input) => {
      input.checked = input.value === mode;
    });
    document.querySelectorAll("[data-kd-theme-resolved]").forEach((note) => {
      note.textContent = `Şu an ${resolve("auto") === "dark" ? "koyu" : "açık"}`;
    });
  };

  apply(getPreferred());

  media.addEventListener("change", () => {
    if (getPreferred() === "auto") {
      apply("auto");
    }
    showActive(getPreferred());
  });

  window.addEventListener("DOMContentLoaded", () => {
    showActive(getPreferred());

    document.querySelectorAll("input[data-kd-theme-value]").forEach((input) => {
      input.addEventListener("change", () => {
        if (!input.checked) {
          return;
        }
        setStored(input.value);
        apply(input.value);
        showActive(input.value);
      });
    });
  });
})();
