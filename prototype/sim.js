// トイレロワイヤル v0.1 — 物理・状態機械（純ロジック）
// ブラウザでは window.ToiletSim、Node.js では module.exports として公開する。
// 描画・入力は game.js 側。ここには Canvas / DOM 依存を置かないこと。

(function (global) {
  "use strict";

  var CONFIG = {
    width: 960,
    height: 540,
    groundY: 470,
    wallLeft: 24,
    wallRight: 936,
    bowl: {
      left: 400, // 便器開口部の左端
      right: 560, // 便器開口部の右端
      centerX: 480,
      waterY: 524, // 便器内の水面
      deathY: 526, // 水面より下に到達したら脱落（仕様: 水面より下）
    },
    // 2〜4人対戦に拡張するときは spawnPoints の順に配置する
    spawnPoints: [140, 820, 240, 720],
    player: {
      radius: 18,
      runSpeed: 240, // 目標速度 px/s
      groundLerp: 12, // 地上での速度補間の強さ /s
      airLerp: 4, // 空中では入力も水流抵抗も効きにくい
      jumpVel: -430,
      gravity: 1200,
    },
    flush: {
      idleTime: 5.0,
      warnTime: 2.5,
      flushTime: 3.0,
      suction: 1200, // 吸引の基本加速度 px/s^2
      falloffDist: 500, // 距離による減衰スケール
      minFactor: 0.45, // 画面端でも最低これだけは吸う
      maxFactor: 1.4, // トイレ直近の最大係数
    },
    flushAnimTime: 0.9, // 螺旋吸い込み演出の長さ
    respawnTime: 1.2,
  };

  function clamp(v, lo, hi) {
    return v < lo ? lo : v > hi ? hi : v;
  }

  function createPlayer(index) {
    var spawnX = CONFIG.spawnPoints[index % CONFIG.spawnPoints.length];
    return {
      index: index,
      x: spawnX,
      y: CONFIG.groundY,
      vx: 0,
      vy: 0,
      onGround: true,
      // "alive" | "flushed"(吸い込まれ演出中) | "respawning"
      state: "alive",
      stateTimer: 0,
      // 吸い込まれ演出の開始位置（螺旋の起点）
      flushFromX: 0,
      flushFromY: 0,
      angle: 0, // 見た目の回転（空中・吸引中に回る）
      fallCount: 0,
    };
  }

  function createWorld(playerCount) {
    var players = [];
    var n = playerCount || 1;
    for (var i = 0; i < n; i++) players.push(createPlayer(i));
    return {
      players: players,
      // "idle" | "warning" | "flushing"
      phase: "idle",
      phaseTimer: CONFIG.flush.idleTime,
      flushCount: 0,
      time: 0,
      events: [], // 描画側がログ表示のために drain する
    };
  }

  function respawn(player) {
    var spawnX = CONFIG.spawnPoints[player.index % CONFIG.spawnPoints.length];
    player.x = spawnX;
    player.y = CONFIG.groundY;
    player.vx = 0;
    player.vy = 0;
    player.onGround = true;
    player.state = "alive";
    player.stateTimer = 0;
    player.angle = 0;
  }

  function updateFlushMachine(world, dt) {
    world.phaseTimer -= dt;
    if (world.phaseTimer > 0) return;
    if (world.phase === "idle") {
      world.phase = "warning";
      world.phaseTimer += CONFIG.flush.warnTime;
      world.events.push({ type: "warning", time: world.time });
    } else if (world.phase === "warning") {
      world.phase = "flushing";
      world.phaseTimer += CONFIG.flush.flushTime;
      world.flushCount++;
      world.events.push({ type: "flush_start", time: world.time });
    } else {
      world.phase = "idle";
      world.phaseTimer += CONFIG.flush.idleTime;
      world.events.push({ type: "flush_end", time: world.time });
    }
  }

  function suctionAccel(x) {
    var dist = Math.abs(CONFIG.bowl.centerX - x);
    var factor = clamp(
      CONFIG.flush.maxFactor - dist / CONFIG.flush.falloffDist,
      CONFIG.flush.minFactor,
      CONFIG.flush.maxFactor
    );
    var dir = CONFIG.bowl.centerX >= x ? 1 : -1;
    return CONFIG.flush.suction * factor * dir;
  }

  function stepPlayer(world, player, input, dt) {
    var P = CONFIG.player;

    if (player.state === "flushed") {
      player.stateTimer -= dt;
      player.angle += 18 * dt; // 螺旋演出中は高速回転
      if (player.stateTimer <= 0) {
        player.state = "respawning";
        player.stateTimer = CONFIG.respawnTime;
      }
      return;
    }
    if (player.state === "respawning") {
      player.stateTimer -= dt;
      if (player.stateTimer <= 0) {
        respawn(player);
        world.events.push({ type: "respawn", player: player.index, time: world.time });
      }
      return;
    }

    // --- alive ---
    var move = (input.right ? 1 : 0) - (input.left ? 1 : 0);
    var target = move * P.runSpeed;
    var lerp = player.onGround ? P.groundLerp : P.airLerp;
    player.vx += (target - player.vx) * Math.min(1, lerp * dt);

    if (world.phase === "flushing") {
      player.vx += suctionAccel(player.x) * dt;
    }

    if (input.jump && player.onGround) {
      player.vy = P.jumpVel;
      player.onGround = false;
    }

    player.vy += P.gravity * dt;
    player.x += player.vx * dt;
    player.y += player.vy * dt;

    // 壁
    if (player.x < CONFIG.wallLeft) {
      player.x = CONFIG.wallLeft;
      player.vx = Math.max(0, player.vx);
    } else if (player.x > CONFIG.wallRight) {
      player.x = CONFIG.wallRight;
      player.vx = Math.min(0, player.vx);
    }

    // 床（便器開口部の上には床がない）
    var overBowl = player.x > CONFIG.bowl.left && player.x < CONFIG.bowl.right;
    if (!overBowl && player.y >= CONFIG.groundY) {
      player.y = CONFIG.groundY;
      player.vy = 0;
      player.onGround = true;
    } else {
      player.onGround = false;
    }

    // 見た目の回転（空中で流されているとコロコロ回る）
    if (!player.onGround) {
      player.angle += player.vx * dt * 0.02;
    } else {
      player.angle = 0;
    }

    // 便器に落ちたら脱落
    if (overBowl && player.y > CONFIG.bowl.deathY) {
      player.state = "flushed";
      player.stateTimer = CONFIG.flushAnimTime;
      player.flushFromX = player.x;
      player.flushFromY = player.y;
      player.fallCount++;
      world.events.push({ type: "flushed", player: player.index, time: world.time });
    }
  }

  // inputs: プレイヤーごとの { left, right, jump } の配列
  function stepWorld(world, dt, inputs) {
    world.time += dt;
    updateFlushMachine(world, dt);
    for (var i = 0; i < world.players.length; i++) {
      var input = (inputs && inputs[i]) || { left: false, right: false, jump: false };
      stepPlayer(world, world.players[i], input, dt);
    }
  }

  var api = {
    CONFIG: CONFIG,
    createWorld: createWorld,
    stepWorld: stepWorld,
    suctionAccel: suctionAccel,
  };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = api;
  } else {
    global.ToiletSim = api;
  }
})(typeof window !== "undefined" ? window : globalThis);
