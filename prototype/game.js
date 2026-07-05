// トイレロワイヤル v0.1 — 描画・入力・演出（ブラウザ専用）
// 物理・状態機械は sim.js（window.ToiletSim）側。

(function () {
  "use strict";

  var Sim = window.ToiletSim;
  var C = Sim.CONFIG;

  var canvas = document.getElementById("game");
  var ctx = canvas.getContext("2d");
  var logEl = document.getElementById("log");

  var world = Sim.createWorld(1);

  // --- 入力 ---------------------------------------------------------------
  // 2〜4人対戦に拡張するときはここにキーマップを足し、createWorld(n) を変える
  var KEYMAPS = [
    {
      left: ["ArrowLeft", "KeyA"],
      right: ["ArrowRight", "KeyD"],
      jump: ["Space", "KeyW", "ArrowUp"],
    },
  ];

  var pressed = {};
  window.addEventListener("keydown", function (e) {
    pressed[e.code] = true;
    if (e.code === "Space" || e.code === "ArrowUp" || e.code === "ArrowDown") {
      e.preventDefault(); // ページスクロール防止
    }
    if (e.code === "KeyR") {
      world = Sim.createWorld(1);
      logLines = [];
      renderLog();
      pushLog("リセットしました");
    }
  });
  window.addEventListener("keyup", function (e) {
    pressed[e.code] = false;
  });

  function readInput(map) {
    function any(codes) {
      for (var i = 0; i < codes.length; i++) if (pressed[codes[i]]) return true;
      return false;
    }
    return { left: any(map.left), right: any(map.right), jump: any(map.jump) };
  }

  // --- ログ ---------------------------------------------------------------
  var logLines = [];
  function pushLog(text) {
    var t = world.time.toFixed(1);
    logLines.push("[" + t + "s] " + text);
    if (logLines.length > 8) logLines.shift();
    renderLog();
  }
  function renderLog() {
    logEl.textContent = logLines.join("\n");
  }

  var FLUSH_QUIPS = ["南無…", "いい流れっぷり", "ジャーッ！", "また会おう"];
  function handleEvents() {
    for (var i = 0; i < world.events.length; i++) {
      var ev = world.events[i];
      if (ev.type === "warning") pushLog("⚠️ ゴゴゴゴ… まもなく水流！");
      else if (ev.type === "flush_start") pushLog("🌊 水流発生！！（" + world.flushCount + "回目）");
      else if (ev.type === "flush_end") pushLog("水流が収まった…");
      else if (ev.type === "flushed") {
        var quip = FLUSH_QUIPS[Math.floor(Math.random() * FLUSH_QUIPS.length)];
        pushLog("🌀 P" + (ev.player + 1) + " が流された！ " + quip);
      } else if (ev.type === "respawn") pushLog("P" + (ev.player + 1) + " リスパウン");
    }
    world.events.length = 0;
  }

  // --- パーティクル（渦・水しぶき） ----------------------------------------
  var particles = [];
  function spawnSwirlParticles(dt) {
    // 水流中: ステージのあちこちから便器へ吸い込まれる水滴/風
    if (Math.random() < dt * 60) {
      var side = Math.random() < 0.5 ? -1 : 1;
      particles.push({
        kind: "wind",
        x: C.bowl.centerX + side * (120 + Math.random() * 320),
        y: C.groundY - 4 - Math.random() * 120,
        life: 0.8,
        maxLife: 0.8,
      });
    }
  }
  function spawnSplash() {
    for (var i = 0; i < 14; i++) {
      var a = -Math.PI / 2 + (Math.random() - 0.5) * 1.6;
      var sp = 140 + Math.random() * 220;
      particles.push({
        kind: "drop",
        x: C.bowl.centerX,
        y: C.bowl.waterY - 6,
        vx: Math.cos(a) * sp,
        vy: Math.sin(a) * sp,
        life: 0.7,
        maxLife: 0.7,
      });
    }
  }
  function stepParticles(dt) {
    for (var i = particles.length - 1; i >= 0; i--) {
      var p = particles[i];
      p.life -= dt;
      if (p.life <= 0) {
        particles.splice(i, 1);
        continue;
      }
      if (p.kind === "wind") {
        var dir = C.bowl.centerX >= p.x ? 1 : -1;
        p.x += dir * 420 * dt;
        p.y += (C.bowl.waterY - p.y) * 1.5 * dt;
      } else {
        p.vy += 900 * dt;
        p.x += p.vx * dt;
        p.y += p.vy * dt;
      }
    }
  }

  // --- 描画 ---------------------------------------------------------------
  function shakeAmount() {
    if (world.phase === "warning") return 1.5;
    if (world.phase === "flushing") return 4;
    return 0;
  }

  function drawBackground() {
    ctx.fillStyle = "#dce9ef";
    ctx.fillRect(0, 0, C.width, C.height);
    // タイル壁
    ctx.strokeStyle = "rgba(140,170,185,0.35)";
    ctx.lineWidth = 1;
    for (var x = 0; x <= C.width; x += 60) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, C.groundY);
      ctx.stroke();
    }
    for (var y = 0; y <= C.groundY; y += 60) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(C.width, y);
      ctx.stroke();
    }
  }

  function drawFloor() {
    ctx.fillStyle = "#8a99a5";
    ctx.fillRect(0, C.groundY, C.bowl.left, C.height - C.groundY);
    ctx.fillRect(C.bowl.right, C.groundY, C.width - C.bowl.right, C.height - C.groundY);
    ctx.fillStyle = "#77858f";
    ctx.fillRect(0, C.groundY, C.bowl.left, 8);
    ctx.fillRect(C.bowl.right, C.groundY, C.width - C.bowl.right, 8);
  }

  function drawToilet() {
    var cx = C.bowl.centerX;
    var t = world.time;
    var wobble = 0;
    if (world.phase === "warning") wobble = Math.sin(t * 40) * 3;
    if (world.phase === "flushing") wobble = Math.sin(t * 55) * 5;

    // タンク
    ctx.save();
    ctx.translate(wobble, 0);
    ctx.fillStyle = "#f7f9fa";
    ctx.strokeStyle = "#9fb2bd";
    ctx.lineWidth = 3;
    roundRect(cx - 110, 190, 220, 130, 14, true, true);
    // タンクのフタ
    roundRect(cx - 122, 178, 244, 26, 10, true, true);
    // レバー
    ctx.fillStyle = "#c0ced6";
    roundRect(cx - 100, 214, 34, 12, 5, true, false);
    // 送水パイプ
    ctx.fillStyle = "#e7edf0";
    ctx.fillRect(cx - 24, 320, 48, C.groundY - 320);
    ctx.strokeRect(cx - 24, 320, 48, C.groundY - 320);
    ctx.restore();

    // 便座（開口部のフチ）
    ctx.fillStyle = "#f7f9fa";
    ctx.strokeStyle = "#9fb2bd";
    ctx.beginPath();
    ctx.ellipse(cx, C.groundY + 2, (C.bowl.right - C.bowl.left) / 2 + 26, 16, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();

    // 便器の内側（すり鉢）
    ctx.fillStyle = "#eef4f6";
    ctx.beginPath();
    ctx.moveTo(C.bowl.left, C.groundY);
    ctx.quadraticCurveTo(cx, C.height + 30, C.bowl.right, C.groundY);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    // 水面
    var swirl = world.phase === "flushing";
    ctx.fillStyle = swirl ? "#4fb3e8" : "#7fc9ee";
    ctx.beginPath();
    ctx.ellipse(cx, C.bowl.waterY, 62, 12, 0, 0, Math.PI * 2);
    ctx.fill();
    if (swirl) {
      // 渦のライン
      ctx.strokeStyle = "rgba(255,255,255,0.85)";
      ctx.lineWidth = 2.5;
      for (var i = 0; i < 3; i++) {
        var a0 = t * 7 + (i * Math.PI * 2) / 3;
        ctx.beginPath();
        ctx.ellipse(cx, C.bowl.waterY, 44 - i * 13, 8 - i * 2, 0, a0, a0 + 2.2);
        ctx.stroke();
      }
    }
  }

  function drawWarning() {
    var cx = C.bowl.centerX;
    if (world.phase === "warning") {
      var blink = Math.sin(world.time * 16) > 0;
      if (blink) {
        ctx.fillStyle = "#e5484d";
        ctx.font = "bold 30px sans-serif";
        ctx.textAlign = "center";
        ctx.fillText("⚠ ゴゴゴゴ…", cx, 150 + Math.sin(world.time * 50) * 3);
      }
    } else if (world.phase === "flushing") {
      ctx.fillStyle = "#1f7ec2";
      ctx.font = "bold 34px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("🌊 水流中！！", cx, 150 + Math.sin(world.time * 60) * 4);
    }
  }

  function drawWindParticles() {
    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];
      var alpha = Math.max(0, p.life / p.maxLife);
      if (p.kind === "wind") {
        var dir = C.bowl.centerX >= p.x ? 1 : -1;
        ctx.strokeStyle = "rgba(90,170,220," + alpha * 0.8 + ")";
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(p.x, p.y);
        ctx.lineTo(p.x - dir * 26, p.y);
        ctx.stroke();
      } else {
        ctx.fillStyle = "rgba(80,160,215," + alpha + ")";
        ctx.beginPath();
        ctx.arc(p.x, p.y, 4, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  var PLAYER_COLORS = ["#f5a03c", "#5fbf6e", "#e56db1", "#8f7ff0"];

  function drawPlayer(player) {
    var r = C.player.radius;
    var x = player.x;
    var y = player.y - r; // player.y は接地点
    var scale = 1;
    var angle = player.angle;

    if (player.state === "respawning") return;

    if (player.state === "flushed") {
      // 螺旋を描いて便器中心へ吸い込まれる
      var prog = Math.min(1, Math.max(0, 1 - player.stateTimer / SimFlushAnimTime()));
      var spiralA = prog * Math.PI * 5;
      var fromX = player.flushFromX;
      var fromY = player.flushFromY - r;
      var toX = C.bowl.centerX;
      var toY = C.bowl.waterY - 4;
      var radius = (1 - prog) * 46;
      x = fromX + (toX - fromX) * prog + Math.cos(spiralA) * radius * prog;
      y = fromY + (toY - fromY) * prog + Math.sin(spiralA) * radius * 0.3 * prog;
      scale = 1 - prog * 0.8;
      angle = spiralA * 2;
    }

    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(angle);
    ctx.scale(scale, scale);

    // 体
    ctx.fillStyle = PLAYER_COLORS[player.index % PLAYER_COLORS.length];
    ctx.strokeStyle = "rgba(0,0,0,0.35)";
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();

    // 顔（水流中はパニック顔）
    var panic = world.phase === "flushing" || player.state === "flushed";
    var lookDir = player.vx === 0 ? 0 : player.vx > 0 ? 1 : -1;
    ctx.fillStyle = "#222";
    ctx.beginPath();
    ctx.arc(-6 + lookDir * 2, -4, panic ? 3.6 : 2.6, 0, Math.PI * 2);
    ctx.arc(6 + lookDir * 2, -4, panic ? 3.6 : 2.6, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    if (panic) {
      ctx.fillStyle = "#222";
      ctx.ellipse(lookDir * 2, 6, 4.5, 6, 0, 0, Math.PI * 2);
      ctx.fill();
    } else {
      ctx.strokeStyle = "#222";
      ctx.lineWidth = 2;
      ctx.arc(lookDir * 2, 4, 5, 0.15 * Math.PI, 0.85 * Math.PI);
      ctx.stroke();
    }
    ctx.restore();

    // 吸い込まれ中の悲鳴
    if (player.state === "flushed") {
      ctx.fillStyle = "#e5484d";
      ctx.font = "bold 22px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("うわあああ！", x, y - 34);
    }
  }

  function SimFlushAnimTime() {
    return Sim.CONFIG.flushAnimTime;
  }

  function drawUI() {
    ctx.fillStyle = "rgba(20,40,55,0.72)";
    roundRect(12, 10, 400, 58, 10, true, false);
    ctx.fillStyle = "#fff";
    ctx.font = "bold 18px sans-serif";
    ctx.textAlign = "left";
    var phaseText;
    if (world.phase === "idle") phaseText = "水流まで " + Math.max(0, world.phaseTimer).toFixed(1) + "s";
    else if (world.phase === "warning") phaseText = "⚠ まもなく水流！ " + Math.max(0, world.phaseTimer).toFixed(1) + "s";
    else phaseText = "🌊 水流中！！ 残り " + Math.max(0, world.phaseTimer).toFixed(1) + "s";
    ctx.fillText(phaseText, 26, 34);
    ctx.font = "14px sans-serif";
    ctx.fillText("水流回数: " + world.flushCount + "　流された回数: " + world.players[0].fallCount, 26, 57);

    ctx.fillStyle = "rgba(20,40,55,0.55)";
    roundRect(C.width - 330, 10, 318, 30, 8, true, false);
    ctx.fillStyle = "#fff";
    ctx.font = "13px sans-serif";
    ctx.fillText("←→/AD: 移動　Space: ジャンプ　R: リセット", C.width - 318, 30);
  }

  function roundRect(x, y, w, h, r, fill, stroke) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
    if (fill) ctx.fill();
    if (stroke) ctx.stroke();
  }

  function draw() {
    ctx.save();
    var s = shakeAmount();
    if (s > 0) {
      ctx.translate((Math.random() - 0.5) * 2 * s, (Math.random() - 0.5) * 2 * s);
    }
    drawBackground();
    drawToilet();
    drawFloor();
    drawWindParticles();
    for (var i = 0; i < world.players.length; i++) drawPlayer(world.players[i]);
    drawWarning();
    ctx.restore();
    drawUI();
  }

  // --- メインループ ---------------------------------------------------------
  var lastT = performance.now();
  function frame(now) {
    var dt = Math.min(1 / 30, (now - lastT) / 1000);
    lastT = now;

    var inputs = [readInput(KEYMAPS[0])];
    Sim.stepWorld(world, dt, inputs);
    handleEvents();
    if (world.phase === "flushing") spawnSwirlParticles(dt);
    stepParticles(dt);

    // 脱落の瞬間に水しぶき
    for (var i = 0; i < world.players.length; i++) {
      var p = world.players[i];
      if (p.state === "flushed" && p.stateTimer > SimFlushAnimTime() - 0.03 && !p._splashed) {
        spawnSplash();
        p._splashed = true;
      }
      if (p.state === "alive") p._splashed = false;
    }

    draw();
    requestAnimationFrame(frame);
  }

  pushLog("トイレロワイヤル v0.1 起動。水流に気をつけろ！");
  requestAnimationFrame(frame);
})();
