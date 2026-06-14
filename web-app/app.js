/* よみたま Web版 (PWA)
 * 音読するとペットが育つ小学生向けアプリ。
 * すべて端末内（localStorage / IndexedDB）で完結し、画像・音声・文章を外部に送信しません。
 * OCRはブラウザで動く Tesseract.js（日本語）を使用します。
 */
(() => {
  'use strict';

  // ---------------- 進化段階 ----------------
  const STAGES = [
    { key: 'egg',     label: 'たまご',       emoji: '🥚', req: 0 },
    { key: 'chick',   label: 'ひよこ',       emoji: '🐣', req: 50 },
    { key: 'child',   label: 'こどもペット', emoji: '🐤', req: 150 },
    { key: 'evolved', label: '進化ペット',   emoji: '🦅', req: 350 },
    { key: 'rare',    label: 'レア進化',     emoji: '🐉', req: 700 },
  ];
  const stageIndex = (key) => STAGES.findIndex((s) => s.key === key);
  const stageOf = (key) => STAGES[Math.max(0, stageIndex(key))];

  const STAMPS = [
    { key: 'great', emoji: '⭐', label: 'すごい！' },
    { key: 'nice',  emoji: '👍', label: 'いいね' },
    { key: 'fun',   emoji: '🎵', label: 'たのしいね' },
    { key: 'heart', emoji: '❤️', label: 'だいすき' },
  ];
  const stampOf = (k) => STAMPS.find((s) => s.key === k) || STAMPS[0];

  // ---------------- 保存（localStorage） ----------------
  const Store = {
    load(key, def) {
      try { const v = localStorage.getItem('yt_' + key); return v ? JSON.parse(v) : def; }
      catch { return def; }
    },
    save(key, val) { localStorage.setItem('yt_' + key, JSON.stringify(val)); },
  };

  // 音声Blobは IndexedDB に保存（localStorageは容量が小さいため）
  const AudioDB = {
    _db: null,
    open() {
      return new Promise((res, rej) => {
        if (this._db) return res(this._db);
        const r = indexedDB.open('yomitama', 1);
        r.onupgradeneeded = () => r.result.createObjectStore('audio');
        r.onsuccess = () => { this._db = r.result; res(this._db); };
        r.onerror = () => rej(r.error);
      });
    },
    async put(id, blob) {
      const db = await this.open();
      return new Promise((res, rej) => {
        const tx = db.transaction('audio', 'readwrite');
        tx.objectStore('audio').put(blob, id);
        tx.oncomplete = res; tx.onerror = () => rej(tx.error);
      });
    },
    async get(id) {
      const db = await this.open();
      return new Promise((res, rej) => {
        const tx = db.transaction('audio', 'readonly');
        const rq = tx.objectStore('audio').get(id);
        rq.onsuccess = () => res(rq.result); rq.onerror = () => rej(rq.error);
      });
    },
  };

  const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 8);

  // ---------------- 状態 ----------------
  let pet = Store.load('pet', null) || {
    id: 'pet_main', name: 'たまちゃん', stage: 'egg', level: 1, exp: 0,
    friendship: 0, energy: 0, lastReadAt: null, streakDays: 0, evolutionItems: 0,
  };
  let texts = Store.load('texts', []);
  let sessions = Store.load('sessions', []);
  let feedbacks = Store.load('feedbacks', []);

  const savePet = () => Store.save('pet', pet);
  const saveTexts = () => Store.save('texts', texts);
  const saveSessions = () => Store.save('sessions', sessions);
  const saveFeedbacks = () => Store.save('feedbacks', feedbacks);

  // ---------------- 文章ユーティリティ ----------------
  const linesOf = (body) => body.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  const charCount = (body) => body.replace(/\s/g, '').length;
  function splitSentences(body) {
    const out = [];
    for (const line of linesOf(body)) {
      const m = line.match(/[^。．！？!?]+[。．！？!?]?/g) || [line];
      m.forEach((s) => { const t = s.trim(); if (t) out.push(t); });
    }
    return out.length ? out : linesOf(body);
  }

  // ---------------- 育成ロジック ----------------
  const levelForExp = (exp) => Math.floor(exp / 50) + 1;

  function isExtremelyShort(durationSec, chars) {
    if (chars <= 0) return false;
    const expectedMin = chars * 0.08;
    return durationSec < expectedMin * 0.3 && durationSec < 5;
  }
  function baseExp(d) {
    if (d >= 60) return 20;
    if (d >= 30) return 10;
    if (d >= 5) return 5;
    return 2;
  }
  function updateStreak(lastReadAt, current, now) {
    if (!lastReadAt) return 1;
    const last = new Date(lastReadAt); const a = new Date(last.getFullYear(), last.getMonth(), last.getDate());
    const b = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const diff = Math.round((b - a) / 86400000);
    if (diff === 0) return current === 0 ? 1 : current;
    if (diff === 1) return current + 1;
    return 1;
  }
  function applySession(session, text) {
    const now = new Date();
    const lc = linesOf(text.body).length;
    const food = lc > 0 ? lc : 1;
    let exp = baseExp(session.durationSec);
    if (isExtremelyShort(session.durationSec, charCount(text.body))) exp = 2;
    const gotTreasure = session.durationSec >= 180;
    if (gotTreasure) exp += 15;

    const newStreak = updateStreak(pet.lastReadAt, pet.streakDays, now);
    const gotItem = newStreak > 0 && newStreak % 5 === 0;

    const beforeLevel = pet.level;
    const beforeStage = pet.stage;
    pet.exp += exp;
    pet.energy += food;
    pet.streakDays = newStreak;
    pet.lastReadAt = now.toISOString();
    pet.level = levelForExp(pet.exp);
    if (gotItem) pet.evolutionItems += 1;

    // 進化
    let evolved = false;
    let idx = stageIndex(pet.stage);
    while (idx + 1 < STAGES.length && pet.exp >= STAGES[idx + 1].req) { idx++; evolved = true; }
    pet.stage = STAGES[idx].key;

    session.earnedExp = exp;
    session.isCompleted = true;
    sessions.unshift(session);
    saveSessions(); savePet();

    const leveledUp = pet.level > beforeLevel;
    let msg;
    if (evolved) msg = `${pet.name}が ${stageOf(pet.stage).label} に しんかしたよ！`;
    else if (gotTreasure) msg = 'たくさん読めたね！宝箱が ひらいたよ✨';
    else if (leveledUp) msg = 'レベルアップ！ペットがよろこんでる🎉';
    else if (session.durationSec >= 60) msg = '今日もしっかり読めたね！';
    else if (session.durationSec >= 30) msg = 'いい声が聞こえたよ！';
    else msg = '声が聞こえたよ。今日も読めたね！';

    return { earnedExp: exp, earnedFood: food, gotTreasure, leveledUp, evolved,
             newStage: evolved ? pet.stage : null, gotItem, newStreak, message: msg,
             _beforeStage: beforeStage };
  }

  // ---------------- 画面切り替え ----------------
  const screens = {};
  document.querySelectorAll('.screen').forEach((s) => { screens[s.id.replace('screen-', '')] = s; });
  function show(name) {
    Object.values(screens).forEach((s) => s.classList.remove('active'));
    screens[name].classList.add('active');
    if (name === 'home') renderHome();
  }
  const $ = (id) => document.getElementById(id);
  const fmtTime = (sec) => `${String(Math.floor(sec / 60)).padStart(2, '0')}:${String(sec % 60).padStart(2, '0')}`;
  function toast(text) {
    const t = $('toast'); t.textContent = text; t.hidden = false;
    clearTimeout(toast._t); toast._t = setTimeout(() => { t.hidden = true; }, 2200);
  }

  // ---------------- ホーム ----------------
  function renderHome() {
    const st = stageOf(pet.stage);
    $('home-pet-name').textContent = pet.name;
    $('home-pet-sub').textContent = `${st.label}・レベル${pet.level}`;
    $('home-pet').textContent = st.emoji;
    // 経験値バー（現段階内の進捗）
    const next = STAGES[stageIndex(pet.stage) + 1];
    let prog = 1;
    if (next) { const s = st.req, e = next.req; prog = Math.max(0, Math.min(1, (pet.exp - s) / (e - s))); }
    $('home-exp-fill').style.width = (prog * 100) + '%';
    $('home-exp-label').textContent = `けいけんち ${pet.exp}`;
    $('home-food').textContent = pet.energy;
    $('home-streak').textContent = pet.streakDays + '日';
    $('home-friend').textContent = pet.friendship;
  }

  // ---------------- スキャン + OCR ----------------
  let capturedDataUrl = null;
  function resetScan() {
    capturedDataUrl = null;
    $('scan-preview').hidden = true;
    $('scan-placeholder').hidden = false;
    $('scan-after').hidden = true;
    $('scan-progress').hidden = true;
    $('scan-input').value = '';
  }
  $('btn-pick').addEventListener('click', () => $('scan-input').click());
  $('btn-retake').addEventListener('click', resetScan);
  $('scan-input').addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      capturedDataUrl = reader.result;
      $('scan-preview').src = capturedDataUrl;
      $('scan-preview').hidden = false;
      $('scan-placeholder').hidden = true;
      $('scan-after').hidden = false;
    };
    reader.readAsDataURL(file);
  });
  $('btn-ocr').addEventListener('click', runOcr);
  async function runOcr() {
    if (!capturedDataUrl) return;
    $('scan-progress').hidden = false;
    const txt = $('scan-progress-text');
    try {
      const worker = await Tesseract.createWorker('jpn', 1, {
        logger: (m) => {
          if (m.status === 'recognizing text') txt.textContent = `もじを よみとっているよ… ${Math.round(m.progress * 100)}%`;
        },
      });
      const { data } = await worker.recognize(capturedDataUrl);
      await worker.terminate();
      const cleaned = cleanupOcr(data.text || '');
      openEdit({ body: cleaned });
    } catch (err) {
      $('scan-progress').hidden = true;
      toast('よみとりに しっぱい。もう一度ためしてね');
      // 失敗しても手入力で続けられるよう編集画面へ
      openEdit({ body: '' });
    }
  }
  function cleanupOcr(text) {
    const lines = text.split('\n').map((l) => l.replace(/[ \t]+/g, ' ').trim());
    const out = []; let prevEmpty = false;
    for (const l of lines) {
      const empty = l === '';
      if (empty && prevEmpty) continue;
      out.push(l); prevEmpty = empty;
    }
    return out.join('\n').trim();
  }

  // ---------------- OCR編集 ----------------
  let editingId = null;
  function openEdit({ body = '', existing = null }) {
    editingId = existing ? existing.id : null;
    $('edit-title').value = existing ? existing.title : '';
    $('edit-body').value = existing ? existing.body : body;
    show('edit');
  }
  $('btn-split').addEventListener('click', () => {
    $('edit-body').value = splitSentences($('edit-body').value).join('\n');
  });
  function saveText(thenRead) {
    const body = $('edit-body').value.trim();
    if (!body) { toast('よむ ぶんしょうを いれてね'); return null; }
    const title = $('edit-title').value.trim() || 'なまえのない おはなし';
    let t;
    if (editingId) {
      t = texts.find((x) => x.id === editingId);
      t.title = title; t.body = body; t.updatedAt = new Date().toISOString();
    } else {
      t = { id: uid(), title, body, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() };
      texts.unshift(t);
    }
    saveTexts();
    if (thenRead) { startReading(t, false); }
    else { show('home'); toast('ほぞんしたよ！いつでも よめるよ'); }
    return t;
  }
  $('btn-save').addEventListener('click', () => saveText(false));
  $('btn-save-read').addEventListener('click', () => saveText(true));

  // ---------------- 文章えらび ----------------
  function openList(singleLine) {
    if (!texts.length) {
      if (confirm('まだ おはなしが ないよ。\nカメラで つくってみる？')) { resetScan(); show('scan'); }
      return;
    }
    $('list-title').textContent = singleLine ? '1ぎょうだけ よむ' : 'よむ おはなしを えらぶ';
    const wrap = $('list-items'); wrap.innerHTML = '';
    texts.forEach((t) => {
      const div = document.createElement('div');
      div.className = 'list-card';
      div.innerHTML = `<div style="font-size:30px">📖</div>
        <div style="flex:1;min-width:0"><div class="ttl">${esc(t.title)}</div>
        <div class="prev">${esc(t.body.replace(/\n/g, ' '))}</div></div>
        <div style="font-size:32px">▶️</div>`;
      div.addEventListener('click', () => startReading(t, singleLine));
      wrap.appendChild(div);
    });
    show('list');
  }
  const esc = (s) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  // ---------------- 音読 + 録音 ----------------
  let currentText = null, singleLineMode = false, lineIndex = 0;
  let mediaRecorder = null, mediaStream = null, audioCtx = null, analyser = null;
  let chunks = [], recStart = 0, timerInt = null, volRaf = null, currentSession = null;
  let volSamples = [];

  // 音量バーの12本を生成
  const volbar = $('volbar');
  for (let i = 0; i < 12; i++) { const b = document.createElement('i'); b.style.height = (16 + i * 4) + 'px'; volbar.appendChild(b); }

  function startReading(text, single) {
    currentText = text; singleLineMode = single; lineIndex = 0;
    $('read-title').textContent = text.title;
    $('read-pet').textContent = stageOf(pet.stage).emoji;
    $('read-pet').className = 'pet small';
    $('read-cheer').hidden = true;
    $('vol-area').hidden = true;
    $('btn-rec-start').hidden = false;
    renderReadText();
    show('read');
  }
  function renderReadText() {
    const lines = linesOf(currentText.body);
    const nav = $('line-nav');
    if (singleLineMode && lines.length > 1) {
      nav.hidden = false;
      lineIndex = Math.max(0, Math.min(lineIndex, lines.length - 1));
      $('line-indicator').textContent = `${lineIndex + 1} / ${lines.length} 行`;
      $('read-text').textContent = lines[lineIndex] || '';
    } else {
      nav.hidden = true;
      $('read-text').textContent = lines.join('\n');
    }
  }
  $('line-prev').addEventListener('click', () => { lineIndex--; renderReadText(); });
  $('line-next').addEventListener('click', () => { lineIndex++; renderReadText(); });

  $('btn-rec-start').addEventListener('click', startRecording);
  $('btn-finish').addEventListener('click', finishReading);

  async function startRecording() {
    try {
      mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch (e) {
      toast('マイクを つかえるように してね'); return;
    }
    currentSession = { id: uid(), textId: currentText.id, startedAt: new Date().toISOString() };
    chunks = []; volSamples = [];
    mediaRecorder = new MediaRecorder(mediaStream);
    mediaRecorder.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
    mediaRecorder.start();
    recStart = Date.now();

    // 音量メーター
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    const src = audioCtx.createMediaStreamSource(mediaStream);
    analyser = audioCtx.createAnalyser(); analyser.fftSize = 512;
    src.connect(analyser);
    const buf = new Uint8Array(analyser.fftSize);
    const bars = volbar.querySelectorAll('i');
    const loop = () => {
      analyser.getByteTimeDomainData(buf);
      let sum = 0; for (let i = 0; i < buf.length; i++) { const x = (buf[i] - 128) / 128; sum += x * x; }
      const level = Math.min(1, Math.sqrt(sum / buf.length) * 3.2);
      volSamples.push(level);
      const active = Math.round(level * bars.length);
      bars.forEach((b, i) => {
        b.style.background = i < active
          ? `linear-gradient(${getComputedStyle(document.documentElement).getPropertyValue('--secondary')}, var(--primary))`
          : 'rgba(0,0,0,.08)';
      });
      $('vol-text').textContent = level > 0.15 ? 'いい声が きこえてるよ！' : 'こえを きかせてね';
      volRaf = requestAnimationFrame(loop);
    };
    loop();

    timerInt = setInterval(() => {
      $('read-timer').textContent = fmtTime(Math.floor((Date.now() - recStart) / 1000));
    }, 500);

    $('btn-rec-start').hidden = true;
    $('vol-area').hidden = false;
    $('read-cheer').hidden = false;
    $('read-pet').className = 'pet small reading';
    $('read-timer').textContent = '00:00';
  }

  function stopMedia() {
    if (timerInt) clearInterval(timerInt);
    if (volRaf) cancelAnimationFrame(volRaf);
    if (audioCtx) { audioCtx.close().catch(() => {}); audioCtx = null; }
    if (mediaStream) { mediaStream.getTracks().forEach((t) => t.stop()); mediaStream = null; }
  }

  async function finishReading() {
    if (!mediaRecorder) return;
    const durationSec = Math.max(0, Math.floor((Date.now() - recStart) / 1000));
    const avg = volSamples.length ? volSamples.reduce((a, b) => a + b, 0) / volSamples.length : 0;
    const max = volSamples.length ? Math.max(...volSamples) : 0;

    const stopped = new Promise((res) => { mediaRecorder.onstop = res; });
    mediaRecorder.stop();
    await stopped;
    stopMedia();

    const blob = new Blob(chunks, { type: mediaRecorder.mimeType || 'audio/mp4' });
    try { await AudioDB.put(currentSession.id, blob); } catch (e) { /* 保存失敗は無視 */ }

    const session = {
      ...currentSession, endedAt: new Date().toISOString(), durationSec,
      averageVolume: avg, maxVolume: max, hasAudio: blob.size > 0,
      parentApproved: false, earnedExp: 0,
    };
    const result = applySession(session, currentText);
    mediaRecorder = null;
    showResult(result, durationSec);
  }

  // ---------------- 結果 ----------------
  function showResult(r, durationSec) {
    $('result-pet').textContent = stageOf(pet.stage).emoji;
    $('result-pet').className = 'pet happy';
    $('result-msg').textContent = r.message;
    $('result-time').textContent = fmtTime(durationSec);
    $('result-exp').textContent = '+' + r.earnedExp;
    $('result-food').textContent = '+' + r.earnedFood;
    const banners = $('result-banners'); banners.innerHTML = '';
    const addBanner = (text, cls) => { const d = document.createElement('div'); d.className = 'banner ' + (cls || ''); d.textContent = text; banners.appendChild(d); };
    if (r.leveledUp) addBanner('🎊 レベルアップ！ 🎊');
    if (r.evolved && r.newStage) addBanner(`✨ ${stageOf(r.newStage).label} に しんか！ ✨`);
    if (r.gotTreasure) addBanner('🎁 たからばこが ひらいたよ！', 'treasure');
    if (r.gotItem) addBanner('🎁 5日れんぞく！しんかアイテム ゲット！');
    $('result-streak').textContent = `れんぞく ${r.newStreak}日め！`;
    show('result');
  }
  $('btn-result-home').addEventListener('click', () => show('home'));

  // ---------------- 親ゲート ----------------
  let gateA = 0, gateB = 0;
  function openGate() {
    gateA = 3 + Math.floor(Math.random() * 7);
    gateB = 4 + Math.floor(Math.random() * 6);
    $('gate-q').textContent = `${gateA} × ${gateB} = ?`;
    $('gate-input').value = '';
    $('gate-error').hidden = true;
    show('gate');
  }
  $('btn-gate-go').addEventListener('click', () => {
    if (parseInt($('gate-input').value, 10) === gateA * gateB) openParent();
    else $('gate-error').hidden = false;
  });

  // ---------------- 親画面 ----------------
  let parentAudioEl = null, playingId = null;
  function openParent() { renderSessions(); renderStamps(); switchTab('sessions'); show('parent'); }
  function switchTab(tab) {
    document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === tab));
    $('parent-sessions').hidden = tab !== 'sessions';
    $('parent-stamps').hidden = tab !== 'stamps';
  }
  document.querySelectorAll('.tab').forEach((t) => t.addEventListener('click', () => switchTab(t.dataset.tab)));

  function renderSessions() {
    const wrap = $('parent-sessions'); wrap.innerHTML = '';
    if (!sessions.length) { wrap.innerHTML = '<p style="text-align:center">まだ 音読の記録が ありません</p>'; return; }
    sessions.forEach((s) => {
      const text = texts.find((t) => t.id === s.textId);
      const fbs = feedbacks.filter((f) => f.sessionId === s.id);
      const card = document.createElement('div'); card.className = 'p-card';
      const d = new Date(s.startedAt);
      card.innerHTML = `
        <div class="p-top"><span class="p-ttl">${esc(text ? text.title : '（削除された文章）')}</span>
        <span class="p-date">${d.getMonth() + 1}/${d.getDate()} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}</span></div>
        <div class="p-meta"><span>⏱️ ${fmtTime(s.durationSec)}</span><span>⭐ +${s.earnedExp}</span>
        <span>🔊 ${Math.round((s.averageVolume || 0) * 100)}%</span>${s.parentApproved ? '<span>💖 ほめた</span>' : ''}</div>
        ${text ? `<div class="p-body">${esc(text.body)}</div>` : ''}
        <div class="p-actions">
          <button class="mini-btn play" ${s.hasAudio ? '' : 'disabled'} data-play="${s.id}">${s.hasAudio ? '▶ さいせい' : '録音なし'}</button>
          <button class="mini-btn stamp" data-stamp="${s.id}">💖 ほめスタンプ</button>
        </div>
        ${fbs.length ? `<div class="chips">${fbs.map((f) => `<span class="chip">${stampOf(f.stampType).emoji} ${stampOf(f.stampType).label}</span>`).join('')}</div>` : ''}`;
      wrap.appendChild(card);
    });
    wrap.querySelectorAll('[data-play]').forEach((b) => b.addEventListener('click', () => playAudio(b.dataset.play, b)));
    wrap.querySelectorAll('[data-stamp]').forEach((b) => b.addEventListener('click', () => openStampSheet(b.dataset.stamp)));
  }
  async function playAudio(id, btn) {
    if (playingId === id && parentAudioEl) { parentAudioEl.pause(); parentAudioEl = null; playingId = null; btn.textContent = '▶ さいせい'; return; }
    const blob = await AudioDB.get(id);
    if (!blob) { toast('録音が みつかりません'); return; }
    if (parentAudioEl) parentAudioEl.pause();
    parentAudioEl = new Audio(URL.createObjectURL(blob));
    playingId = id; btn.textContent = '⏸ ていし';
    parentAudioEl.onended = () => { btn.textContent = '▶ さいせい'; playingId = null; };
    parentAudioEl.play();
  }

  function renderStamps() {
    const wrap = $('parent-stamps'); wrap.innerHTML = '';
    if (!feedbacks.length) { wrap.innerHTML = '<p style="text-align:center">まだ スタンプは ありません</p>'; return; }
    feedbacks.forEach((f) => {
      const st = stampOf(f.stampType); const d = new Date(f.createdAt);
      const card = document.createElement('div'); card.className = 'p-card';
      card.innerHTML = `<div style="display:flex;align-items:center;gap:12px">
        <span style="font-size:28px">${st.emoji}</span>
        <div style="flex:1"><b>${st.label}</b>${f.comment ? `<div>${esc(f.comment)}</div>` : ''}</div>
        <span class="p-date">${d.getMonth() + 1}/${d.getDate()}</span></div>`;
      wrap.appendChild(card);
    });
  }

  // スタンプ送信シート
  let stampSessionId = null, stampSelected = 'great';
  const sheet = $('stamp-sheet');
  function openStampSheet(sessionId) {
    stampSessionId = sessionId; stampSelected = 'great';
    const wrap = $('stamp-choices'); wrap.innerHTML = '';
    STAMPS.forEach((s) => {
      const b = document.createElement('button');
      b.className = 'stamp-choice' + (s.key === stampSelected ? ' sel' : '');
      b.textContent = `${s.emoji} ${s.label}`;
      b.addEventListener('click', () => { stampSelected = s.key; wrap.querySelectorAll('.stamp-choice').forEach((x) => x.classList.remove('sel')); b.classList.add('sel'); });
      wrap.appendChild(b);
    });
    $('stamp-comment').value = '';
    sheet.hidden = false;
  }
  $('btn-cancel-stamp').addEventListener('click', () => { sheet.hidden = true; });
  $('btn-send-stamp').addEventListener('click', () => {
    feedbacks.unshift({ id: uid(), sessionId: stampSessionId, stampType: stampSelected,
      comment: $('stamp-comment').value.trim(), createdAt: new Date().toISOString() });
    const s = sessions.find((x) => x.id === stampSessionId); if (s) s.parentApproved = true;
    pet.friendship += 1;
    saveFeedbacks(); saveSessions(); savePet();
    sheet.hidden = true;
    toast('スタンプを おくったよ！なかよし度アップ💖');
    renderSessions(); renderStamps();
  });

  // ---------------- ナビゲーション結線 ----------------
  $('btn-parent').addEventListener('click', openGate);
  $('btn-scan').addEventListener('click', () => { resetScan(); show('scan'); });
  $('btn-read').addEventListener('click', () => openList(false));
  $('btn-read-line').addEventListener('click', () => openList(true));
  document.querySelectorAll('[data-back]').forEach((b) => b.addEventListener('click', () => { stopMedia(); show(b.dataset.back); }));

  // 起動
  show('home');
})();
