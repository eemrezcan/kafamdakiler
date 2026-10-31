// Neuron background scene (K-0022).
// Any <canvas class="kd-synapse"> becomes a microscope view of living neurons:
// fluorescent cells on the dark theme, stained tissue on the light theme.
// Each neuron has a soma, branching dendrites and an axon that reaches toward
// another neuron. Action potentials run down the axon, neurotransmitter
// vesicles cross the synaptic cleft and the receiving cell lights up and may
// fire in turn. Three depth layers (blurred far, sharp near) drift slowly and
// shift with the pointer. A click or tap fires the nearest neuron.
// Cells are drawn once into sprites, so each frame is mostly drawImage calls.
// Honors "reduce motion" (one still frame) and pauses while the tab is hidden.
(() => {
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  const supportsFilter = "filter" in CanvasRenderingContext2D.prototype;
  const TAU = Math.PI * 2;

  const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
  const random = (min, max) => min + Math.random() * (max - min);
  const mix = (a, b, t) => a.map((channel, i) => Math.round(channel + (b[i] - channel) * t));
  const rgba = (c, alpha) => `rgba(${c[0]}, ${c[1]}, ${c[2]}, ${alpha})`;

  const parseRgb = (text, fallback) => {
    const parts = text.split(",").map((part) => Number.parseFloat(part));
    return parts.length === 3 && parts.every(Number.isFinite) ? parts : fallback;
  };

  const LAYERS = [
    { density: 36000, min: 10, max: 32, scale: 0.6, blur: 2.6, alpha: 0.5, parallax: 10, drift: 8, signals: false },
    { density: 60000, min: 7, max: 20, scale: 0.85, blur: 0.9, alpha: 0.75, parallax: 22, drift: 12, signals: true },
    { density: 120000, min: 4, max: 11, scale: 1.1, blur: 0, alpha: 1, parallax: 40, drift: 16, signals: true },
  ];

  // ---------- Morphology ----------

  function growBranch(out, x, y, angle, length, width, depth, step) {
    const steps = Math.max(3, Math.round(length / step));
    const points = [[x, y, width]];
    let a = angle;
    for (let i = 1; i <= steps; i++) {
      a += random(-0.3, 0.3);
      x += Math.cos(a) * step;
      y += Math.sin(a) * step;
      const w = Math.max(0.35, width * (1 - (i / steps) * 0.85));
      points.push([x, y, w]);
      if (depth < 3 && i > 2 && i < steps - 1 && Math.random() < 0.17) {
        const side = Math.random() < 0.5 ? -1 : 1;
        growBranch(out, x, y, a + side * random(0.35, 0.85), length * random(0.4, 0.65), w * 0.85, depth + 1, step);
      }
    }
    out.push(points);
  }

  function makeNeuron(x, y, layer) {
    const s = layer.scale;
    const neuron = {
      x, y, layer,
      somaR: random(5.5, 9) * s,
      somaShape: Array.from({ length: 9 }, () => random(0.82, 1.18)),
      dendrites: [],
      axon: null,
      terminals: [],
      target: null,
      flash: 0,
      busy: false,
    };
    const count = Math.round(random(4, 7));
    const base = Math.random() * TAU;
    for (let i = 0; i < count; i++) {
      const angle = base + (i * TAU) / count + random(-0.4, 0.4);
      const startX = x + Math.cos(angle) * neuron.somaR * 0.8;
      const startY = y + Math.sin(angle) * neuron.somaR * 0.8;
      growBranch(neuron.dendrites, startX, startY, angle, random(45, 90) * s, random(2.2, 3.3) * s, 0, 5 * s);
    }
    return neuron;
  }

  function cubic(p0, p1, p2, p3, t) {
    const u = 1 - t;
    return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3;
  }

  function buildAxon(neuron, target) {
    const s = neuron.layer.scale;
    let dir;
    let end;
    if (target) {
      dir = Math.atan2(target.y - neuron.y, target.x - neuron.x);
      const stop = target.somaR + random(20, 34) * target.layer.scale;
      end = [target.x - Math.cos(dir) * stop, target.y - Math.sin(dir) * stop];
    } else {
      dir = Math.random() * TAU;
      const length = random(150, 260) * s;
      end = [neuron.x + Math.cos(dir) * length, neuron.y + Math.sin(dir) * length];
    }

    const start = [neuron.x + Math.cos(dir) * neuron.somaR, neuron.y + Math.sin(dir) * neuron.somaR];
    const length = Math.hypot(end[0] - start[0], end[1] - start[1]);
    const nx = -Math.sin(dir);
    const ny = Math.cos(dir);
    const bend1 = random(-0.28, 0.28) * length;
    const bend2 = random(-0.28, 0.28) * length;
    const c1 = [start[0] + Math.cos(dir) * length * 0.33 + nx * bend1, start[1] + Math.sin(dir) * length * 0.33 + ny * bend1];
    const c2 = [start[0] + Math.cos(dir) * length * 0.66 + nx * bend2, start[1] + Math.sin(dir) * length * 0.66 + ny * bend2];

    const count = Math.max(14, Math.round(length / 6));
    const points = [];
    const lengths = [0];
    for (let i = 0; i <= count; i++) {
      const t = i / count;
      points.push([cubic(start[0], c1[0], c2[0], end[0], t), cubic(start[1], c1[1], c2[1], end[1], t)]);
      if (i > 0) {
        const [ax, ay] = points[i - 1];
        lengths.push(lengths[i - 1] + Math.hypot(points[i][0] - ax, points[i][1] - ay));
      }
    }
    neuron.axon = { points, lengths, total: lengths[lengths.length - 1], dir };

    // Axon terminals fan out toward the target and end in small boutons.
    const twigs = Math.round(random(3, 5));
    for (let i = 0; i < twigs; i++) {
      const a = dir + random(-0.95, 0.95);
      const twigLength = random(8, 17) * s;
      const mid = [end[0] + Math.cos(a + random(-0.4, 0.4)) * twigLength * 0.5, end[1] + Math.sin(a + random(-0.4, 0.4)) * twigLength * 0.5];
      const tip = [end[0] + Math.cos(a) * twigLength, end[1] + Math.sin(a) * twigLength];
      neuron.terminals.push({ points: [end, mid, tip], tip, angle: a });
    }
    neuron.target = target;
  }

  function pointOnAxon(axon, distance) {
    const { points, lengths } = axon;
    let i = 1;
    while (i < lengths.length - 1 && lengths[i] < distance) {
      i++;
    }
    const span = lengths[i] - lengths[i - 1] || 1;
    const t = clamp((distance - lengths[i - 1]) / span, 0, 1);
    return [points[i - 1][0] + (points[i][0] - points[i - 1][0]) * t, points[i - 1][1] + (points[i][1] - points[i - 1][1]) * t];
  }

  // ---------- Sprites ----------

  function makeCanvas(width, height) {
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.ceil(width));
    canvas.height = Math.max(1, Math.ceil(height));
    return canvas;
  }

  function drawCell(g, neuron, color, widthFactor) {
    g.strokeStyle = color;
    g.fillStyle = color;
    g.lineCap = "round";
    g.lineJoin = "round";

    for (const branch of neuron.dendrites) {
      for (let i = 1; i < branch.length; i++) {
        g.lineWidth = branch[i][2] * widthFactor;
        g.beginPath();
        g.moveTo(branch[i - 1][0], branch[i - 1][1]);
        g.lineTo(branch[i][0], branch[i][1]);
        g.stroke();
      }
    }

    const s = neuron.layer.scale;
    const axonPoints = neuron.axon.points;
    for (let i = 1; i < axonPoints.length; i++) {
      g.lineWidth = (1.5 - (i / axonPoints.length) * 0.7) * s * widthFactor;
      g.beginPath();
      g.moveTo(axonPoints[i - 1][0], axonPoints[i - 1][1]);
      g.lineTo(axonPoints[i][0], axonPoints[i][1]);
      g.stroke();
    }

    g.lineWidth = 0.8 * s * widthFactor;
    for (const terminal of neuron.terminals) {
      const [a, b, c] = terminal.points;
      g.beginPath();
      g.moveTo(a[0], a[1]);
      g.quadraticCurveTo(b[0], b[1], c[0], c[1]);
      g.stroke();
      g.beginPath();
      g.arc(c[0], c[1], 1.9 * s * Math.max(widthFactor, 0.8), 0, TAU);
      g.fill();
    }

    // Soma: an irregular, smooth blob.
    const shape = neuron.somaShape;
    g.beginPath();
    for (let i = 0; i <= shape.length; i++) {
      const k = i % shape.length;
      const next = (i + 1) % shape.length;
      const a = (k / shape.length) * TAU;
      const an = (next / shape.length) * TAU;
      const r = neuron.somaR * shape[k] * Math.max(widthFactor, 0.7);
      const rn = neuron.somaR * shape[next] * Math.max(widthFactor, 0.7);
      const px = neuron.x + Math.cos(a) * r;
      const py = neuron.y + Math.sin(a) * r;
      const mx = (px + neuron.x + Math.cos(an) * rn) / 2;
      const my = (py + neuron.y + Math.sin(an) * rn) / 2;
      if (i === 0) {
        g.moveTo(mx, my);
      } else {
        g.quadraticCurveTo(px, py, mx, my);
      }
    }
    g.closePath();
    g.fill();
  }

  function renderNeuron(neuron, palette, ratio) {
    const layer = neuron.layer;
    let minX = neuron.x;
    let maxX = neuron.x;
    let minY = neuron.y;
    let maxY = neuron.y;
    const extend = ([px, py]) => {
      minX = Math.min(minX, px);
      maxX = Math.max(maxX, px);
      minY = Math.min(minY, py);
      maxY = Math.max(maxY, py);
    };
    neuron.dendrites.forEach((branch) => branch.forEach(extend));
    neuron.axon.points.forEach(extend);
    neuron.terminals.forEach((terminal) => terminal.points.forEach(extend));

    const pad = 18 + layer.blur * 4;
    const width = maxX - minX + pad * 2;
    const height = maxY - minY + pad * 2;
    const setup = (g) => {
      g.setTransform(ratio, 0, 0, ratio, 0, 0);
      g.translate(pad - minX, pad - minY);
    };

    // Crisp cell.
    const crisp = makeCanvas(width * ratio, height * ratio);
    const cg = crisp.getContext("2d");
    setup(cg);
    drawCell(cg, neuron, rgba(palette.membrane, palette.membraneAlpha), 1);

    // Bright core along the thicker parts, and a darker nucleus.
    cg.globalCompositeOperation = "source-atop";
    drawCell(cg, neuron, rgba(palette.core, palette.coreAlpha), 0.45);
    cg.globalCompositeOperation = "destination-out";
    cg.fillStyle = "rgba(0, 0, 0, 0.5)";
    cg.beginPath();
    cg.ellipse(neuron.x, neuron.y, neuron.somaR * 0.42, neuron.somaR * 0.36, random(0, TAU), 0, TAU);
    cg.fill();
    cg.globalCompositeOperation = "source-over";

    const sprite = makeCanvas(width * ratio, height * ratio);
    const sg = sprite.getContext("2d");

    // Soft glow: a blurred, tinted copy under the crisp cell.
    if (supportsFilter && palette.glowAlpha > 0) {
      const glow = makeCanvas(width * ratio, height * ratio);
      const gg = glow.getContext("2d");
      gg.filter = `blur(${7 * ratio * layer.scale}px)`;
      gg.drawImage(crisp, 0, 0);
      gg.filter = "none";
      gg.globalCompositeOperation = "source-in";
      gg.fillStyle = rgba(palette.glow, palette.glowAlpha);
      gg.fillRect(0, 0, glow.width, glow.height);
      sg.drawImage(glow, 0, 0);
      sg.drawImage(glow, 0, 0);
    }

    if (supportsFilter && layer.blur > 0) {
      sg.filter = `blur(${layer.blur * ratio}px)`;
    }
    sg.drawImage(crisp, 0, 0);
    sg.filter = "none";

    neuron.sprite = sprite;
    neuron.spriteX = minX - pad;
    neuron.spriteY = minY - pad;
    neuron.spriteW = width;
    neuron.spriteH = height;
  }

  function renderSpark(color) {
    const size = 64;
    const spark = makeCanvas(size, size);
    const g = spark.getContext("2d");
    const gradient = g.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
    gradient.addColorStop(0, "rgba(255, 255, 255, 1)");
    gradient.addColorStop(0.18, rgba(color, 0.95));
    gradient.addColorStop(0.45, rgba(color, 0.3));
    gradient.addColorStop(1, rgba(color, 0));
    g.fillStyle = gradient;
    g.fillRect(0, 0, size, size);
    return spark;
  }

  // ---------- Scene ----------

  class NeuronScene {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext("2d");
      this.layers = [];
      this.signals = [];
      this.pointer = { x: 0, y: 0, tx: 0, ty: 0 };
      this.time = 0;
      this.nextFireIn = 600;
      this.frame = 0;

      this.readPalette();
      this.build();
      this.bindEvents();
      this.start();
    }

    readPalette() {
      const style = getComputedStyle(document.documentElement);
      const dark = document.documentElement.getAttribute("data-bs-theme") === "dark";
      const violet = parseRgb(style.getPropertyValue("--kd-violet-rgb"), [139, 92, 246]);
      const pink = parseRgb(style.getPropertyValue("--kd-pink-rgb"), [236, 72, 153]);
      this.palette = dark
        ? {
          // Fluorescence: glowing cells on black, added light on light.
          blend: "lighter", membrane: violet, membraneAlpha: 0.75, core: [245, 240, 255], coreAlpha: 0.55,
          glow: pink, glowAlpha: 0.32, signal: [violet, pink], vesicle: [255, 220, 240],
          vignette: [0, 0, 0], vignetteAlpha: 0.78,
        }
        : {
          // Stained tissue: violet dye on a pale slide.
          blend: "source-over", membrane: [84, 56, 146], membraneAlpha: 0.4, core: [52, 32, 98], coreAlpha: 0.42,
          glow: [150, 120, 200], glowAlpha: 0.12, signal: [[90, 62, 158], [184, 54, 111]], vesicle: [184, 54, 111],
          vignette: [70, 52, 40], vignetteAlpha: 0.14,
        };
      this.sparks = [renderSpark(this.palette.signal[0]), renderSpark(this.palette.signal[1])];
      this.vignette = null;
    }

    // Round field of view: the edges fall off like the rim of a microscope eyepiece.
    getVignette() {
      if (!this.vignette) {
        const { width, height, palette } = this;
        const radius = Math.hypot(width, height) / 2;
        // On a phone the card covers the bright center, so the rim starts later and stays lighter.
        const inner = 0.35 + (1 - this.fit) * 0.5;
        const alpha = palette.vignetteAlpha * this.fit;
        const gradient = this.ctx.createRadialGradient(width / 2, height / 2, radius * inner, width / 2, height / 2, radius);
        gradient.addColorStop(0, rgba(palette.vignette, 0));
        gradient.addColorStop(0.7, rgba(palette.vignette, alpha * 0.45));
        gradient.addColorStop(1, rgba(palette.vignette, alpha));
        this.vignette = gradient;
      }
      return this.vignette;
    }

    build() {
      const width = this.canvas.clientWidth;
      const height = this.canvas.clientHeight;
      const ratio = Math.min(window.devicePixelRatio || 1, 2);
      this.width = width;
      this.height = height;
      this.ratio = ratio;
      this.canvas.width = Math.round(width * ratio);
      this.canvas.height = Math.round(height * ratio);
      this.ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
      this.signals = [];
      this.vignette = null;

      // Small screens get smaller, denser cells that stay inside the view;
      // at full size they would be few and mostly hidden behind the card.
      const fit = clamp(Math.min(width, height) / 700, 0.62, 1);
      this.fit = fit;
      const margin = 60 * fit;
      this.layers = LAYERS.map((config, index) => {
        const layer = { ...config, scale: config.scale * fit, index, phase: Math.random() * TAU, ox: 0, oy: 0, neurons: [] };
        const count = clamp(Math.round((width * height) / (config.density * fit * fit)), config.min, config.max);
        const minGap = 70 * layer.scale;
        for (let attempt = 0; attempt < count * 30 && layer.neurons.length < count; attempt++) {
          const x = random(-margin, width + margin);
          const y = random(-margin, height + margin);
          if (layer.neurons.every((n) => Math.hypot(n.x - x, n.y - y) > minGap)) {
            layer.neurons.push(makeNeuron(x, y, layer));
          }
        }

        for (const neuron of layer.neurons) {
          const candidates = layer.neurons
            .filter((other) => other !== neuron)
            .map((other) => ({ other, distance: Math.hypot(other.x - neuron.x, other.y - neuron.y) }))
            .filter(({ distance }) => distance > 100 * layer.scale && distance < 420 * layer.scale)
            .sort((a, b) => a.distance - b.distance)
            .slice(0, 3);
          const choice = candidates.length ? candidates[Math.floor(Math.random() * candidates.length)].other : null;
          buildAxon(neuron, choice);
        }
        return layer;
      });

      this.renderSprites();
      if (!this.running) {
        this.drawStill();
      }
    }

    renderSprites() {
      for (const layer of this.layers) {
        for (const neuron of layer.neurons) {
          renderNeuron(neuron, this.palette, this.ratio);
        }
      }
    }

    bindEvents() {
      let resizeTimer = 0;
      new ResizeObserver(() => {
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(() => {
          if (Math.abs(this.canvas.clientWidth - this.width) > 1 || Math.abs(this.canvas.clientHeight - this.height) > 1) {
            this.build();
          }
        }, 150);
      }).observe(this.canvas);

      new MutationObserver(() => {
        this.readPalette();
        this.renderSprites();
        if (!this.running) {
          this.drawStill();
        }
      }).observe(document.documentElement, { attributes: true, attributeFilter: ["data-bs-theme"] });

      window.addEventListener("pointermove", (event) => {
        this.pointer.tx = (event.clientX / this.width) * 2 - 1;
        this.pointer.ty = (event.clientY / this.height) * 2 - 1;
      }, { passive: true });

      window.addEventListener("pointerdown", (event) => {
        const neuron = this.nearestNeuron(event.clientX, event.clientY);
        if (neuron) {
          this.fire(neuron, 0);
        }
      }, { passive: true });

      document.addEventListener("visibilitychange", () => {
        if (document.hidden) {
          this.stop();
        } else {
          this.start();
        }
      });

      reduceMotion.addEventListener("change", () => {
        this.stop();
        this.start();
      });
    }

    start() {
      if (this.running || document.hidden) {
        return;
      }
      if (reduceMotion.matches) {
        this.drawStill();
        return;
      }
      this.running = true;
      this.lastTime = performance.now();
      this.frame = requestAnimationFrame((time) => this.tick(time));
    }

    stop() {
      this.running = false;
      cancelAnimationFrame(this.frame);
    }

    tick(time) {
      if (!this.running) {
        return;
      }
      const dt = Math.min(time - this.lastTime, 50);
      this.lastTime = time;
      this.update(dt);
      this.draw();
      this.frame = requestAnimationFrame((next) => this.tick(next));
    }

    nearestNeuron(x, y) {
      let best = null;
      let bestDistance = 220;
      for (const layer of this.layers) {
        if (!layer.signals) {
          continue;
        }
        for (const neuron of layer.neurons) {
          const distance = Math.hypot(neuron.x + layer.ox - x, neuron.y + layer.oy - y);
          if (distance < bestDistance) {
            best = neuron;
            bestDistance = distance;
          }
        }
      }
      return best;
    }

    fire(neuron, depth) {
      const limit = this.width < 600 ? 6 : 12;
      if (neuron.busy || this.signals.length >= limit) {
        return;
      }
      neuron.busy = true;
      neuron.flash = Math.max(neuron.flash, 0.8);
      this.signals.push({ neuron, depth, phase: "axon", distance: 0, t: 0, vesicles: [], delivered: false });
    }

    update(dt) {
      this.time += dt;
      const p = this.pointer;
      p.x += (p.tx - p.x) * Math.min(1, dt / 600);
      p.y += (p.ty - p.y) * Math.min(1, dt / 600);

      for (const layer of this.layers) {
        layer.ox = Math.sin(this.time * 0.00011 + layer.phase) * layer.drift - p.x * layer.parallax;
        layer.oy = Math.cos(this.time * 0.00008 + layer.phase) * layer.drift * 0.7 - p.y * layer.parallax * 0.6;
        for (const neuron of layer.neurons) {
          neuron.flash *= Math.exp(-dt / 700);
        }
      }

      this.nextFireIn -= dt;
      if (this.nextFireIn <= 0) {
        this.nextFireIn = random(600, 1400);
        const pool = this.layers.filter((layer) => layer.signals).flatMap((layer) => layer.neurons).filter((n) => !n.busy);
        if (pool.length) {
          this.fire(pool[Math.floor(Math.random() * pool.length)], 0);
        }
      }

      for (const signal of this.signals) {
        const { neuron } = signal;
        const s = neuron.layer.scale;
        if (signal.phase === "axon") {
          signal.distance += dt * 0.32 * s;
          if (signal.distance >= neuron.axon.total) {
            signal.phase = "terminal";
          }
        } else if (signal.phase === "terminal") {
          signal.t += dt / 200;
          if (signal.t >= 1) {
            signal.phase = "cleft";
            signal.t = 0;
            for (const terminal of neuron.terminals) {
              const aim = neuron.target
                ? Math.atan2(neuron.target.y - terminal.tip[1], neuron.target.x - terminal.tip[0])
                : terminal.angle;
              for (let i = 0; i < 5; i++) {
                const a = aim + random(-0.6, 0.6);
                const speed = random(0.018, 0.04) * s;
                signal.vesicles.push({ x: terminal.tip[0], y: terminal.tip[1], vx: Math.cos(a) * speed, vy: Math.sin(a) * speed, life: 0, span: random(450, 800) });
              }
            }
          }
        } else {
          signal.t += dt;
          for (const vesicle of signal.vesicles) {
            vesicle.x += vesicle.vx * dt;
            vesicle.y += vesicle.vy * dt;
            vesicle.life += dt / vesicle.span;
          }
          signal.vesicles = signal.vesicles.filter((vesicle) => vesicle.life < 1);

          if (!signal.delivered && signal.t > 280 && neuron.target) {
            signal.delivered = true;
            const target = neuron.target;
            target.flash = 1;
            if (signal.depth < 6 && Math.random() < 0.72) {
              setTimeout(() => this.fire(target, signal.depth + 1), random(250, 650));
            }
          }
          if (!signal.vesicles.length) {
            signal.done = true;
            neuron.busy = false;
          }
        }
      }
      this.signals = this.signals.filter((signal) => !signal.done);
    }

    drawSpark(x, y, size, alpha, progress) {
      const ctx = this.ctx;
      ctx.globalAlpha = alpha * (1 - progress);
      ctx.drawImage(this.sparks[0], x - size / 2, y - size / 2, size, size);
      ctx.globalAlpha = alpha * progress;
      ctx.drawImage(this.sparks[1], x - size / 2, y - size / 2, size, size);
    }

    draw() {
      const { ctx, palette } = this;
      ctx.globalCompositeOperation = "source-over";
      ctx.globalAlpha = 1;
      ctx.clearRect(0, 0, this.width, this.height);
      ctx.globalCompositeOperation = palette.blend;

      for (const layer of this.layers) {
        const { ox, oy } = layer;
        for (const neuron of layer.neurons) {
          ctx.globalAlpha = layer.alpha;
          ctx.drawImage(neuron.sprite, neuron.spriteX + ox, neuron.spriteY + oy, neuron.spriteW, neuron.spriteH);
          if (neuron.flash > 0.02) {
            ctx.globalAlpha = layer.alpha * neuron.flash * 0.75;
            ctx.drawImage(neuron.sprite, neuron.spriteX + ox, neuron.spriteY + oy, neuron.spriteW, neuron.spriteH);
            const size = neuron.somaR * 9 * (0.6 + neuron.flash * 0.6);
            this.drawSpark(neuron.x + ox, neuron.y + oy, size, layer.alpha * neuron.flash * 0.8, 0.6);
          }
        }

        for (const signal of this.signals) {
          if (signal.neuron.layer !== layer) {
            continue;
          }
          const { neuron } = signal;
          const s = layer.scale;
          const axon = neuron.axon;

          if (signal.phase === "axon") {
            const progress = signal.distance / axon.total;
            for (let k = 10; k >= 0; k--) {
              const back = signal.distance - k * 5 * s;
              if (back < 0) {
                continue;
              }
              const [x, y] = pointOnAxon(axon, back);
              const fade = 1 - k / 11;
              this.drawSpark(x + ox, y + oy, (k === 0 ? 26 : 14) * s * fade, layer.alpha * fade * 0.9, progress);
            }
          } else if (signal.phase === "terminal") {
            for (const terminal of neuron.terminals) {
              const [a, b, c] = terminal.points;
              const t = signal.t;
              const u = 1 - t;
              const x = u * u * a[0] + 2 * u * t * b[0] + t * t * c[0];
              const y = u * u * a[1] + 2 * u * t * b[1] + t * t * c[1];
              this.drawSpark(x + ox, y + oy, 16 * s, layer.alpha, 1);
            }
          } else {
            ctx.fillStyle = rgba(palette.vesicle, 1);
            for (const vesicle of signal.vesicles) {
              ctx.globalAlpha = layer.alpha * (1 - vesicle.life) * 0.9;
              ctx.beginPath();
              ctx.arc(vesicle.x + ox, vesicle.y + oy, 1.3 * s, 0, TAU);
              ctx.fill();
            }
          }
        }
      }

      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = "source-over";
      ctx.fillStyle = this.getVignette();
      ctx.fillRect(0, 0, this.width, this.height);
    }

    drawStill() {
      // A calm still frame for "reduce motion": a few cells lit, nothing moving.
      this.signals = [];
      this.layers.forEach((layer) => layer.neurons.forEach((neuron, index) => {
        neuron.flash = layer.signals && index % 3 === 0 ? 0.6 : 0;
      }));
      this.draw();
    }
  }

  const attach = (canvas) => {
    if (!canvas.kdSynapse) {
      canvas.kdSynapse = new NeuronScene(canvas);
    }
    return canvas.kdSynapse;
  };

  document.querySelectorAll("canvas.kd-synapse").forEach(attach);
  window.kdSynapse = { attach };
})();
