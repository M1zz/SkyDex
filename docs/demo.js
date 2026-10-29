// 하늘색 웹 체험: 앱의 판을 브라우저에서 그대로 만져 본다.
// 칸(SkyBoard), 칸의 색(SkySpectrum), 사진에서 색 고르기(SkyColorExtractor), 칸 채우기(SkyMatch),
// 흐려지기(SkyEntry.freshness, SkyBoard.faded), 색 이름(SkySimiles.nearest)을 앱 소스에서 옮겼다.
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text);

  // SkySimiles.all 의 색(순서 그대로). 이름과 설명은 T.sims 에 같은 순서로 들어온다.
  const SIM = ("0C1120 0A1424 14151C 1A2036 101B33 1E2C4E 2F3A5E 232B45 2B3856 33406B 4A6086 46586B 6E8098 7E90B6 B6BCC9 A6B2C6 " +
    "737688 9B8AA8 E8AE94 E5C2AC EFE2D2 E89A82 E6A8B4 E8B478 A9C7DE 9FC0D6 BFD8E6 C9D6E2 E4E9EF DCE6EE 8AA3BE 4A86C8 3E8FCF 2F62B4 " +
    "1F5AA0 2C77BC 22345F 7FB8D8 CBD2D6 B6C3CE C8C6C1 DEDCD8 B4B7B8 A3A6A8 9CA1AB 8F8983 24262B 45414A A8ADA9 BFC2BE 8C9499 6E7E8E " +
    "7A8C9C 7E8489 6A6E72 4A4E52 7E8C7A 8A9488 DCD9D1 E6E0D4 DED6C6 CFC6B0 C4B79A BFA684 C9B183 D6BE93 C8AE90 B7ABA0 BCA391 A5837A " +
    "9A8C80 7C726C 85706A 67605E 63535A C2A87E E8B04A C98B4F E88A3C E08258 C97B3F C94B24 D9603A C9432E D9455A C0596A 9A5A48 8A4A3C " +
    "7A3F58 6B3F4A 5A3550 6B5C86 8A87B8 4A3A63 3C3357").split(" ");
  // SkySpectrum.ordered: 판의 칸마다 그 칸의 색이 SIM 몇 번인지.
  const BEAD = [46, 0, 6, 55, 11, 73, 10, 91, 54, 16, 92, 52, 13, 17, 15, 26, 28, 32, 35, 33, 37, 43, 56, 49,
    45, 22, 67, 69, 61, 20, 19, 65, 23, 76, 21, 78, 80, 79, 82, 83, 72, 87, 85, 88, 74, 90, 93, 47];
  // SkyBoard.bands: 하늘이 빨리 바뀌는 때일수록 칸이 촘촘하다.
  const BANDS = [[0, 300, 6], [300, 480, 6], [480, 960, 12], [960, 1080, 6], [1080, 1260, 12], [1260, 1440, 6]];
  const SLOTS = [];
  BANDS.forEach(([s, e, n], band) => {
    for (let i = 0; i < n; i++) SLOTS.push({ start: s + Math.round((e - s) / n * i), end: s + Math.round((e - s) / n * (i + 1)), band });
  });
  // ScreenshotDemo.fills: 앱 스크린샷에 쓰는 예시 하루.
  const SAMPLE = [[2, "26272C"], [4, "303D60"], [6, "4C648A"], [8, "6C6461"], [10, "8396BB"], [13, "ACB9CC"], [14, "9FC0D6"],
    [15, "3D8FD0"], [17, "2E7BC1"], [18, "3266BA"], [20, "BED8E6"], [22, "7E9179"], [25, "EEAEB9"], [27, "A6857A"], [29, "EEE2D4"],
    [31, "D7C092"], [33, "F0B64B"], [35, "E9875A"], [37, "E1855B"], [39, "D04631"], [42, "C75C6C"], [44, "5D4F5A"], [46, "47395F"]];
  const AGES = [0, 1, 7, 14, 28, 49, 63];

  // --- 색 (Lab.swift, DeltaE.swift) ---
  const fromHex = h => [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16) / 255);
  const toHex = c => c.map(v => Math.round(Math.min(1, Math.max(0, v)) * 255).toString(16).padStart(2, "0")).join("").toUpperCase();
  function lab(c) {
    const [r, g, b] = c.map(v => v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
    const f = t => t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116;
    const fx = f((r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047);
    const fy = f(r * 0.2126729 + g * 0.7151522 + b * 0.0721750);
    const fz = f((r * 0.0193339 + g * 0.1191920 + b * 0.9503041) / 1.08883);
    return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
  }
  function rgb([l, a, b]) {
    const fy = (l + 16) / 116, inv = t => t ** 3 > 0.008856 ? t ** 3 : (t - 16 / 116) / 7.787;
    const x = inv(fy + a / 500) * 0.95047, y = inv(fy), z = inv(fy - b / 200) * 1.08883;
    const g = c => c <= 0.0031308 ? c * 12.92 : 1.055 * c ** (1 / 2.4) - 0.055;
    return [x * 3.2404542 - y * 1.5371385 - z * 0.4985314, -x * 0.9692660 + y * 1.8760108 + z * 0.0415560,
      x * 0.0556434 - y * 0.2040259 + z * 1.0572252].map(g);
  }
  function de2000(p, q) {
    const d = Math.PI / 180, c1 = Math.hypot(p[1], p[2]), c2 = Math.hypot(q[1], q[2]), cb7 = ((c1 + c2) / 2) ** 7;
    const G = 0.5 * (1 - Math.sqrt(cb7 / (cb7 + 25 ** 7))), a1 = (1 + G) * p[1], a2 = (1 + G) * q[1];
    const C1 = Math.hypot(a1, p[2]), C2 = Math.hypot(a2, q[2]);
    const hue = (a, b) => a === 0 && b === 0 ? 0 : (Math.atan2(b, a) / d + 360) % 360;
    const h1 = hue(a1, p[2]), h2 = hue(a2, q[2]);
    let dh = 0;
    if (C1 * C2 !== 0) { dh = h2 - h1; if (dh > 180) dh -= 360; else if (dh < -180) dh += 360; }
    const dH = 2 * Math.sqrt(C1 * C2) * Math.sin(dh / 2 * d), L = (p[0] + q[0]) / 2, C = (C1 + C2) / 2;
    const H = C1 * C2 === 0 ? h1 + h2 : Math.abs(h1 - h2) <= 180 ? (h1 + h2) / 2 : h1 + h2 < 360 ? (h1 + h2 + 360) / 2 : (h1 + h2 - 360) / 2;
    const t = 1 - 0.17 * Math.cos((H - 30) * d) + 0.24 * Math.cos(2 * H * d) + 0.32 * Math.cos((3 * H + 6) * d) - 0.2 * Math.cos((4 * H - 63) * d);
    const C7 = C ** 7, rC = 2 * Math.sqrt(C7 / (C7 + 25 ** 7)), rT = -Math.sin(2 * 30 * Math.exp(-(((H - 275) / 25) ** 2)) * d) * rC;
    const sL = 1 + 0.015 * (L - 50) ** 2 / Math.sqrt(20 + (L - 50) ** 2);
    const tl = (q[0] - p[0]) / sL, tc = (C2 - C1) / (1 + 0.045 * C), th = dH / (1 + 0.015 * C * t);
    return Math.sqrt(tl * tl + tc * tc + th * th + rT * tc * th);
  }
  const SIM_LAB = SIM.map(h => lab(fromHex(h)));
  const ghost = ([l, a, b]) => [52 + (l - 52) * 0.32, a * 0.38, b * 0.38];          // SkyBoard.ghost
  const freshness = days => days <= 7 ? 1 : Math.max(0, 1 - Math.min(1, (days - 7) / 56));
  function faded(c, f) {                                                             // SkyBoard.faded
    if (f >= 1) return toHex(c);
    const p = lab(c), q = ghost(p), t = (1 - f) * 0.62;
    return toHex(rgb(p.map((v, i) => v + (q[i] - v) * t)));
  }
  const nearest = l => SIM_LAB.reduce((best, s, i) => (de2000(l, s) < de2000(l, SIM_LAB[best]) ? i : best), 0);

  // --- 사진에서 하늘색: 정사각형으로 자르고, 위 3분의 1을 64×64로, Lab k-평균 3개 중 15% 넘는 가장 밝은 무리 ---
  async function skyColour(file) {
    const bmp = await createImageBitmap(file), side = Math.min(bmp.width, bmp.height);
    const cv = Object.assign(document.createElement("canvas"), { width: 64, height: 64 }), x = cv.getContext("2d");
    x.drawImage(bmp, (bmp.width - side) / 2, (bmp.height - side) / 2, side, Math.max(1, Math.floor(side / 3)), 0, 0, 64, 64);
    const px = x.getImageData(0, 0, 64, 64).data, S = [];
    for (let i = 0; i < px.length; i += 4) if (px[i + 3] > 127) { const c = [px[i], px[i + 1], px[i + 2]].map(v => v / 255); S.push({ c, l: lab(c) }); }
    const sorted = [...S].sort((a, b) => a.l[0] - b.l[0]);
    let cen = [0, 1, 2].map(k => sorted[Math.floor((S.length - 1) * (k + 0.5) / 3)].l), as = [];
    for (let it = 0; it < 12; it++) {
      as = S.map(s => cen.reduce((b, c, k) => (s.l.reduce((d, v, j) => d + (v - c[j]) ** 2, 0) < s.l.reduce((d, v, j) => d + (v - cen[b][j]) ** 2, 0) ? k : b), 0));
      cen = cen.map((c, k) => { const m = S.filter((_, i) => as[i] === k); return m.length ? [0, 1, 2].map(j => m.reduce((d, s) => d + s.l[j], 0) / m.length) : c; });
    }
    const groups = cen.map((l, k) => { const m = S.filter((_, i) => as[i] === k); return m.length && { l, w: m.length / S.length, c: [0, 1, 2].map(j => m.reduce((d, s) => d + s.c[j], 0) / m.length) }; }).filter(Boolean);
    const pool = groups.filter(g => g.w >= 0.15).length ? groups.filter(g => g.w >= 0.15) : groups;
    return pool.reduce((a, b) => (b.l[0] > a.l[0] ? b : a));
  }

  // --- 판 채우기 (SkyMatch.map): 오늘 찍은 하늘은 찍은 시각의 칸을, 나머지는 3.5 안의 가장 가까운 칸 하나를 ---
  const entries = SAMPLE.map(([slot, h], i) => ({ slot, c: fromHex(h), l: lab(fromHex(h)), order: i }));
  const state = { age: 0, selected: null };
  const nowSlot = () => { const d = new Date(), m = d.getHours() * 60 + d.getMinutes(); return SLOTS.findLastIndex(s => s.start <= m); };
  function board() {
    const result = {};
    if (state.age === 0) for (const e of entries) if (!result[e.slot] || result[e.slot].order < e.order) result[e.slot] = e;
    const spoken = new Set(Object.values(result)), pairs = [];
    SLOTS.forEach((_, id) => { if (!result[id]) for (const e of entries) if (!spoken.has(e)) { const d = de2000(SIM_LAB[BEAD[id]], e.l); if (d <= 3.5) pairs.push([id, e, d]); } });
    pairs.sort((a, b) => a[2] - b[2] || b[1].order - a[1].order || a[0] - b[0]);
    for (const [id, e] of pairs) if (!result[id] && !spoken.has(e)) { result[id] = e; spoken.add(e); }
    return result;
  }

  const time = s => [s.start, s.end].map(m => `${String(Math.floor(m / 60) % 24).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`).join("–");
  root.innerHTML = `
    <div class="sky-board" role="group"></div>
    <div class="sky-side">
      <div class="sky-info" aria-live="polite"></div>
      <label class="sky-photo"><input type="file" accept="image/*"><span>${T.photo}</span></label>
      <div class="sky-age"><label for="sky-age">${T.age}</label><input id="sky-age" type="range" min="0" max="${AGES.length - 1}" step="1" value="0"><output></output></div>
      <p class="muted small">${T.note}</p>
    </div>`;
  const $ = s => root.querySelector(s), grid = $(".sky-board"), info = $(".sky-info"), out = $(".sky-age output");
  grid.innerHTML = SLOTS.map((s, i) => `<button type="button" class="bead" data-slot="${i}"></button>`).join("");

  function render() {
    const filled = board(), now = nowSlot(), days = AGES[state.age], f = freshness(days), sel = state.selected ?? now;
    out.textContent = days === 0 ? T.ageToday : (days === 1 ? T.ageDay : T.ageDays).replace("{n}", days);
    grid.querySelectorAll(".bead").forEach((b, id) => {
      const e = filled[id], s = SLOTS[id];
      b.style.setProperty("--c", e ? "#" + faded(e.c, f) : "#" + toHex(rgb(ghost(SIM_LAB[BEAD[id]]))));
      b.classList.toggle("on", !!e); b.classList.toggle("now", id === now); b.setAttribute("aria-pressed", String(id === sel));
      b.setAttribute("aria-label", `${time(s)} · ${T.bands[s.band]} · ${e ? T.sims[nearest(e.l)][0] : T.emptyTag.replace("%@", T.bands[s.band])}`);
    });
    const e = filled[sel], s = SLOTS[sel], k = e ? nearest(e.l) : BEAD[sel];
    info.innerHTML = `<p class="sky-time">${time(s)}${sel === now ? ` · <b>${T.now}</b>` : ""}</p>
      <p class="muted small">${e ? `${T.bands[s.band]} · #${toHex(e.c)}` : T.emptyTag.replace("%@", T.bands[s.band])}</p>
      <div class="sky-name">${e && e.url ? `<img src="${e.url}" alt="">` : `<i style="background:#${e ? toHex(e.c) : SIM[k]}"></i>`}
      <div><b>${T.sims[k][0]}</b><span class="muted small">${T.sims[k][1]}</span></div></div>
      ${e ? "" : `<p class="muted small">${T.spot}</p>`}`;
  }

  grid.addEventListener("click", ev => { const b = ev.target.closest(".bead"); if (b) { state.selected = +b.dataset.slot; render(); } });
  $(".sky-age input").addEventListener("input", ev => { state.age = +ev.target.value; render(); });
  $(".sky-photo input").addEventListener("change", async ev => {
    const file = ev.target.files[0]; if (!file) return;
    const g = await skyColour(file), slot = nowSlot();
    entries.push({ slot, c: g.c, l: g.l, order: entries.length, url: URL.createObjectURL(file) });
    state.age = 0; $(".sky-age input").value = 0; state.selected = slot; render();
    ev.target.value = "";
  });
  render();
})();
