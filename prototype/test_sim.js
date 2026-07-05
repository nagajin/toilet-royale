// トイレロワイヤル v0.1 — sim.js の簡易テスト
// 実行: node prototype/test_sim.js

"use strict";

var Sim = require("./sim.js");
var C = Sim.CONFIG;

var failures = 0;
function assert(cond, name) {
  if (cond) {
    console.log("  ok - " + name);
  } else {
    console.error("  NG - " + name);
    failures++;
  }
}

var DT = 1 / 120;
function run(world, seconds, input) {
  var steps = Math.round(seconds / DT);
  for (var i = 0; i < steps; i++) {
    Sim.stepWorld(world, DT, [input || {}]);
  }
}

console.log("1. 左右移動");
{
  var w = Sim.createWorld(1);
  var x0 = w.players[0].x;
  run(w, 1.0, { right: true });
  var x1 = w.players[0].x;
  assert(x1 > x0 + 150, "右入力1秒で150px以上進む (x: " + x0 + " -> " + x1.toFixed(1) + ")");
  assert(x1 < C.bowl.left, "1秒では便器まで届かない");
  run(w, 1.0, { left: true });
  assert(w.players[0].x < x1, "左入力で戻る");
}

console.log("2. ジャンプと着地");
{
  var w2 = Sim.createWorld(1);
  run(w2, DT, { jump: true });
  assert(!w2.players[0].onGround, "ジャンプ直後は空中にいる");
  assert(w2.players[0].vy < 0, "上向きの速度を持つ");
  run(w2, 1.5, {});
  assert(w2.players[0].onGround, "1.5秒後には着地している");
  assert(Math.abs(w2.players[0].y - C.groundY) < 0.001, "接地位置は groundY");
}

console.log("3. 水流フェーズの遷移");
{
  var w3 = Sim.createWorld(1);
  assert(w3.phase === "idle", "初期フェーズは idle");
  run(w3, C.flush.idleTime + 0.05, {});
  assert(w3.phase === "warning", "idleTime 経過で warning になる");
  run(w3, C.flush.warnTime, {});
  assert(w3.phase === "flushing", "warnTime 経過で flushing になる");
  assert(w3.flushCount === 1, "水流回数がカウントされる");
  run(w3, C.flush.flushTime, {});
  assert(w3.phase === "idle", "flushTime 経過で idle に戻る");
  var types = w3.events.map(function (e) { return e.type; });
  assert(types.indexOf("warning") >= 0, "warning イベントが記録される");
  assert(types.indexOf("flush_start") >= 0, "flush_start イベントが記録される");
}

console.log("4. 水流による吸い込み");
{
  var w4 = Sim.createWorld(1);
  w4.players[0].x = 300; // トイレ左側、無入力なら逃げ切れない位置
  w4.phase = "flushing";
  w4.phaseTimer = C.flush.flushTime;
  run(w4, 1.0, {});
  var p = w4.players[0];
  assert(p.x > 320 || p.state !== "alive", "無入力ならトイレ方向へ流される (x=" + p.x.toFixed(1) + ")");
  run(w4, 2.0, {});
  assert(w4.players[0].fallCount === 1, "x=300 で無抵抗なら流されて脱落する");
}

console.log("5. 画面端なら無入力でも耐えられる");
{
  var w5 = Sim.createWorld(1);
  w5.players[0].x = C.wallLeft;
  w5.phase = "flushing";
  w5.phaseTimer = C.flush.flushTime;
  run(w5, C.flush.flushTime, {});
  assert(w5.players[0].state === "alive", "左端スタートなら1回の水流を生き残る (x=" + w5.players[0].x.toFixed(1) + ")");
}

console.log("6. 逃げ入力なら水流に抵抗できる");
{
  var w6 = Sim.createWorld(1);
  w6.players[0].x = 300;
  w6.phase = "flushing";
  w6.phaseTimer = C.flush.flushTime;
  run(w6, C.flush.flushTime, { left: true });
  assert(w6.players[0].state === "alive", "左入力し続ければ生き残れる (x=" + w6.players[0].x.toFixed(1) + ")");
}

console.log("7. 脱落 → リスパウン");
{
  var w7 = Sim.createWorld(1);
  w7.players[0].x = C.bowl.centerX; // 便器の真上に配置
  w7.players[0].y = C.groundY;
  run(w7, 0.5, {});
  assert(w7.players[0].fallCount === 1, "便器に落ちると脱落する");
  run(w7, C.flushAnimTime + C.respawnTime + 0.1, {});
  var p7 = w7.players[0];
  assert(p7.state === "alive", "演出後にリスパウンする");
  assert(p7.x === C.spawnPoints[0], "スポーン地点に戻る");
}

console.log("8. 複数プレイヤーでも動く（将来のローカル対戦用）");
{
  var w8 = Sim.createWorld(4);
  assert(w8.players.length === 4, "4人生成できる");
  var xs = w8.players.map(function (p) { return p.x; });
  assert(new Set(xs).size === 4, "スポーン位置が重ならない");
  for (var i = 0; i < 120; i++) Sim.stepWorld(w8, DT, [{ right: true }, { left: true }, {}, {}]);
  assert(w8.players[0].x > xs[0], "P1 が右へ動く");
  assert(w8.players[1].x < xs[1], "P2 が左へ動く");
}

console.log("");
if (failures > 0) {
  console.error(failures + " 件のテストが失敗");
  process.exit(1);
} else {
  console.log("全テスト成功 ✅");
}
