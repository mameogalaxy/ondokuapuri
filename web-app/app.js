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
  let ocrVertical = false; // 縦書きモード（教科書は縦書きが多い）
  function resetScan() {
    capturedDataUrl = null;
    $('scan-preview').hidden = true;
    $('scan-placeholder').hidden = false;
    $('scan-after').hidden = true;
    $('writing-toggle').hidden = true;
    $('scan-progress').hidden = true;
    $('scan-input').value = '';
  }
  $('btn-pick').addEventListener('click', () => $('scan-input').click());
  $('btn-retake').addEventListener('click', resetScan);
  // 縦書き／横書きの切り替え
  document.querySelectorAll('#writing-toggle .wt-btn').forEach((b) => {
    b.addEventListener('click', () => {
      ocrVertical = b.dataset.dir === 'v';
      document.querySelectorAll('#writing-toggle .wt-btn').forEach((x) => x.classList.toggle('active', x === b));
    });
  });
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
      $('writing-toggle').hidden = false;
    };
    reader.readAsDataURL(file);
  });
  $('btn-ocr').addEventListener('click', runOcr);
  async function runOcr() {
    if (!capturedDataUrl) return;
    $('scan-progress').hidden = false;
    const txt = $('scan-progress-text');
    const lang = ocrVertical ? 'jpn_vert' : 'jpn';
    try {
      // 画像を前処理（拡大・グレースケール・コントラスト）して精度を上げる
      const processed = await preprocessImage(capturedDataUrl);
      const worker = await Tesseract.createWorker(lang, 1, {
        logger: (m) => {
          if (m.status === 'recognizing text') txt.textContent = `もじを よみとっているよ… ${Math.round(m.progress * 100)}%`;
        },
      });
      // 縦書きは縦1ブロック(5)、横書きは自動(3)。日本語は単語間スペース不要。
      await worker.setParameters({
        tessedit_pageseg_mode: ocrVertical ? '5' : '3',
        preserve_interword_spaces: '0',
      });
      const { data } = await worker.recognize(processed);
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

  // 画像前処理：大きすぎる画像を適度に縮小し、グレースケール＋コントラスト強調
  function preprocessImage(dataUrl) {
    return new Promise((resolve) => {
      const img = new Image();
      img.onload = () => {
        try {
          const maxW = 1600;
          const scale = img.width > maxW ? maxW / img.width : 1;
          const w = Math.round(img.width * scale);
          const h = Math.round(img.height * scale);
          const canvas = document.createElement('canvas');
          canvas.width = w; canvas.height = h;
          const ctx = canvas.getContext('2d');
          ctx.drawImage(img, 0, 0, w, h);
          const imgData = ctx.getImageData(0, 0, w, h);
          const d = imgData.data;
          for (let i = 0; i < d.length; i += 4) {
            // グレースケール
            let g = d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114;
            // コントラスト強調
            g = (g - 128) * 1.4 + 128;
            g = g < 0 ? 0 : g > 255 ? 255 : g;
            d[i] = d[i + 1] = d[i + 2] = g;
          }
          ctx.putImageData(imgData, 0, 0);
          resolve(canvas.toDataURL('image/png'));
        } catch (e) {
          resolve(dataUrl); // 失敗時は元画像
        }
      };
      img.onerror = () => resolve(dataUrl);
      img.src = dataUrl;
    });
  }

  function cleanupOcr(text) {
    let lines = text.split('\n').map((l) => l.replace(/[ \t]+/g, ' ').trim());
    const out = []; let prevEmpty = false;
    for (const l of lines) {
      const empty = l === '';
      if (empty && prevEmpty) continue;
      out.push(l); prevEmpty = empty;
    }
    let joined = out.join('\n');
    // 日本語の文字どうしの間に入った余分なスペースを除去（例:「今 日 は」→「今日は」）
    // 両隣が非ASCII（＝日本語）のときだけスペースを削る。英単語の間隔は残す。
    for (let i = 0; i < 3; i++) {
      joined = joined.replace(/([^\x00-\x7F])[\x20\u3000]+([^\x00-\x7F])/g, '$1$2');
    }
    return joined.trim();
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
        <button class="del-btn" title="さくじょ">🗑️</button>
        <div style="font-size:32px">▶️</div>`;
      div.addEventListener('click', () => startReading(t, singleLine));
      // 削除ボタン（カードのタップとは分離）
      div.querySelector('.del-btn').addEventListener('click', (e) => {
        e.stopPropagation();
        if (confirm(`「${t.title}」を さくじょしますか？`)) {
          deleteText(t.id);
          openList(singleLine); // 再描画
        }
      });
      wrap.appendChild(div);
    });
    show('list');
  }
  function deleteText(id) {
    texts = texts.filter((t) => t.id !== id);
    saveTexts();
  }
  const esc = (s) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  // ---------------- 音読 + 録音 ----------------
  let currentText = null, singleLineMode = false, lineIndex = 0;
  let mediaStream = null, audioCtx = null, analyser = null;
  let recStart = 0, timerInt = null, volRaf = null, currentSession = null;
  let volSamples = [];
  // 読み上げハイライト用
  let highlightSpans = [];   // {el, matchable}
  let matchableTarget = [];  // 照合用：正規化した文字（句読点・空白を除く）
  let recognition = null, recognizing = false, finalTranscript = '';

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
    let displayText;
    if (singleLineMode && lines.length > 1) {
      nav.hidden = false;
      lineIndex = Math.max(0, Math.min(lineIndex, lines.length - 1));
      $('line-indicator').textContent = `${lineIndex + 1} / ${lines.length} 行`;
      displayText = lines[lineIndex] || '';
    } else {
      nav.hidden = true;
      displayText = lines.join('\n');
    }
    // 1文字ずつ <span> に分割（読み上げに合わせて色をつけるため）
    const el = $('read-text');
    el.innerHTML = '';
    highlightSpans = []; matchableTarget = [];
    for (const ch of displayText) {
      if (ch === '\n') { el.appendChild(document.createElement('br')); continue; }
      const span = document.createElement('span');
      span.textContent = ch;
      el.appendChild(span);
      const matchable = isMatchable(ch);
      highlightSpans.push({ el: span, matchable });
      if (matchable) matchableTarget.push(normCh(ch));
    }
  }

  // 照合対象の文字か（句読点・空白・記号は除く）
  function isMatchable(ch) {
    if (/\s/.test(ch)) return false;
    return !/[、。，．・「」『』（）()！？!?…—〜~"'：；:;]/.test(ch);
  }
  // 正規化：カタカナ→ひらがな、英字は小文字に
  function normCh(ch) {
    const code = ch.charCodeAt(0);
    if (code >= 0x30a1 && code <= 0x30f6) ch = String.fromCharCode(code - 0x60);
    return ch.toLowerCase();
  }
  // 認識した読み上げテキストを文章と前から照合し、読めた文字数を色づけする
  function updateHighlightFromTranscript(transcript) {
    if (!matchableTarget.length) return;
    const t = [];
    for (const ch of transcript) { if (isMatchable(ch)) t.push(normCh(ch)); }
    let i = 0, j = 0;
    while (i < matchableTarget.length && j < t.length) {
      if (matchableTarget[i] === t[j]) { i++; j++; } else { j++; }
    }
    highlightByCount(i);
  }

  // 「読めた文字数」ぶんだけ色をつける（声に合わせて前から進む）
  function highlightByCount(matched) {
    if (!highlightSpans.length) return;
    matched = Math.max(0, Math.min(matched, matchableTarget.length));
    let mcount = 0, until = -1;
    for (let k = 0; k < highlightSpans.length; k++) {
      if (highlightSpans[k].matchable) {
        if (mcount < matched) { until = k; mcount++; } else break;
      } else if (mcount > 0 && mcount < matched) {
        until = k; // 読んだ文字の間にある句読点も色づけ
      }
    }
    for (let k = 0; k < highlightSpans.length; k++) {
      highlightSpans[k].el.classList.toggle('read-hl', k <= until);
    }
    const progress = matchableTarget.length ? matched / matchableTarget.length : 0;
    if (progress >= 0.98) $('read-cheer').textContent = 'ぜんぶ よめたね！すごい！';
    else if (progress > 0.05) $('read-cheer').textContent = 'いいちょうし！よめてるよ';
  }
  $('line-prev').addEventListener('click', () => { lineIndex--; renderReadText(); });
  $('line-next').addEventListener('click', () => { lineIndex++; renderReadText(); });

  $('btn-rec-start').addEventListener('click', startRecording);
  // iOSでのタップ取りこぼし対策に click と touchend の両方を購読（多重実行はガード済み）
  $('btn-finish').addEventListener('click', finishReading);
  $('btn-finish').addEventListener('touchend', (e) => { e.preventDefault(); finishReading(); });

  let reading = false;

  // 音声認識（読んだ言葉を文字化して、文章と照合・色づけ）
  function startRecognition() {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SR) return false;
    try {
      recognition = new SR();
      recognition.lang = 'ja-JP';
      recognition.continuous = true;
      recognition.interimResults = true;
      finalTranscript = '';
      recognition.onresult = (e) => {
        let interim = '';
        for (let k = e.resultIndex; k < e.results.length; k++) {
          const r = e.results[k];
          if (r.isFinal) finalTranscript += r[0].transcript;
          else interim += r[0].transcript;
        }
        updateHighlightFromTranscript(finalTranscript + interim);
      };
      recognition.onerror = () => {};
      recognition.onend = () => { if (recognizing) { try { recognition.start(); } catch (_) {} } };
      recognition.start();
      recognizing = true;
      return true;
    } catch (_) { recognition = null; return false; }
  }
  function stopRecognition() {
    recognizing = false;
    if (recognition) { try { recognition.stop(); } catch (_) {} recognition = null; }
  }

  // 音声認識が使えない端末向けフォールバック：声の「区切り」でハイライトを進める
  async function startVoiceFallback() {
    try {
      mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch (e) { toast('マイクを つかえるように してね'); return false; }
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    if (audioCtx.state === 'suspended') { try { await audioCtx.resume(); } catch (_) {} }
    const src = audioCtx.createMediaStreamSource(mediaStream);
    analyser = audioCtx.createAnalyser(); analyser.fftSize = 512;
    src.connect(analyser);
    const buf = new Uint8Array(analyser.fftSize);
    let onsets = 0, wasAbove = false, belowSince = performance.now();
    const VOICE_THRESHOLD = 0.12, GAP_MS = 80, CHARS_PER_ONSET = 1.6;
    const loop = () => {
      analyser.getByteTimeDomainData(buf);
      let sum = 0; for (let i = 0; i < buf.length; i++) { const x = (buf[i] - 128) / 128; sum += x * x; }
      const level = Math.min(1, Math.sqrt(sum / buf.length) * 3.2);
      const now = performance.now();
      const above = level > VOICE_THRESHOLD;
      if (above && !wasAbove && (now - belowSince) > GAP_MS) onsets++;
      if (!above && wasAbove) belowSince = now;
      wasAbove = above;
      highlightByCount(Math.round(onsets * CHARS_PER_ONSET));
      volRaf = requestAnimationFrame(loop);
    };
    loop();
    return true;
  }

  async function startRecording() {
    finishing = false;
    currentSession = { id: uid(), textId: currentText.id, startedAt: new Date().toISOString() };
    volSamples = [];
    renderReadText();
    recStart = Date.now();

    // まず音声認識を試す。使えない端末は声の区切り方式にフォールバック。
    let mode = 'speech';
    if (!startRecognition()) {
      const ok = await startVoiceFallback();
      if (!ok) return; // マイク不可
      mode = 'voice';
    }

    $('read-cheer').textContent = mode === 'speech'
      ? 'こえを きかせてね！よんだ ところに いろが つくよ'
      : 'こえを だすと 文字に いろが ついていくよ！';
    $('vol-text').textContent = '🎤 きいているよ…';

    timerInt = setInterval(() => {
      $('read-timer').textContent = fmtTime(Math.floor((Date.now() - recStart) / 1000));
    }, 500);

    reading = true;
    $('btn-rec-start').hidden = true;
    $('vol-area').hidden = false;
    $('volbar').hidden = true; // 録音なしのため音量バーは非表示（聞いている表示のみ）
    $('read-cheer').hidden = false;
    $('read-pet').className = 'pet small reading';
    $('read-timer').textContent = '00:00';
  }

  function stopMedia() {
    stopRecognition();
    if (timerInt) clearInterval(timerInt);
    if (volRaf) cancelAnimationFrame(volRaf);
    if (audioCtx) { audioCtx.close().catch(() => {}); audioCtx = null; }
    if (mediaStream) { mediaStream.getTracks().forEach((t) => t.stop()); mediaStream = null; }
  }

  let finishing = false;
  function finishReading() {
    // 開始していない／すでに終了処理中なら何もしない（多重実行ガード）
    if (finishing || !currentSession) return;
    finishing = true;
    reading = false;

    const durationSec = Math.max(0, Math.floor((Date.now() - recStart) / 1000));
    let matched = 0;
    for (const s of highlightSpans) { if (s.matchable && s.el.classList.contains('read-hl')) matched++; }
    const progress = matchableTarget.length ? matched / matchableTarget.length : 0;

    // マイク・認識を止める（ここで例外が出ても結果表示は必ず行う）
    try { stopMedia(); } catch (_) {}

    try {
      const session = {
        ...currentSession, endedAt: new Date().toISOString(), durationSec,
        averageVolume: progress, maxVolume: progress, hasAudio: false,
        parentApproved: false, earnedExp: 0,
      };
      const result = applySession(session, currentText);
      showResult(result, durationSec);
    } catch (e) {
      show('home'); // 万一失敗してもホームに戻して操作不能を防ぐ
    }
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
        <span>📖 よめた ${Math.round((s.averageVolume || 0) * 100)}%</span>${s.parentApproved ? '<span>💖 ほめた</span>' : ''}</div>
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

  // Service Worker を登録（ホーム画面アプリでも更新が届くように）
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('sw.js').then((reg) => {
        // 新しいバージョンを見つけたら取り込む
        reg.addEventListener('updatefound', () => {
          const sw = reg.installing;
          if (!sw) return;
          sw.addEventListener('statechange', () => {
            if (sw.state === 'installed' && navigator.serviceWorker.controller) {
              // 既存ページがある状態で更新が入った→次回以降は最新
            }
          });
        });
      }).catch(() => {});
    });
  }
})();
