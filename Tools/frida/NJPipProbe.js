/*
 * NJPipProbe.js — passive in-process observer of the bilibili live PiP pipeline.
 *
 * Runs inside frida-gadget 17.24.3 in "script" interaction mode, i.e. it is
 * executed automatically at dylib load; it never waits for an external
 * connection. It only RECORDS: it never changes arguments, return values or
 * objects, and every failure is swallowed so the host app cannot crash.
 *
 * Output: NDJSON appended to <NSHomeDirectory()>/Library/NJPiPProbe.ndjson,
 * one JSON object per line: {"ts":<ms>,"v":<probe version>,"ev":"<event>","d":{...}}
 * Every line is hard-capped at 400 characters (over-long payloads are replaced
 * with a {"tr":1,...} stub). High-frequency methods are counted only; a per-30s
 * "cnt" summary reports the counters instead of per-call lines.
 *
 * v2 (nj-pip-probe-2): display-path forensics for the native-overlay test:
 *   A) SBDL vs Metal: IJKSDLSampleBufferView -display_pixels, _vtb, _ffmpeg and
 *      -enqueueSmapleBuffer: counts + first-arg types + instance layer class +
 *      +layerClass; BFCCRONRenderViewV2 instantiation + backing layer class
 *      (_displayLayer); BFCPlayerSampleBufferView / IJKSampleBufferWrapView
 *      instantiation + getCurrentRenderer/switchRenderer:.
 *   B) PiP instance identity: -[AVSampleBufferDisplayLayer enqueueSampleBuffer:]
 *      counted per layer address with first-3 superlayer + backtrace samples;
 *      -[BFCPlayerControllerV2 sampleBufferDisplayLayer] return addresses;
 *      generateContentSourceWithCompletionHandler: on BBPlayerPlayback and
 *      BFCPlayerControllerV2; ContentSource -initWithSampleBufferDisplayLayer:
 *      playbackDelegate:; -[BBPiPController setContentSource:].
 *   C) danmaku carrier: -didMoveToWindow watchlist over the DM view classes
 *      recording backing layer + sublayer class names;
 *      BFCChronosRendererWrapper instantiation (via state snapshots) and
 *      -copyPixelBuffer counts (never invoked by the probe itself).
 *
 * v3 (nj-pip-probe-3): the runtime gates, read from one real-device run. All
 * targets are ObjC method names (8.89 static forensics said where the gates
 * are; the probe reads what they actually do):
 *   G1) sbp_view_visible: -[IJKSDLSampleBufferView visible] — display_pixels_vtb:
 *      calls [self visible] then cbz (no frames fed when NO). All calls are
 *      counted; one line per 5s or on a value flip, with the layer addr + value.
 *   G2) sbp_layer_state: every 5s, per live AVSampleBufferDisplayLayer:
 *      status + isReadyForMoreMediaData + the enqueueSampleBuffer: frame rate
 *      (delta of the v2 per-address counter). enqueueSmapleBuffer: consults
 *      isReadyForMoreMediaData (tbz → frames skipped); that selector itself is
 *      count-only here (hook_miss if the class lacks it).
 *   G3) cron_gate: -[BFCCRONRenderBaseView updateGpuState] (reads
 *      applicationState → setGpuAccessAllowed:NO), -updateDisplayLinkState
 *      (no window / empty frame → setPaused:YES) and -didMoveToWindow: one
 *      line per 5s per key: appState, gpuAllowed (ivar / setGpuAccessAllowed:
 *      argument, best effort), paused, window?, frame w/h.
 *   G4) dm_pixfmt: -[BFCChronosRendererWrapper copyPixelBuffer] keeps the v2
 *      count; at most once per 5s the returned pointer is handed straight to
 *      CVPixelBufferGetPixelFormatType — raw pointer only, never wrapped,
 *      retained or released, so the buffer's lifetime is untouched — and the
 *      fourcc is decoded to text.
 *   G5) pip_route: -[BBPiPController setContentSource:],
 *      -[BFCPlayerControllerV2 generateContentSourceWithCompletionHandler:]
 *      and ContentSource -initWithSampleBufferDisplayLayer:playbackDelegate:
 *      ⇒ sb; -[AVPlayerItem setCustomVideoCompositor:] and
 *      -[AVPlayerLayer setVideoGravity:] ⇒ avplayer. One line per evidence
 *      kind (30s repeat throttle). pip_playerview:
 *      BBPictureInPicture.PlayerView +layerClass + live instance count.
 *   G6) defensive: a v3 target whose class never appears, or whose class is
 *      present while the selector is not, logs exactly one hook_miss line with
 *      its name; nothing throws into the host. probe_boot reports the version
 *      and the number of mounted hook points (probe_ready once polling ends).
 *   Volume: every new state line is throttled to ≤ 1 per 5s per key, hot paths
 *   stay count-only, so total output stays well under 200 lines/minute.
 *
 * v4 (nj-pip-probe-4): the ONLINE danmaku render chain, which the v2/v3
 * targets never reached (they only ever saw the recording path's
 * BBPlayerDanmakuVoutView). 8.89 statics put the online renderer behind the
 * player context, and no probe line had ever confirmed it:
 *   H1) cron_chain: once per PiP entry, walk the live BBPlayerDanmakuService →
 *       context → chronos → chronosView → rendererWrapper chain and report one
 *       line per hop (class + address), ending with copy/sync = whether the
 *       final object answers copyPixelBuffer / updateSyncForTimeStep:. A
 *       failure names the hop that broke. H1 itself never calls the renderer.
 *   H2) cron_dm_poll: only while PiP is active and H1 resolved, ask that
 *       wrapper for a frame every 2s (copyPixelBuffer ONLY — updateSync would
 *       advance the engine's own clock) and compare the returned pointer with
 *       the previous one: changed=1 means a new danmaku buffer appeared, a
 *       repeated pointer means the image is frozen. Lines go out on a state
 *       change plus one keep-alive per 30s. The +1 buffer is released with
 *       CFRelease on every poll; the wrapper is retained only for the duration
 *       of the poll. stopPictureInPicture ends the poll.
 *   H3) ext_pixelbuf: count -[BFCCRONRenderBaseView setExternalPixelBuffer:]
 *       (the door a decoded-video buffer would be pushed through) and report at
 *       most one line per 30s, only when the count moved. If the class has no
 *       such selector, one hook_miss line says so and nothing else happens.
 *   H1/H2/H3 measure only: no argument, return value or object state is changed,
 *   and every path is wrapped so nothing throws into the host.
 *
 * v5 (nj-pip-probe-5): the mixed-offscreen candidate (third PiP path,借官方
 * 离屏混合渲染取帧). Same passive rules: measure only, never change arguments,
 * returns or objects; everything wrapped.
 *   I1) mx_probe: on the H1 chain walk, at the chronosView hop, one extra line
 *       with the REAL cron view class name (BFCCRONRenderView vs …V2 — the
 *       AB pick is runtime-only) plus responds bits for the three offscreen
 *       entry points: gmi = -getMixedImage on the view, gri = -getRendererImage
 *       on the view, omi = -offscreenMixedImage on the chronos object of the
 *       same chain. Responds checks only; nothing is called, no image is made.
 *       If the chain breaks after the view hop the line is still emitted.
 *   I2) mx_alive: while the H2 poll runs, once per 30s ask the retained
 *       chronos object for its current chronosView again (same getter H1
 *       already walks) and compare the pointer with the one I1 saw:
 *       same=0 means the app swapped views mid-PiP; win reports whether that
 *       view has a window (window=0 means its own display link is paused, so
 *       its textures would be frozen). The chronos pointer is retained by the
 *       probe and released when the chain is released; the view pointer from
 *       the re-read is never retained.
 *
 * No Node.js APIs, no require, no process — Frida/ObjC bridge + NativeFunction only.
 */
(function () {
  'use strict';

  var PROBE_VERSION = 'nj-pip-probe-5';
  var PROBE_V = 5;
  var MAX_LINE = 400;

  // ---------------------------------------------------------------------------
  // native export lookup (compatible across Frida API generations)
  // ---------------------------------------------------------------------------
  function findExport(moduleName, symbolName) {
    try {
      if (moduleName && Process.findModuleByName) {
        var m = Process.findModuleByName(moduleName);
        if (m && m.findExportByName) {
          var e = m.findExportByName(symbolName);
          if (e !== null && e !== undefined) return e;
        }
      }
    } catch (e0) {}
    try {
      if (Module.findGlobalExportByName) {
        var g = Module.findGlobalExportByName(symbolName);
        if (g !== null && g !== undefined) return g;
      }
    } catch (e1) {}
    try {
      if (typeof Module.findExportByName === 'function') {
        return Module.findExportByName(moduleName, symbolName);
      }
    } catch (e2) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // file output via libsystem_kernel open/write/close (POSIX flags are the
  // Darwin ones: O_WRONLY=2, O_CREAT=0x200, O_APPEND=0x8)
  // ---------------------------------------------------------------------------
  var O_WRONLY = 2, O_CREAT = 0x200, O_APPEND = 0x8, MODE_0644 = 0x1a4;
  var sysOpen = null, sysWrite = null, sysClose = null, nsHomeDirectory = null;
  try {
    sysOpen = new NativeFunction(findExport('libsystem_kernel.dylib', 'open'), 'int', ['pointer', 'int', 'int']);
    sysWrite = new NativeFunction(findExport('libsystem_kernel.dylib', 'write'), 'long', ['int', 'pointer', 'uint']);
    sysClose = new NativeFunction(findExport('libsystem_kernel.dylib', 'close'), 'int', ['int']);
    nsHomeDirectory = new NativeFunction(findExport('Foundation', 'NSHomeDirectory'), 'pointer', []);
  } catch (e) {
    sysOpen = null;
  }

  var probePath = null;

  function resolveProbePath() {
    if (probePath !== null) return probePath;
    try {
      var home = new ObjC.Object(nsHomeDirectory()).toString();
      if (home === null || home.length === 0) return null;
      probePath = home + '/Library/NJPiPProbe.ndjson';
    } catch (e) {
      return null;
    }
    return probePath;
  }

  function appendLine(obj) {
    try {
      if (sysOpen === null || sysWrite === null || sysClose === null) return;
      var path = resolveProbePath();
      if (path === null) return;
      var body;
      try { body = JSON.stringify(obj); } catch (e0) { return; }
      if (body.length > MAX_LINE) {
        // every record must stay <= 400 chars: keep the envelope, stub the data
        try {
          body = JSON.stringify({ ts: obj.ts, v: obj.v, ev: obj.ev, tr: 1, d: trunc(JSON.stringify(obj.d), 240) });
        } catch (e1) {
          body = body.substring(0, MAX_LINE);
        }
      }
      body += '\n';
      var buf = Memory.allocUtf8String(body);
      var fd = sysOpen(Memory.allocUtf8String(path), O_WRONLY | O_CREAT | O_APPEND, MODE_0644);
      if (fd < 0) return; // 'int' return type gives a plain JS number
      sysWrite(fd, buf, body.length);
      sysClose(fd);
    } catch (e) {
      // never propagate
    }
  }

  function log(ev, d) {
    appendLine({ ts: Date.now(), v: PROBE_V, ev: ev, d: (d === undefined) ? null : d });
  }

  // ---------------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------------
  function findClass(name) {
    try {
      var c = ObjC.classes[name];
      return c || null;
    } catch (e) {
      return null;
    }
  }

  function trunc(s, n) {
    try {
      if (s === null || s === undefined) return null;
      s = String(s);
      var limit = n || 240;
      return s.length > limit ? s.substring(0, limit) + '…' : s;
    } catch (e) {
      return null;
    }
  }

  function safeDescribe(o) {
    try { return trunc(o.toString(), 200); } catch (e) { return null; }
  }

  // class name of a bridged value (ObjC.Object) or null for nil
  function classNameOf(v) {
    try {
      if (v === null || v === undefined) return null;
      if (typeof v.isNull === 'function' && v.isNull()) return null;
      if (v.class !== undefined) return v.class.toString();
      return null;
    } catch (e) {
      return null;
    }
  }

  // address + class of a raw pointer argument / native value, or null for nil
  function objInfo(p) {
    try {
      if (p === null || p === undefined) return null;
      var po = (p instanceof NativePointer) ? p : new NativePointer(p);
      if (po.isNull()) return null;
      var o = new ObjC.Object(po);
      return { addr: po.toString(), cls: o.class.toString() };
    } catch (e) {
      return null;
    }
  }

  // read a property / no-arg method through the bridge; returns {cls: ...} info
  function readObjProp(receiver, getterSel) {
    try {
      if (!receiver.respondsToSelector_(getterSel)) return { present: false };
      var v = receiver[getterSel]();
      return { present: true, cls: classNameOf(v), nil: (v === null || v === undefined) };
    } catch (e) {
      return { present: true, error: trunc(e.message || ('' + e), 120) };
    }
  }

  function callBool(obj, sel) {
    try {
      if (!obj.respondsToSelector_(sel)) return null;
      return !!obj[sel]();
    } catch (e) {
      return null;
    }
  }

  function callNumber(obj, sel) {
    try {
      if (!obj.respondsToSelector_(sel)) return null;
      var r = obj[sel]();
      if (r === null || r === undefined) return null;
      return Number(r);
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CoreMedia helpers for AVSampleBufferDisplayLayer.timebase
  // ---------------------------------------------------------------------------
  var CMTimebaseGetRate = null, CMTimebaseGetTime = null;
  try {
    var rateAddr = findExport('CoreMedia', 'CMTimebaseGetRate');
    var timeAddr = findExport('CoreMedia', 'CMTimebaseGetTime');
    if (rateAddr) CMTimebaseGetRate = new NativeFunction(rateAddr, 'double', ['pointer']);
    if (timeAddr) {
      // struct CMTime { int64_t value; int32_t timescale; uint32_t flags; int32_t epoch; }
      CMTimebaseGetTime = new NativeFunction(timeAddr, {
        fields: [
          { name: 'value', type: 'int64' },
          { name: 'timescale', type: 'int32' },
          { name: 'flags', type: 'uint32' },
          { name: 'epoch', type: 'int32' }
        ]
      }, ['pointer']);
    }
  } catch (e) {}

  function timebaseInfoOf(layer) {
    var out = {};
    try {
      // timebase is a CMTimebaseRef; KVC usually hands back an NSValue holding the pointer
      var tbVal = layer.valueForKey_('timebase');
      if (tbVal === null || tbVal === undefined) return null;
      var p = null;
      try {
        p = tbVal.pointerValue();
      } catch (e0) {
        try { p = tbVal.handle; } catch (e1) { p = null; }
      }
      if (p === null || p === undefined) return null;
      if (!(p instanceof NativePointer)) {
        try { p = new NativePointer(p); } catch (eN) { return null; }
      }
      if (p.isNull()) return null;
      out.timebase = p.toString();
      if (CMTimebaseGetRate !== null) {
        try { out.rate = CMTimebaseGetRate(p); } catch (e2) { out.rate = null; }
      }
      if (CMTimebaseGetTime !== null) {
        try {
          var t = CMTimebaseGetTime(p);
          out.time = {
            value: t.value.toString(),
            timescale: t.timescale,
            flags: t.flags,
            epoch: t.epoch
          };
        } catch (e3) {
          out.time = null;
        }
      }
      return out;
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // dumpState — snapshot of live objects and their state.
  // v2: one bounded line per class ("state") plus per-instance detail lines
  // ("state1") for the interesting classes, so every record stays under the cap.
  // ---------------------------------------------------------------------------
  var SNAPSHOT_CLASSES = [
    'BBSBPiPManager',
    'BBAVPiPManager',
    'PictureInPictureControllerWrapper',
    'AVPictureInPictureController',
    'AVSampleBufferDisplayLayer',
    'BBPlayerDanmakuService',
    'BBPlayerDanmakuVoutView',
    'BBPlayerChronosContainerView',
    // v2 additions
    'BFCPlayerControllerV2',
    'BBPlayerPlayback',
    'BBPiPController',
    'BFCCRONRenderViewV2',
    'IJKSDLSampleBufferView',
    'BFCPlayerSampleBufferView',
    'IJKSampleBufferWrapView',
    'BFCChronosRendererWrapper',
    'BBPlayerDMView',
    'BFCPlayerDMView',
    'DMRenderLayerView',
    // v3: the PiP host view — instance count over time (its layer class is
    // reported once by the pvp probe)
    'BBPictureInPicture.PlayerView'
  ];

  function snapshotOnePiP(o) {
    var d = { addr: o.handle.toString() };
    d.possible = callBool(o, 'isPictureInPicturePossible');
    d.active = callBool(o, 'isPictureInPictureActive');
    d.suspended = callBool(o, 'isPictureInPictureSuspended');
    d.contentSource = readObjProp(o, 'contentSource');
    d.sampleBufferPlaybackDelegate = readObjProp(o, 'sampleBufferPlaybackDelegate');
    d.contentViewController = readObjProp(o, 'contentViewController');
    d.hostingView = readObjProp(o, 'hostingView');
    d.sourceViewProvider = readObjProp(o, 'sourceViewProvider');
    return d;
  }

  function snapshotOneLayer(o) {
    var d = { addr: o.handle.toString() };
    d.status = callNumber(o, 'status');
    try {
      var et = o.valueForKey_('endTime');
      d.endTime = (et === null || et === undefined) ? null : safeDescribe(et);
    } catch (e) {
      d.endTime = null;
    }
    d.timebase = timebaseInfoOf(o);
    try {
      var sl = o.superlayer();
      d.superlayer = (sl === null || sl === undefined) ? null : { cls: classNameOf(sl) };
      if (d.superlayer !== null) {
        try { d.superlayer.delegate = classNameOf(sl.delegate()); } catch (e1) { d.superlayer.delegate = null; }
      }
    } catch (e2) {
      d.superlayer = null;
    }
    try { d.delegate = classNameOf(o.delegate()); } catch (e3) { d.delegate = null; }
    try { d.sublayerCount = o.sublayers().count(); } catch (e4) { d.sublayerCount = null; }
    return d;
  }

  function snapshotOneDanmakuService(o) {
    var d = { addr: o.handle.toString() };
    try {
      if (o.respondsToSelector_('view')) {
        var v = o.view();
        if (v !== null && v !== undefined) {
          d.viewClass = v.class.toString();
          try {
            var f = v.frame();
            d.frame = (typeof f === 'object') ? f : trunc('' + f, 120);
          } catch (e1) {
            d.frame = null;
          }
          try {
            var l = v.layer();
            d.layerClass = l.class.toString();
            try { d.sublayerCount = l.sublayers().count(); } catch (e2) { d.sublayerCount = null; }
          } catch (e3) {
            d.layerClass = null;
          }
        }
      }
    } catch (e4) {
      d.viewClass = null;
    }
    d.currentTime = callNumber(o, 'currentTime');
    d.playbackRate = callNumber(o, 'playbackRate');
    return d;
  }

  function dumpState(tag) {
    try {
      for (var i = 0; i < SNAPSHOT_CLASSES.length; i++) {
        var name = SNAPSHOT_CLASSES[i];
        try {
          var cls = findClass(name);
          if (cls === null) {
            log('state', { tag: tag, cls: name, registered: false });
            continue;
          }
          var instances = ObjC.chooseSync(cls);
          var addrs = [];
          for (var j = 0; j < instances.length && j < 6; j++) {
            addrs.push(instances[j].handle.toString());
          }
          log('state', { tag: tag, cls: name, registered: true, count: instances.length, addrs: addrs });
          var detailFn = null;
          if (name === 'AVPictureInPictureController' && instances.length <= 8) detailFn = snapshotOnePiP;
          else if (name === 'AVSampleBufferDisplayLayer' && instances.length <= 16) detailFn = snapshotOneLayer;
          else if (name === 'BBPlayerDanmakuService' && instances.length <= 8) detailFn = snapshotOneDanmakuService;
          if (detailFn !== null) {
            for (var k = 0; k < instances.length; k++) {
              try { log('state1', { tag: tag, cls: name, d: detailFn(instances[k]) }); }
              catch (e1) { log('state1', { tag: tag, cls: name, error: trunc(e1.message || ('' + e1), 100) }); }
            }
          }
        } catch (e) {
          log('state', { tag: tag, cls: name, error: trunc(e.message || ('' + e), 120) });
        }
      }
    } catch (e) {
      log('state_error', { tag: tag, error: trunc(e.message || ('' + e), 200) });
    }
  }

  // expose a manual entry point (useful if this is ever switched to connect mode)
  try {
    globalThis.njDumpState = dumpState;
    globalThis.njProbeLog = log;
    globalThis.njCronResolve = resolveCronChain; // v4 H1: re-resolve on demand
    globalThis.njCronPoll = function (on) { if (on) startCronPoll(); else stopCronPoll(); };
  } catch (e) {}

  // ---------------------------------------------------------------------------
  // one-time fuzzy class-name listing
  // ---------------------------------------------------------------------------
  var classesEventSent = false;

  function listInterestingClasses() {
    if (classesEventSent) return;
    try {
      var names = Object.keys(ObjC.classes);
      var pats = [
        'PlayerContainer', 'BBPictureInPicture', 'PictureInPictureControllerContentSource',
        'BFCCRON', 'IJKSDL', 'BFCPlayerSampleBuffer', 'IJKSampleBufferWrap',
        'BBPiPController', 'BFCPlayerControllerV2', 'BFCChronosRendererWrapper',
        'DMRenderLayerView', 'DMDanmakuRendererView', 'BBPlayerDMView',
        'BFCPlayerDMView', 'BBWWebDMView', 'DMImageView', 'DMVideoLayoutView'
      ];
      var hits = [];
      for (var i = 0; i < names.length && hits.length < 120; i++) {
        var n = names[i];
        for (var j = 0; j < pats.length; j++) {
          if (n.indexOf(pats[j]) !== -1) { hits.push(n); break; }
        }
      }
      classesEventSent = true;
      log('classes', { total: names.length, matched: hits });
    } catch (e) {
      // ObjC.classes enumeration failed; retry next round
    }
  }

  // ---------------------------------------------------------------------------
  // passive instrumentation
  // ---------------------------------------------------------------------------
  var instrumented = {};   // "ClassName - sel" -> true
  var classAttempts = {};  // ClassName -> attempts so far

  function argDescription(method, selName, args) {
    var out = [];
    var argTypes = null;
    try { argTypes = method.argumentTypes; } catch (e) { argTypes = null; }
    var n = (selName.match(/:/g) || []).length;
    for (var i = 0; i < n; i++) {
      var t = (argTypes && argTypes.length > 2 + i) ? argTypes[2 + i] : '?';
      try {
        if (t === '@') {
          var p = args[2 + i];
          if (p.isNull()) { out.push(null); continue; }
          var o = new ObjC.Object(p);
          out.push({ cls: o.class.toString(), desc: safeDescribe(o) });
        } else if (t === 'd' || t === 'f') {
          // raw register bits (hex); not dereferenced — treat as bit pattern
          out.push('rawbits:' + args[2 + i].toString());
        } else if (t === 'i' || t === 'q' || t === 'l' || t === 'B' || t === 'c') {
          out.push(args[2 + i].toInt32());
        } else {
          out.push(args[2 + i].toString());
        }
      } catch (e) {
        out.push('<unreadable>');
      }
    }
    return out;
  }

  function instrumentMethod(className, cls, selName, opts) {
    var key = className + ' ' + selName;
    if (instrumented[key]) return true;
    try {
      var m = cls[selName];
      if (m === null || m === undefined) return false;
      var impl = m.implementation;
      if (impl === null || impl === undefined) return false;
      Interceptor.attach(impl, {
        onEnter: function (args) {
          try {
            var d = {
              cls: className,
              sel: selName,
              self: (function () { try { return new ObjC.Object(args[0]).handle.toString(); } catch (e) { return null; } })(),
              selfCls: (function () { try { return new ObjC.Object(args[0]).class.toString(); } catch (e) { return null; } })(),
              args: argDescription(m, selName, args)
            };
            log('call', d);
            if (opts && opts.preDump) { try { dumpState(opts.preDump); } catch (e) {} }
            this._njt = Date.now();
          } catch (e) { log('call_error', { cls: className, sel: selName, error: trunc(e.message || ('' + e), 150) }); }
        },
        onLeave: function (retval) {
          try {
            var d = { cls: className, sel: selName, durMs: Date.now() - (this._njt || Date.now()) };
            if (opts && opts.logReturn) {
              var t = null;
              try { t = m.returnType; } catch (e) {}
              d.ret = (t === '@') ? ((retval.isNull()) ? null : safeDescribe(new ObjC.Object(retval))) : retval.toString();
            }
            log('return', d);
            if (opts && opts.postDump) { try { dumpState(opts.postDump); } catch (e) {} }
            if (opts && opts.postDumpDelayedMs !== undefined) {
              var tag2 = opts.postDumpDelayedMs.tag, ms = opts.postDumpDelayedMs.ms;
              setTimeout(function () { try { dumpState(tag2); } catch (e) {} }, ms);
            }
          } catch (e) { log('return_error', { cls: className, sel: selName, error: trunc(e.message || ('' + e), 150) }); }
        }
      });
      instrumented[key] = true;
      log('instrumented', { cls: className, sel: selName });
      return true;
    } catch (e) {
      log('instrument_error', { cls: className, sel: selName, error: trunc(e.message || ('' + e), 150) });
      return false;
    }
  }

  // BBSBPiPManager / BBAVPiPManager / AVPictureInPictureController targets.
  // {sel: '...'} with optional dump hooks; missing ones are simply skipped.
  var TARGETS = {
    'BBSBPiPManager': {
      methods: [
        { sel: '- prepareToStart', preDump: 'pre_bbsb_prepare', postDump: 'post_bbsb_prepare' },
        { sel: '- start', preDump: 'pre_bbsb_start', postDump: 'post_bbsb_start' },
        { sel: '- stopWithReason:', preDump: 'pre_bbsb_stop', postDump: 'post_bbsb_stop', logReturn: true },
        { sel: '- syncPlaybackStateWithPlayback:ignorePause:', logReturn: true },
        { sel: '- pictureInPictureStatus', logReturn: true },
        { sel: '- needsBindingPlayerContainer', logReturn: true }
      ],
      // also anything whose name contains bindGraftData
      dynamicFilter: 'bindGraftData'
    },
    'BBAVPiPManager': {
      methods: [
        { sel: '- prepareToStartSyncWithPlayback:' },
        { sel: '- updateDataSource:' },
        { sel: '- start', preDump: 'pre_bbav_start', postDump: 'post_bbav_start' },
        { sel: '- stopWithReason:', preDump: 'pre_bbav_stop', postDump: 'post_bbav_stop', logReturn: true }
      ]
    },
    'AVPictureInPictureController': {
      methods: [
        { sel: '- startPictureInPicture', preDump: 'pre_startPiP', postDumpDelayedMs: { tag: 'post_startPiP_1s', ms: 1000 } },
        { sel: '- stopPictureInPicture', preDump: 'pre_stopPiP', postDump: 'post_stopPiP' },
        { sel: '- setContentSource:' },
        { sel: '- setDelegate:' },
        { sel: '- setSampleBufferPlaybackDelegate:' },
        { sel: '- setPlaybackState:', logReturn: true }
      ]
    },
    'UIApplication': {
      methods: [
        { sel: '- applicationDidEnterBackground:' },
        { sel: '- applicationWillEnterForeground:' }
      ]
    }
  };

  function instrumentDynamicFilters(className, cls) {
    var spec = TARGETS[className];
    if (!spec || !spec.dynamicFilter) return;
    try {
      var methods = cls.$ownMethods;
      if (!methods) return;
      var needle = spec.dynamicFilter.toLowerCase();
      for (var i = 0; i < methods.length; i++) {
        var sel = methods[i];
        if (sel.toLowerCase().indexOf(needle) === -1) continue;
        instrumentMethod(className, cls, sel, { logReturn: true });
      }
    } catch (e) {}
  }

  function instrumentClassIfPresent(className) {
    if (allTargetsOf(className).done) return true;
    var cls = findClass(className);
    if (cls === null) return false;
    var spec = TARGETS[className];
    var foundAny = false;
    for (var i = 0; i < spec.methods.length; i++) {
      var m = spec.methods[i];
      if (instrumentMethod(className, cls, m.sel, m)) foundAny = true;
    }
    instrumentDynamicFilters(className, cls);
    if (foundAny) {
      allTargetsOf(className).done = true;
      allTargetsOf(className).missing = [];
    }
    return foundAny;
  }

  var targetState = {};
  function allTargetsOf(name) {
    if (!targetState[name]) targetState[name] = { done: false, missing: [] };
    return targetState[name];
  }

  function backgroundLifecycleHit(via) {
    // dump 0.5s / 2s / 5s after going to background (deduplicated across hooks)
    var now = Date.now();
    if (now - lastBackgroundAt < 2000) return;
    lastBackgroundAt = now;
    log('background', { via: via });
    setTimeout(function () { try { dumpState('background_0.5s'); } catch (e) {} }, 500);
    setTimeout(function () { try { dumpState('background_2s'); } catch (e) {} }, 2000);
    setTimeout(function () { try { dumpState('background_5s'); } catch (e) {} }, 5000);
  }
  var lastBackgroundAt = 0;

  function foregroundLifecycleHit(via) {
    var now = Date.now();
    if (now - lastForegroundAt < 2000) return;
    lastForegroundAt = now;
    log('foreground', { via: via });
  }
  var lastForegroundAt = 0;

  // Notification observers are the robust hook for app lifecycle; the
  // UIApplication method instrumentation (if the selectors exist) is a bonus.
  var lifecycleObserverBlocks = [];
  function observeLifecycleNotifications() {
    try {
      var nc = ObjC.classes.NSNotificationCenter.defaultCenter();
      if (nc === null) return;
      var mk = function (name, handler) {
        var blk = new ObjC.Block({
          rettype: 'void',
          argtypes: ['object'],
          implementation: function (note) {
            try { handler(); } catch (e) { log('note_error', { name: name, error: trunc(e.message || ('' + e), 120) }); }
          }
        });
        lifecycleObserverBlocks.push(blk); // keep alive
        nc.addObserverForName_object_queue_completionHandler_(name, null, null, blk);
      };
      mk('UIApplicationDidEnterBackgroundNotification', function () { backgroundLifecycleHit('notification'); });
      mk('UIApplicationWillEnterForegroundNotification', function () { foregroundLifecycleHit('notification'); });
      log('lifecycle_observers', { ok: true });
    } catch (e) {
      log('lifecycle_observers', { ok: false, error: trunc(e.message || ('' + e), 150) });
    }
  }

  // ===========================================================================
  // v2 forensics — SBDL vs Metal display path, PiP instance identity, danmaku
  // host views. All read-only: counters + bounded samples, never mutating.
  // ===========================================================================
  var missingReported = {};
  function reportMissing(name, why) {
    if (missingReported[name]) return;
    missingReported[name] = true;
    log('missing', { cls: name, why: trunc(why || 'class never appeared', 120) });
  }

  function argTypeOf(m, idx) {
    try {
      var at = m.argumentTypes;
      return (at && at.length > idx) ? at[idx] : '?';
    } catch (e) {
      return '?';
    }
  }

  function btSymbols(ctx, nFrames) {
    try {
      var addrs = Thread.backtrace(ctx, Backtracer.FUZZY).slice(0, nFrames || 6);
      var out = [];
      for (var i = 0; i < addrs.length; i++) {
        var sym = null;
        try { sym = DebugSymbol.fromAddress(addrs[i]); } catch (e0) {}
        if (sym !== null && sym !== undefined) {
          var mod = null;
          try { mod = sym.module ? sym.module.name : null; } catch (e1) {}
          out.push((mod ? mod + '!' : '') + (sym.name || ('' + addrs[i])));
        } else {
          out.push('' + addrs[i]);
        }
      }
      return out;
    } catch (e) {
      return null;
    }
  }

  // counters for high-frequency methods; a per-30s ticker emits "cnt" summaries.
  var counters = {};
  function countHook(className, cls, selName, opts) {
    var key = className + ' ' + selName;
    var st = counters[key];
    if (st && st.attached) return true;
    try {
      var m = cls[selName];
      if (!m || !m.implementation) return false;
      if (!st) st = counters[key] = { n: 0, attached: false };
      var limit = (opts && opts.sampleFirst !== undefined) ? opts.sampleFirst : 2;
      var byAddr = !!(opts && opts.byAddr);
      Interceptor.attach(m.implementation, {
        onEnter: function (args) {
          try {
            st.n++;
            if (byAddr) {
              if (!st.addrs) st.addrs = {};
              var a = args[0].toString();
              st.addrs[a] = (st.addrs[a] || 0) + 1;
            }
            if (st.n > limit) return;
            var d = { key: key, n: st.n, self: objInfo(args[0]) };
            if (opts && opts.argObjs) {
              for (var i = 0; i < opts.argObjs.length; i++) {
                var idx = opts.argObjs[i];
                var t = argTypeOf(m, idx);
                d['a' + idx] = (t === '@') ? objInfo(args[idx]) : ('t=' + t + ' ' + args[idx]);
              }
            }
            if (opts && opts.selfLayer) {
              try {
                var l = new ObjC.Object(args[0]).layer();
                if (l !== null && l !== undefined) d.layer = { addr: l.handle.toString(), cls: l.class.toString() };
              } catch (e1) { d.layer = 'err'; }
            }
            if (opts && opts.superlayer) {
              try {
                var sl = new ObjC.Object(args[0]).superlayer();
                if (sl !== null && sl !== undefined) d.superlayer = objInfo(sl.handle);
              } catch (e3) { d.superlayer = 'err'; }
            }
            if (opts && opts.backtrace) d.bt = btSymbols(this.context, 6);
            log('cnt1', d);
          } catch (e) {}
        },
        onLeave: function (retval) {
          if (!(opts && opts.retInfo)) return;
          try {
            if (st.n <= limit) log('cnt1', { key: key, ret: objInfo(retval) });
          } catch (e) {}
        }
      });
      st.attached = true;
      log('instrumented', { cls: className, sel: selName, mode: 'count' });
      return true;
    } catch (e) {
      log('instrument_error', { cls: className, sel: selName, error: trunc(e.message || ('' + e), 120) });
      return false;
    }
  }

  // instantiation watcher for a designated initializer: logs at most 3 records,
  // filtered to the target class by constructed-object class name (the IMP may
  // be an inherited one), records backing layer + ivar _displayLayer class.
  var instCounters = {};
  function instHook(className, cls, selName) {
    var key = className + ' ' + selName;
    if (instCounters[key]) return true;
    try {
      var m = cls[selName];
      if (!m || !m.implementation) return false;
      var st = instCounters[key] = { n: 0 };
      Interceptor.attach(m.implementation, {
        onLeave: function (retval) {
          try {
            if (retval === null || retval === undefined || retval.isNull()) return;
            var o = new ObjC.Object(retval);
            var cn = o.class.toString();
            if (cn.indexOf(className) === -1) return;
            st.n++;
            if (st.n > 3) return;
            var d = { key: key, n: st.n, self: retval.toString(), cls: cn };
            try {
              var l = o.layer();
              if (l !== null && l !== undefined) d.layer = { addr: l.handle.toString(), cls: l.class.toString() };
            } catch (e1) {}
            try {
              var iv = null;
              try { iv = o.$ivars._displayLayer; } catch (e2) { iv = null; }
              if (iv === null || iv === undefined) {
                try { iv = o.valueForKey_('_displayLayer'); } catch (e3) { iv = null; }
              }
              if (iv !== null && iv !== undefined) {
                d.displayLayerCls = (iv.class !== undefined) ? iv.class.toString() : classNameOf(iv);
              }
            } catch (e4) {}
            log('inst', d);
          } catch (e) {}
        }
      });
      log('instrumented', { cls: className, sel: selName, mode: 'inst' });
      return true;
    } catch (e) {
      log('instrument_error', { cls: className, sel: selName, error: trunc(e.message || ('' + e), 120) });
      return false;
    }
  }

  // +layerClass of a class (best-effort; instance layer class is captured by
  // the count hooks too, which is the authoritative answer).
  function probeLayerClass(className, cls) {
    var key = 'layerclass ' + className;
    if (counters[key]) return true;
    counters[key] = { n: 0, attached: true };
    try {
      var lc = cls.layerClass();
      var name = null;
      if (lc !== null && lc !== undefined) {
        try { name = lc.toString(); } catch (e0) {}
        if (name === null) { try { name = classNameOf(lc); } catch (e1) {} }
      }
      log('layerclass', { cls: className, layerClass: name });
      return true;
    } catch (e) {
      log('layerclass', { cls: className, error: trunc(e.message || ('' + e), 100) });
      return true;
    }
  }

  // watchlist: UIView subclasses of interest get exactly one record per live
  // instance at -didMoveToWindow time, with backing layer class and the class
  // names of its direct sublayers. Single hook on UIView -didMoveToWindow,
  // filtered by class name, so unrelated views cost one string compare.
  var WATCH_VIEWS = [
    'BBPlayerDMView', 'BFCPlayerDMView', 'BBWWebDMView', 'DMRenderLayerView',
    'DMImageView', 'DMVideoLayoutView', 'DMDanmakuRendererViewV2',
    'BFCPlayerSampleBufferView', 'IJKSampleBufferWrapView'
  ];
  var viewWatchDone = false;
  var viewSeen = {}; // view addr -> true (one record per instance)
  function installViewWatch() {
    if (viewWatchDone) return true;
    var uv = findClass('UIView');
    if (uv === null) return false;
    var m = uv['- didMoveToWindow'];
    if (!m || !m.implementation) return false;
    Interceptor.attach(m.implementation, {
      onEnter: function (args) {
        try {
          var selfObj = new ObjC.Object(args[0]);
          var cn = selfObj.class.toString();
          var hit = null;
          for (var i = 0; i < WATCH_VIEWS.length; i++) {
            if (cn === WATCH_VIEWS[i] || cn.indexOf(WATCH_VIEWS[i]) !== -1) { hit = WATCH_VIEWS[i]; break; }
          }
          if (hit === null) return;
          var addr = args[0].toString();
          if (viewSeen[addr]) return;
          viewSeen[addr] = true;
          var d = { host: hit, cls: cn, view: addr };
          try {
            var l = selfObj.layer();
            if (l !== null && l !== undefined) {
              d.layer = { addr: l.handle.toString(), cls: l.class.toString() };
              try {
                var sls = l.sublayers();
                if (sls !== null && sls !== undefined) {
                  var total = sls.count();
                  var names = [];
                  var lim = Math.min(total, 8);
                  for (var j = 0; j < lim; j++) {
                    try { names.push(sls.objectAtIndex(j).class.toString()); } catch (e0) { names.push('?'); }
                  }
                  d.sublayers = names;
                  d.subTotal = total;
                }
              } catch (e1) {}
            }
          } catch (e2) {}
          log('view', d);
        } catch (e) {}
      }
    });
    viewWatchDone = true;
    log('instrumented', { cls: 'UIView', sel: '- didMoveToWindow', mode: 'watch_filter' });
    return true;
  }

  // per-30s counter summaries: one short line per non-zero counter, never
  // per-call lines for the hot paths.
  function startCountSummary() {
    setInterval(function () {
      try {
        var keys = Object.keys(counters);
        for (var i = 0; i < keys.length; i++) {
          var st = counters[keys[i]];
          if (!st || !st.n) continue;
          var d = { k: keys[i], n: st.n };
          if (st.addrs) {
            var ak = Object.keys(st.addrs);
            var top = {};
            for (var j = 0; j < ak.length && j < 4; j++) top[ak[j]] = st.addrs[ak[j]];
            d.addrCount = ak.length;
            d.addrs = top;
          }
          log('cnt', d);
        }
      } catch (e) {}
    }, 30000);
  }

  // ===========================================================================
  // v3 forensics — the runtime gates that decide whether pixels reach the
  // screen. Read-only: counts + one bounded state line per 5s per key. Every
  // hook is defensive: a missing class or method logs exactly one hook_miss
  // line naming it and never throws into the host app.
  // ===========================================================================
  var STATE_THROTTLE_MS = 5000;   // sbp_view_visible / sbp_layer_state / cron_gate
  var ROUTE_THROTTLE_MS = 30000;  // pip_route repeats (kind changes always emit)

  // exactly one hook_miss per target name
  function hookMiss(key, why) {
    var mk = 'hook_miss ' + key;
    if (missingReported[mk]) return;
    missingReported[mk] = true;
    log('hook_miss', { key: key, why: trunc(why || 'target never appeared', 160) });
  }

  // v3 polling bookkeeping: keys whose class exists but whose selector does
  // not are settled after 2 attempts (retrying cannot make a selector appear)
  var selMiss = {};
  var settled = {};

  // --- G1: -[IJKSDLSampleBufferView visible] --------------------------------
  // display_pixels_vtb: does [self visible] then cbz, i.e. when this returns
  // NO the decoder pipeline is not fed at all. Count every call; emit at most
  // one line per 5s, or immediately when the returned value flips.
  function gateHook(className, cls, selName) {
    var key = className + ' ' + selName;
    var st = counters[key];
    if (st && st.attached) return true;
    try {
      var m = cls[selName];
      if (!m || !m.implementation) return false;
      if (!st) st = counters[key] = { n: 0, attached: false };
      var lastVal = null, lastAt = 0;
      Interceptor.attach(m.implementation, {
        onEnter: function (args) { this._njself = args[0]; },
        onLeave: function (retval) {
          try {
            st.n++;
            if (!st.addrs) st.addrs = {};
            var a = this._njself.toString();
            st.addrs[a] = (st.addrs[a] || 0) + 1;
            var v = 0;
            try { v = (retval.toUInt32 ? retval.toUInt32() : retval.toInt32()) & 1; } catch (e0) { v = -1; }
            var now = Date.now();
            var flip = (v !== lastVal);
            if (!flip && now - lastAt < STATE_THROTTLE_MS) return;
            lastVal = v; lastAt = now;
            var d = { key: key, n: st.n, visible: v };
            try {
              var l = new ObjC.Object(this._njself).layer();
              if (l !== null && l !== undefined) d.layer = { addr: l.handle.toString(), cls: l.class.toString() };
            } catch (e1) { d.layer = 'err'; }
            log('sbp_view_visible', d);
          } catch (e2) {}
        }
      });
      st.attached = true;
      log('instrumented', { cls: className, sel: selName, mode: 'gate' });
      return true;
    } catch (e) {
      log('instrument_error', { cls: className, sel: selName, error: trunc(e.message || ('' + e), 120) });
      return false;
    }
  }

  // --- G2: the sample-buffer layer's own state ------------------------------
  // The ready gate is -isReadyForMoreMediaData (counted through countHook);
  // status is read off the live layer instances, together with the frame rate
  // implied by the v2 per-address enqueueSampleBuffer: counter.
  var ENQ_KEY = 'AVSampleBufferDisplayLayer - enqueueSampleBuffer:';
  var layerStateLast = {}; // addr -> { n, at }
  var layerStateTimer = null;

  function startLayerStateTicker() {
    if (layerStateTimer !== null) return;
    layerStateTimer = setInterval(function () {
      try {
        var cls = findClass('AVSampleBufferDisplayLayer');
        if (cls === null) return;
        var insts = ObjC.chooseSync(cls);
        if (insts.length === 0) return;
        if (insts.length > 8) return; // too many to describe honestly; the cnt line already counts them
        var enq = counters[ENQ_KEY];
        var now = Date.now();
        for (var i = 0; i < insts.length; i++) {
          try {
            var o = insts[i];
            var addr = o.handle.toString();
            var d = { addr: addr };
            d.status = callNumber(o, 'status');
            d.ready = callBool(o, 'isReadyForMoreMediaData');
            var cur = (enq && enq.addrs && enq.addrs[addr]) ? enq.addrs[addr] : 0;
            var prev = layerStateLast[addr];
            if (prev === undefined) prev = { n: 0, at: now - 5000 };
            var dt = (now - prev.at) / 1000;
            d.enqTotal = cur;
            d.enqFps = dt > 0 ? Math.round(((cur - prev.n) / dt) * 10) / 10 : null;
            layerStateLast[addr] = { n: cur, at: now };
            log('sbp_layer_state', d);
          } catch (e0) {}
        }
      } catch (e) {}
    }, STATE_THROTTLE_MS);
  }

  // --- G3: the Metal-render gates (BFCCRONRenderBaseView) -------------------
  // updateGpuState reads applicationState and turns GPU access off in
  // background; updateDisplayLinkState pauses the display link when the view
  // has no window or an empty frame. Both are rare (app/view state changes),
  // so one line per key per 5s is enough to see the ordering.
  var GPU_IVARS = ['_gpuAccessAllowed', 'gpuAccessAllowed'];
  var DL_IVARS = ['_displayLink', '_displaylink', 'displayLink'];

  function appStateValue() {
    try {
      var ua = findClass('UIApplication');
      if (ua === null) return null;
      var app = ua.sharedApplication();
      if (app === null || app === undefined) return null;
      return Number(app.applicationState()); // 0 active, 1 inactive, 2 background
    } catch (e) {
      return null;
    }
  }

  function readIvarBool(o, names) {
    for (var i = 0; i < names.length; i++) {
      try {
        var iv = o.$ivars[names[i]];
        if (iv === null || iv === undefined) continue;
        if (typeof iv === 'number') return iv ? 1 : 0;
        if (iv instanceof NativePointer) {
          if (iv.isNull()) continue;
          var n = iv.toInt32();
          if (n >= 0 && n <= 1) return n;
        }
      } catch (e) {}
    }
    return null;
  }

  function displayLinkPaused(o) {
    for (var i = 0; i < DL_IVARS.length; i++) {
      try {
        var dl = o.$ivars[DL_IVARS[i]];
        if (dl === null || dl === undefined) continue;
        if (dl instanceof NativePointer) {
          if (dl.isNull()) continue;
          try { dl = new ObjC.Object(dl); } catch (e0) { continue; }
        }
        try { if (typeof dl.isPaused === 'function') return dl.isPaused() ? 1 : 0; } catch (e1) {}
        try {
          if (typeof dl.respondsToSelector === 'function' && dl.respondsToSelector_('isPaused')) return dl.isPaused() ? 1 : 0;
        } catch (e2) {}
        try { if (typeof dl.paused === 'function') return dl.paused() ? 1 : 0; } catch (e3) {}
      } catch (e4) {}
    }
    return null;
  }

  function viewFrameOf(o) {
    try {
      var f = o.frame();
      if (f === null || f === undefined) return null;
      var w = null, h = null;
      if (typeof f === 'object') {
        try { w = f.size.width; h = f.size.height; } catch (e0) {}
        if (w === null || w === undefined) { try { w = f[2]; h = f[3]; } catch (e1) {} }
      }
      if (w === null || w === undefined || h === null || h === undefined) return null;
      return { w: Math.round(Number(w) * 100) / 100, h: Math.round(Number(h) * 100) / 100 };
    } catch (e) {
      return null;
    }
  }

  // setGpuAccessAllowed:'s argument is the ground truth for gpuAllowed; keep
  // the last value so the cron_gate line can carry it. Count-only, no output.
  var cronArgState = { gpuAllowed: null, have: false };

  function gpusetHook(className, cls, selName) {
    var key = className + ' ' + selName;
    var st = counters[key];
    if (st && st.attached) return true;
    try {
      var m = cls[selName];
      if (!m || !m.implementation) return false;
      if (!st) st = counters[key] = { n: 0, attached: false };
      var argT = argTypeOf(m, 2);
      Interceptor.attach(m.implementation, {
        onEnter: function (args) {
          try {
            st.n++;
            if (argT === 'B' || argT === 'c') {
              var v = args[2].toInt32() & 1;
              cronArgState.gpuAllowed = v;
              cronArgState.have = true;
            }
          } catch (e) {}
        }
      });
      st.attached = true;
      log('instrumented', { cls: className, sel: selName, mode: 'gpuset' });
      return true;
    } catch (e) {
      log('instrument_error', { cls: className, sel: selName, error: trunc(e.message || ('' + e), 120) });
      return false;
    }
  }

  function cronHook(className, cls, selName) {
    var key = className + ' ' + selName;
    var st = counters[key];
    if (st && st.attached) return true;
    try {
      var m = cls[selName];
      if (!m || !m.implementation) return false;
      if (!st) st = counters[key] = { n: 0, attached: false };
      Interceptor.attach(m.implementation, {
        onEnter: function (args) { this._njself = args[0]; },
        onLeave: function () {
          try {
            st.n++;
            var now = Date.now();
            if (st.lastAt !== undefined && now - st.lastAt < STATE_THROTTLE_MS) return;
            st.lastAt = now;
            var o = new ObjC.Object(this._njself);
            var d = { key: key, n: st.n, appState: appStateValue() };
            var iv = readIvarBool(o, GPU_IVARS);
            d.gpuAllowed = (iv !== null) ? iv : (cronArgState.have ? cronArgState.gpuAllowed : null);
            d.paused = displayLinkPaused(o);
            try {
              var w = o.window();
              d.hasWindow = !(w === null || w === undefined || w.handle.isNull());
            } catch (e0) { d.hasWindow = null; }
            var f = viewFrameOf(o);
            if (f !== null) { d.frameW = f.w; d.frameH = f.h; }
            log('cron_gate', d);
          } catch (e2) {}
        }
      });
      st.attached = true;
      log('instrumented', { cls: className, sel: selName, mode: 'cron' });
      return true;
    } catch (e) {
      log('instrument_error', { cls: className, sel: selName, error: trunc(e.message || ('' + e), 120) });
      return false;
    }
  }

  // --- G4: the danmaku texture's real pixel format --------------------------
  // copyPixelBuffer returns the CVPixelBuffer the composer feeds; the static
  // binary cannot say which fourcc it is. The pointer is only handed to the
  // CoreVideo getter right here — no ObjC wrapper, no retain, no release — so
  // the buffer's lifetime is exactly as the host left it. At most once per 5s.
  var CVPixelBufferGetPixelFormatType = null;
  try {
    var cvfmtAddr = findExport('CoreVideo', 'CVPixelBufferGetPixelFormatType');
    if (cvfmtAddr) CVPixelBufferGetPixelFormatType = new NativeFunction(cvfmtAddr, 'uint32', ['pointer']);
  } catch (e) { CVPixelBufferGetPixelFormatType = null; }

  function fourccStr(u) {
    var s = '';
    for (var sh = 24; sh >= 0; sh -= 8) {
      var c = (u >>> sh) & 0xff;
      s += (c >= 32 && c < 127) ? String.fromCharCode(c) : '?';
    }
    return s;
  }

  function pixfmtHook(className, cls, selName) {
    var key = className + ' ' + selName;
    var st = counters[key];
    if (st && st.attached) return true;
    try {
      var m = cls[selName];
      if (!m || !m.implementation) return false;
      if (!st) st = counters[key] = { n: 0, attached: false };
      var lastFmtAt = 0;
      Interceptor.attach(m.implementation, {
        onEnter: function (args) {
          try {
            if (st.n === 0) this._njself = args[0]; // one v2-style sample only
          } catch (e) {}
        },
        onLeave: function (retval) {
          try {
            st.n++;
            if (this._njself !== undefined) log('cnt1', { key: key, n: 1, self: objInfo(this._njself) });
            if (retval === null || retval === undefined || retval.isNull()) return;
            if (CVPixelBufferGetPixelFormatType === null) return;
            var now = Date.now();
            if (now - lastFmtAt < STATE_THROTTLE_MS) return;
            lastFmtAt = now;
            var u = CVPixelBufferGetPixelFormatType(retval);
            log('dm_pixfmt', { key: key, n: st.n, pixfmt: fourccStr(u), raw: '0x' + u.toString(16) });
          } catch (e) {}
        }
      });
      st.attached = true;
      log('instrumented', { cls: className, sel: selName, mode: 'pixfmt' });
      return true;
    } catch (e) {
      log('instrument_error', { cls: className, sel: selName, error: trunc(e.message || ('' + e), 120) });
      return false;
    }
  }

  // --- G5: which PiP pipeline is actually in play ----------------------------
  // Sample-buffer evidence (a ContentSource built on an SBDL, handed to the
  // PiP controller) versus AVPlayer evidence (a custom video compositor or a
  // video-gravity change on an AVPlayerLayer).
  var pipRoute = { kind: null, evidence: [] };
  var pipRouteLastAt = 0;

  function routeEvidence(kind, key, selfAddr, detail) {
    try {
      var tag = kind + ':' + key;
      if (pipRoute.evidence.indexOf(tag) === -1 && pipRoute.evidence.length < 12) pipRoute.evidence.push(tag);
      var changed = (pipRoute.kind !== kind);
      var now = Date.now();
      if (!changed && now - pipRouteLastAt < ROUTE_THROTTLE_MS) return;
      pipRoute.kind = kind;
      pipRouteLastAt = now;
      log('pip_route', {
        route: kind, via: key, self: selfAddr,
        arg: detail ? trunc(detail, 100) : null,
        evidence: pipRoute.evidence.join('|')
      });
    } catch (e) {}
  }

  function routeHook(className, cls, selName, kind) {
    // its own bookkeeping key: the same implementation may already carry a v2
    // 'call' hook, and attaching a second interceptor to one IMP is supported.
    var key = 'route ' + className + ' ' + selName;
    var st = counters[key];
    if (st && st.attached) return true;
    try {
      var m = cls[selName];
      if (!m || !m.implementation) return false;
      if (!st) st = counters[key] = { n: 0, attached: false };
      Interceptor.attach(m.implementation, {
        onEnter: function (args) {
          // note: the same implementation may already carry a v2 'call' hook;
          // attaching a second interceptor to one IMP is supported.
          try {
            st.n++;
            var sa = null;
            try { sa = args[0].toString(); } catch (e0) {}
            var det = null;
            try {
              if (args[2] !== undefined && args[2] !== null && !args[2].isNull()) {
                det = new ObjC.Object(args[2]).class.toString();
              }
            } catch (e1) {}
            routeEvidence(kind, className + ' ' + selName, sa, det);
          } catch (e2) {}
        }
      });
      st.attached = true;
      log('instrumented', { cls: className, sel: selName, mode: 'route', route: kind });
      return true;
    } catch (e) {
      log('instrument_error', { cls: className, sel: selName, error: trunc(e.message || ('' + e), 120) });
      return false;
    }
  }

  // BBPictureInPicture.PlayerView: its +layerClass says whether the PiP view
  // is SBDL-backed, and the live instance count says whether it was built.
  function pipPlayerViewProbe(className) {
    var key = 'pipplayerview ' + className;
    if (counters[key]) return true;
    counters[key] = { n: 0, attached: true };
    try {
      var cls = findClass(className);
      if (cls === null) return false;
      var lcName = null;
      try {
        var lc = cls.layerClass();
        if (lc !== null && lc !== undefined) {
          try { lcName = lc.toString(); } catch (e0) { lcName = classNameOf(lc); }
        }
      } catch (e1) { lcName = 'err'; }
      var count = 0, addrs = [];
      try {
        var insts = ObjC.chooseSync(cls);
        count = insts.length;
        for (var i = 0; i < insts.length && i < 4; i++) addrs.push(insts[i].handle.toString());
      } catch (e2) {}
      log('pip_playerview', { cls: className, layerClass: lcName, count: count, addrs: addrs });
      return true;
    } catch (e) {
      log('pip_playerview', { cls: className, error: trunc(e.message || ('' + e), 120) });
      return true;
    }
  }

  // --- v4 H1/H2: the online chronos danmaku chain ---------------------------
  // Static forensics (HANDOFF 15.11) says the online danmaku renderer is NOT
  // reachable through -[BBPlayerDanmakuService view] (that returns a
  // BBPlayerChronosContainerView); it is reached through the player context:
  //   service.context → BBPlayerContext -chronos → BBPlayerChronos -chronosView
  //   → BFCCRONRenderView / …V2 -rendererWrapper → BFCChronosRendererWrapper
  // H1 walks that chain once per PiP entry and reports every hop (a failure
  // names the hop that broke). H2 then asks that wrapper for a frame every 2s
  // while PiP is active, to see whether the danmaku layer is still producing
  // new buffers. H1 never calls into the renderer; H2 calls ONLY
  // -copyPixelBuffer — never -updateSyncForTimeStep:, which would advance the
  // engine's own clock. The +1 buffer that -copyPixelBuffer returns is handed
  // straight to CFRelease here, so nothing is kept and nothing leaks.
  var CRON_HOPS = ['context', 'chronos', 'chronosView', 'rendererWrapper'];
  var CRON_POLL_MS = 2000;
  var CRON_POLL_CAP_MS = 900000; // stop asking after 15 min of one PiP session
  var CRON_KEEPALIVE_MS = 30000; // one "same buffer" line per 30s while polling

  var objcRetain = null, objcRelease = null, cfRelease = null;
  var CVPixelBufferGetWidth = null, CVPixelBufferGetHeight = null;
  try {
    var rA = findExport('libobjc.A.dylib', 'objc_retain');
    var rB = findExport('libobjc.A.dylib', 'objc_release');
    var rC = findExport('CoreFoundation', 'CFRelease');
    if (rA && rB && rC) {
      objcRetain = new NativeFunction(rA, 'pointer', ['pointer']);
      objcRelease = new NativeFunction(rB, 'pointer', ['pointer']);
      cfRelease = new NativeFunction(rC, 'void', ['pointer']);
    }
  } catch (e) {
    objcRetain = null; objcRelease = null; cfRelease = null;
  }
  try {
    var wA = findExport('CoreVideo', 'CVPixelBufferGetWidth');
    var wB = findExport('CoreVideo', 'CVPixelBufferGetHeight');
    if (wA) CVPixelBufferGetWidth = new NativeFunction(wA, 'uint', ['pointer']);
    if (wB) CVPixelBufferGetHeight = new NativeFunction(wB, 'uint', ['pointer']);
  } catch (e2) {
    CVPixelBufferGetWidth = null; CVPixelBufferGetHeight = null;
  }

  // resolved chain; `wrapper` is a pointer this probe retained itself (H1 keeps
  // it alive only while H2 is polling, and releases it when PiP stops)
  var cron = {
    resolved: false, polling: false, pipActive: false, timer: null,
    wrapper: null, copyFn: null, copySel: null,
    state: null, lastKeepAliveAt: 0, polls: 0, startedAt: 0
  };

  function cronReleaseWrapper() {
    try {
      if (cron.wrapper !== null && objcRelease !== null) objcRelease(cron.wrapper);
    } catch (e) {}
    cron.wrapper = null;
    cron.copyFn = null;
    cron.copySel = null;
    cron.resolved = false;
    cron.state = null;
    mxReleaseChronos(); // v5 I2: the retained chain object goes with the chain
  }

  // --- v5 I1/I2: the mixed-offscreen candidate -------------------------------
  // The third PiP path replays the app's own offscreen mixed render, so the
  // probe answers three static questions at the chain walk (which view class is
  // live — the AB pick V1/V2 is runtime-only — and which offscreen entry points
  // it answers) and one dynamic one (does that same view stay alive and
  // windowed while PiP runs). Only respondsToSelector checks plus one extra
  // no-argument getter per 30s through an object the probe retained; no image
  // is ever made, nothing is called on the view itself.
  var MX_ALIVE_MS = 30000;
  var mx = { chronos: null, viewAddr: null, lastAliveAt: 0 };

  function mxReleaseChronos() {
    try {
      if (mx.chronos !== null && objcRelease !== null) objcRelease(mx.chronos);
    } catch (e) {}
    mx.chronos = null;
    mx.viewAddr = null;
    mx.lastAliveAt = 0;
  }

  // I1: one line per chain walk, at the chronosView hop (also when that hop
  // itself failed — a nil view is the finding then).
  function mxProbeReport(viewR, chronosR, reason) {
    try {
      if (viewR === null) return;
      var d = {
        reason: reason,
        view: viewR.ok ? 1 : 0,
        cls: viewR.cls || null,
        addr: viewR.addr || null,
        v2: (viewR.cls && viewR.cls.indexOf('V2') >= 0) ? 1 : 0
      };
      if (viewR.ok) {
        try { d.gmi = viewR.obj.respondsToSelector_('getMixedImage') ? 1 : 0; } catch (e0) { d.gmi = 0; }
        try { d.gri = viewR.obj.respondsToSelector_('getRendererImage') ? 1 : 0; } catch (e1) { d.gri = 0; }
      }
      if (chronosR !== null && chronosR.ok) {
        try { d.omi = chronosR.obj.respondsToSelector_('offscreenMixedImage') ? 1 : 0; } catch (e2) { d.omi = 0; }
      } else {
        d.omi = 0;
      }
      log('mx_probe', d);
      // keep the chain's chronos object alive so I2 can re-read the view later
      mxReleaseChronos();
      if (viewR.ok && chronosR !== null && chronosR.ok && objcRetain !== null) {
        var kept = null;
        try { kept = objcRetain(chronosR.obj.handle); } catch (e3) { kept = null; }
        if (kept !== null && !(typeof kept.isNull === 'function' && kept.isNull())) {
          mx.chronos = kept;
          mx.viewAddr = viewR.addr;
          mx.lastAliveAt = 0;
        }
      }
    } catch (e) {
      try { log('mx_probe', { error: trunc(e.message || ('' + e), 120) }); } catch (e9) {}
    }
  }

  // I2: through the retained chronos object, re-read the current view pointer
  // (same getter H1 walks, once per 30s) and ask it for its window. same=0 or
  // win=0 mean the view's own display link cannot be producing fresh textures.
  function mxAliveTick() {
    try {
      if (mx.chronos === null || typeof ObjC === 'undefined') return;
      var now = Date.now();
      if (now - mx.lastAliveAt < MX_ALIVE_MS) return;
      mx.lastAliveAt = now;
      var r = cronHop(new ObjC.Object(mx.chronos), 'chronosView');
      var d = { same: (r.ok && r.addr === mx.viewAddr) ? 1 : 0, view: r.ok ? 1 : 0 };
      if (r.ok) {
        var win = -1;
        try {
          var w = r.obj.window();
          win = (w === null || w === undefined || (typeof w.isNull === 'function' && w.isNull())) ? 0 : 1;
        } catch (e0) { win = -1; }
        d.win = win;
      }
      log('mx_alive', d);
    } catch (e) {
      try { log('mx_alive', { error: trunc(e.message || ('' + e), 120) }); } catch (e9) {}
    }
  }

  // one hop of the chain: a no-argument getter, guarded by respondsToSelector:
  function cronHop(receiver, hop) {
    try {
      if (receiver === null || receiver === undefined) return { ok: false, why: 'nil-recv' };
      if (typeof receiver.respondsToSelector_ !== 'function') return { ok: false, why: 'no-bridge' };
      if (!receiver.respondsToSelector_(hop)) return { ok: false, why: 'no-sel' };
      var v = receiver[hop]();
      if (v === null || v === undefined) return { ok: false, why: 'nil' };
      if (typeof v.isNull === 'function' && v.isNull()) return { ok: false, why: 'nil' };
      return {
        ok: true, obj: v, cls: classNameOf(v),
        addr: (v.handle !== undefined) ? v.handle.toString() : null
      };
    } catch (e) {
      return { ok: false, why: 'error', err: trunc(e.message || ('' + e), 90) };
    }
  }

  function resolveCronChain(reason) {
    try {
      cronReleaseWrapper();
      var cls = findClass('BBPlayerDanmakuService');
      if (cls === null) {
        log('cron_chain', { step: 0, hop: 'service', present: 0, reason: reason });
        return false;
      }
      var insts = [];
      try { insts = ObjC.chooseSync(cls); } catch (e0) { insts = []; }
      var svc = null;
      for (var i = 0; i < insts.length && i < 4; i++) {
        try {
          if (insts[i] && !insts[i].isNull()) { svc = insts[i]; break; }
        } catch (e1) {}
      }
      if (svc === null) {
        log('cron_chain', { step: 0, hop: 'service', found: 0, fail: 'no-instance', reason: reason });
        return false;
      }
      log('cron_chain', { step: 0, hop: 'service', n: insts.length, cls: classNameOf(svc), addr: svc.handle.toString() });
      var cur = svc;
      var chronosR = null;
      for (var h = 0; h < CRON_HOPS.length; h++) {
        var r = cronHop(cur, CRON_HOPS[h]);
        if (!r.ok) {
          log('cron_chain', { step: h + 1, hop: CRON_HOPS[h], fail: r.why, err: r.err || null });
          if (h === 2) mxProbeReport(r, chronosR, reason); // v5 I1: a nil view is the finding
          return false;
        }
        log('cron_chain', { step: h + 1, hop: CRON_HOPS[h], cls: r.cls, addr: r.addr });
        if (h === 1) chronosR = r; // BBPlayerChronos: where offscreenMixedImage lives
        if (h === 2) mxProbeReport(r, chronosR, reason); // v5 I1: the cron view hop
        cur = r.obj;
      }
      var hasCopy = false, hasSync = false;
      try { hasCopy = !!cur.respondsToSelector_('copyPixelBuffer'); } catch (e2) {}
      try { hasSync = !!cur.respondsToSelector_('updateSyncForTimeStep:'); } catch (e3) {}
      log('cron_chain', {
        step: CRON_HOPS.length + 1, hop: 'ready', cls: classNameOf(cur),
        addr: cur.handle.toString(), copy: hasCopy ? 1 : 0, sync: hasSync ? 1 : 0
      });
      if (!hasCopy) return false;
      if (objcRetain === null || cfRelease === null) {
        // without CFRelease the +1 buffer of every poll would leak, and without
        // objc_retain the pointer below could die under us: measure nothing.
        log('cron_poll', { off: 1, why: (objcRetain === null) ? 'no-objc-retain' : 'no-cfrelease' });
        return false;
      }
      var imp = null;
      try {
        var m = cur.copyPixelBuffer;
        if (m && m.implementation) imp = m.implementation;
      } catch (e4) { imp = null; }
      if (imp === null) {
        log('cron_poll', { off: 1, why: 'no-imp' });
        return false;
      }
      var kept = null;
      try { kept = objcRetain(cur.handle); } catch (e5) { kept = null; }
      if (kept === null || kept.isNull()) {
        log('cron_poll', { off: 1, why: 'retain-failed' });
        return false;
      }
      cron.wrapper = kept;
      cron.copySel = ObjC.selector('copyPixelBuffer');
      cron.copyFn = new NativeFunction(imp, 'pointer', ['pointer', 'pointer']);
      cron.resolved = true;
      return true;
    } catch (e) {
      log('cron_chain', { step: -1, hop: 'resolve', error: trunc(e.message || ('' + e), 120) });
      return false;
    }
  }

  // H2: is the danmaku engine still producing frames? Pointer identity only —
  // same pointer twice means the compositor handed back the same buffer, which
  // is the cheap, non-invasive signal for "the image is frozen".
  function cronPollTick() {
    try {
      mxAliveTick(); // v5 I2: piggybacks on this timer (self-throttled to 30s)
      if (!cron.resolved || cron.wrapper === null || cron.copyFn === null) return;
      if (Date.now() - cron.startedAt > CRON_POLL_CAP_MS) {
        log('cron_poll', { stop: 1, reason: 'cap', n: cron.polls });
        stopCronPoll();
        return;
      }
      var buf = cron.copyFn(cron.wrapper, cron.copySel);
      cron.polls++;
      var isNil = (buf === null || buf === undefined || buf.isNull());
      var st = isNil ? '' : buf.toString();
      var changed = (st !== '' && st !== cron.state) ? 1 : 0;
      var now = Date.now();
      var keepAlive = (!changed && st === cron.state && now - cron.lastKeepAliveAt >= CRON_KEEPALIVE_MS);
      if (changed || st !== cron.state || keepAlive) {
        var d = { n: cron.polls, changed: changed, ptr: (st === '' ? null : st) };
        if (!isNil) {
          if (CVPixelBufferGetWidth !== null) { try { d.w = CVPixelBufferGetWidth(buf); } catch (e1) {} }
          if (CVPixelBufferGetHeight !== null) { try { d.h = CVPixelBufferGetHeight(buf); } catch (e2) {} }
        }
        log('cron_dm_poll', d);
        if (keepAlive) cron.lastKeepAliveAt = now;
      }
      cron.state = st;
      if (!isNil && cfRelease !== null) cfRelease(buf); // the -copy method owes us one
    } catch (e) {
      log('cron_dm_poll', { error: trunc(e.message || ('' + e), 120) });
    }
  }

  function cronPollTickOnMain() {
    // the renderer is driven from the main thread by its own display link, so
    // the probe asks for a frame there too instead of from the JS thread
    try {
      if (typeof ObjC !== 'undefined' && typeof ObjC.schedule === 'function' && ObjC.mainQueue) {
        ObjC.schedule(ObjC.mainQueue, function () { cronPollTick(); });
        return;
      }
    } catch (e) {}
    cronPollTick();
  }

  function startCronPoll() {
    if (cron.polling) return;
    cron.polling = true;
    cron.startedAt = Date.now();
    cron.lastKeepAliveAt = 0;
    cron.timer = setInterval(function () {
      try { cronPollTickOnMain(); } catch (e) {}
    }, CRON_POLL_MS);
  }

  function stopCronPoll() {
    try {
      if (cron.timer !== undefined && cron.timer !== null) clearInterval(cron.timer);
    } catch (e) {}
    cron.timer = null;
    cron.polling = false;
    cron.polls = 0;
    cronReleaseWrapper();
  }

  // H1/H2 trigger: PiP really starting / stopping. Two extra interceptors on a
  // method the v2 config already hooks is supported (see routeHook).
  function cronStartHook(className, cls, selName) {
    var key = 'cronstart ' + className + ' ' + selName;
    var st = counters[key];
    if (st && st.attached) return true;
    try {
      var m = cls[selName];
      if (!m || !m.implementation) return false;
      if (!st) st = counters[key] = { n: 0, attached: false };
      Interceptor.attach(m.implementation, {
        onEnter: function () {
          try {
            st.n++;
            var first = !cron.pipActive;
            cron.pipActive = true;
            if (!first) return;
            if (resolveCronChain('pip_start')) startCronPoll();
          } catch (e) {}
        }
      });
      st.attached = true;
      log('instrumented', { cls: className, sel: selName, mode: 'cronstart' });
      return true;
    } catch (e2) {
      log('instrument_error', { cls: className, sel: selName, error: trunc(e2.message || ('' + e2), 120) });
      return false;
    }
  }

  function cronStopHook(className, cls, selName) {
    var key = 'cronstop ' + className + ' ' + selName;
    var st = counters[key];
    if (st && st.attached) return true;
    try {
      var m = cls[selName];
      if (!m || !m.implementation) return false;
      if (!st) st = counters[key] = { n: 0, attached: false };
      Interceptor.attach(m.implementation, {
        onEnter: function () {
          try {
            st.n++;
            if (!cron.pipActive) return;
            cron.pipActive = false;
            stopCronPoll();
          } catch (e) {}
        }
      });
      st.attached = true;
      log('instrumented', { cls: className, sel: selName, mode: 'cronstop' });
      return true;
    } catch (e2) {
      log('instrument_error', { cls: className, sel: selName, error: trunc(e2.message || ('' + e2), 120) });
      return false;
    }
  }

  // --- v4 H3: is the decoded video fed into the Metal danmaku view? ---------
  // -[BFCCRONRenderBaseView setExternalPixelBuffer:] is the door an external
  // (decoded video) buffer would be pushed through. Only a call counter; one
  // line per 30s at most, and only when the count moved (or once, to say that
  // a mounted hook has seen nothing at all).
  var extpb = { attached: false, n: 0, cls: null, reported: -1, zeroSaid: false };

  function extpbHook(className, cls, selName) {
    var key = 'extpb ' + className + ' ' + selName;
    var st = counters[key];
    if (st && st.attached) return true;
    try {
      var m = cls[selName];
      if (!m || !m.implementation) return false;
      if (!st) st = counters[key] = { n: 0, attached: false };
      Interceptor.attach(m.implementation, {
        onEnter: function (args) {
          try {
            extpb.n++;
            if (extpb.cls === null) extpb.cls = objInfo(args[0]);
          } catch (e) {}
        }
      });
      st.attached = true;
      extpb.attached = true;
      log('instrumented', { cls: className, sel: selName, mode: 'extpb' });
      return true;
    } catch (e2) {
      log('instrument_error', { cls: className, sel: selName, error: trunc(e2.message || ('' + e2), 120) });
      return false;
    }
  }

  var extpbTimer = null;
  function startExtpbTicker() {
    if (extpbTimer !== null) return;
    extpbTimer = setInterval(function () {
      try {
        if (extpb.n === extpb.reported) return;
        if (extpb.n === 0 && extpb.zeroSaid) return;
        if (extpb.n === 0 && !extpb.attached) return;
        if (extpb.n === 0) extpb.zeroSaid = true;
        extpb.reported = extpb.n;
        log('ext_pixelbuf', { count: extpb.n, cls: (extpb.cls === null) ? null : extpb.cls.cls, addr: (extpb.cls === null) ? null : extpb.cls.addr });
      } catch (e) {}
    }, 30000);
  }

  // mounted hook points, reported by probe_boot / probe_ready
  function mountedCount() {
    var n = 0;
    try {
      n += Object.keys(instrumented).length;
      n += Object.keys(instCounters).length;
      var ks = Object.keys(counters);
      for (var i = 0; i < ks.length; i++) { if (counters[ks[i]].attached) n++; }
      if (viewWatchDone) n++;
      if (lifecycleObserverBlocks.length > 0) n++;
    } catch (e) {}
    return n;
  }

  var FX_METHODS = [
    // A. display path: SBDL vs Metal
    { cls: 'IJKSDLSampleBufferView', sel: '- display_pixels:', mode: 'count', opts: { argObjs: [2], selfLayer: true, sampleFirst: 3 } },
    { cls: 'IJKSDLSampleBufferView', sel: '- display_pixels_vtb:', mode: 'count', opts: { argObjs: [2], sampleFirst: 2 } },
    { cls: 'IJKSDLSampleBufferView', sel: '- display_pixels_ffmpeg:', mode: 'count', opts: { argObjs: [2], sampleFirst: 2 } },
    { cls: 'IJKSDLSampleBufferView', sel: '- enqueueSmapleBuffer:', mode: 'count', opts: { argObjs: [2], selfLayer: true, sampleFirst: 3 } },
    { cls: 'IJKSDLSampleBufferView', sel: '+ layerClass', mode: 'layerclass' },
    { cls: 'BFCCRONRenderViewV2', sel: '- initWithFrame:', mode: 'inst' },
    { cls: 'BFCPlayerSampleBufferView', sel: '- getCurrentRenderer', mode: 'count', opts: { retInfo: true, sampleFirst: 3 } },
    { cls: 'BFCPlayerSampleBufferView', sel: '- switchRenderer:', mode: 'call' },
    { cls: 'IJKSampleBufferWrapView', sel: '- getCurrentRenderer', mode: 'count', opts: { retInfo: true, sampleFirst: 3 } },
    { cls: 'IJKSampleBufferWrapView', sel: '- switchRenderer:', mode: 'call' },
    // B. PiP instance identity
    { cls: 'AVSampleBufferDisplayLayer', sel: '- enqueueSampleBuffer:', mode: 'count', opts: { argObjs: [2], superlayer: true, backtrace: true, byAddr: true, sampleFirst: 3 } },
    { cls: 'BFCPlayerControllerV2', sel: '- sampleBufferDisplayLayer', mode: 'count', opts: { retInfo: true, sampleFirst: 5 } },
    { cls: 'BBPlayerPlayback', sel: '- generateContentSourceWithCompletionHandler:', mode: 'call' },
    { cls: 'BFCPlayerControllerV2', sel: '- generateContentSourceWithCompletionHandler:', mode: 'call' },
    { cls: 'AVPictureInPictureControllerContentSource', sel: '- initWithSampleBufferDisplayLayer:playbackDelegate:', mode: 'call' },
    { cls: 'BBPiPController', sel: '- setContentSource:', mode: 'call' },
    // C. danmaku engine carrier (instantiation seen via state snapshots / view watch)
    // v3 G4: count (as in v2) + a throttled fourcc read of the returned buffer
    { cls: 'BFCChronosRendererWrapper', sel: '- copyPixelBuffer', mode: 'pixfmt' },
    // v3 G1: the visible gate that display_pixels_vtb: branches on
    { cls: 'IJKSDLSampleBufferView', sel: '- visible', mode: 'gate' },
    // v3 G2: the ready gate that enqueueSmapleBuffer: branches on (count-only;
    // the 5s ticker reads status/ready off the live layers). If this class has
    // no such selector, exactly one hook_miss line names it.
    { cls: 'AVSampleBufferDisplayLayer', sel: '- isReadyForMoreMediaData', mode: 'count', opts: { byAddr: true, sampleFirst: 0 } },
    // v3 G3: app-background ⇒ GPU off; no window / empty frame ⇒ display link paused
    { cls: 'BFCCRONRenderBaseView', sel: '- updateGpuState', mode: 'cron' },
    { cls: 'BFCCRONRenderBaseView', sel: '- updateDisplayLinkState', mode: 'cron' },
    { cls: 'BFCCRONRenderBaseView', sel: '- didMoveToWindow', mode: 'cron' },
    { cls: 'BFCCRONRenderBaseView', sel: '- setGpuAccessAllowed:', mode: 'gpuset' },
    // v3 G5: which pipeline the PiP is driven by (a second interceptor on an
    // IMP already covered by a v2 'call' hook is fine — both run)
    { cls: 'BBPiPController', sel: '- setContentSource:', mode: 'route', route: 'sb' },
    { cls: 'BFCPlayerControllerV2', sel: '- generateContentSourceWithCompletionHandler:', mode: 'route', route: 'sb' },
    { cls: 'AVPictureInPictureControllerContentSource', sel: '- initWithSampleBufferDisplayLayer:playbackDelegate:', mode: 'route', route: 'sb' },
    { cls: 'AVPlayerItem', sel: '- setCustomVideoCompositor:', mode: 'route', route: 'avplayer' },
    { cls: 'AVPlayerLayer', sel: '- setVideoGravity:', mode: 'route', route: 'avplayer' },
    // v3 G5: the PiP host view's backing layer class + instance count
    { cls: 'BBPictureInPicture.PlayerView', sel: '+ layerClass', mode: 'pvp' },
    // v4 H1/H2: resolve the online chronos danmaku chain when PiP really
    // starts; the 2s frame-alive poll runs only between start and stop.
    { cls: 'AVPictureInPictureController', sel: '- startPictureInPicture', mode: 'cronstart' },
    { cls: 'AVPictureInPictureController', sel: '- stopPictureInPicture', mode: 'cronstop' },
    // v4 H3: is a decoded-video buffer ever pushed into the Metal danmaku view?
    { cls: 'BFCCRONRenderBaseView', sel: '- setExternalPixelBuffer:', mode: 'extpb' }
  ];

  var fxLastPending = null;
  var fxTicks = 0;
  var fxTimer = null;
  function tryForensicsOnce() {
    var pending = [];
    for (var i = 0; i < FX_METHODS.length; i++) {
      var e = FX_METHODS[i];
      var key = e.cls + ' ' + e.sel;
      // route / v4 hooks live alongside (not instead of) a v2 hook on the same
      // IMP, so they keep a separate bookkeeping key.
      var dual = (e.mode === 'route' || e.mode === 'cronstart' || e.mode === 'cronstop' || e.mode === 'extpb');
      var dkey = dual ? (e.mode + ' ' + key) : key;
      if (counters[dkey] && counters[dkey].attached) continue;
      if (!dual) {
        if (instCounters[key]) continue;
        if (instrumented[key]) continue;
        if (key === 'IJKSDLSampleBufferView + layerClass' && counters['layerclass IJKSDLSampleBufferView']) continue;
      }
      if (settled[dkey]) continue;
      var cls = findClass(e.cls);
      if (cls === null) { pending.push(key); continue; }
      // the class is here but the selector is not: polling cannot make one
      // appear, so say so once (hook_miss) and stop retrying this key.
      if (e.mode !== 'layerclass' && e.mode !== 'pvp') {
        var hasSel = false;
        try { hasSel = (cls[e.sel] !== null && cls[e.sel] !== undefined); } catch (eh) { hasSel = false; }
        if (!hasSel) {
          selMiss[dkey] = (selMiss[dkey] || 0) + 1;
          if (selMiss[dkey] >= 2) { settled[dkey] = true; hookMiss(key, 'class present, selector absent'); }
          else pending.push(key);
          continue;
        }
      }
      var ok = false;
      try {
        if (e.mode === 'count') ok = countHook(e.cls, cls, e.sel, e.opts);
        else if (e.mode === 'call') ok = instrumentMethod(e.cls, cls, e.sel, e.opts);
        else if (e.mode === 'inst') ok = instHook(e.cls, cls, e.sel);
        else if (e.mode === 'layerclass') ok = probeLayerClass(e.cls, cls);
        else if (e.mode === 'gate') ok = gateHook(e.cls, cls, e.sel);
        else if (e.mode === 'cron') ok = cronHook(e.cls, cls, e.sel);
        else if (e.mode === 'gpuset') ok = gpusetHook(e.cls, cls, e.sel);
        else if (e.mode === 'pixfmt') ok = pixfmtHook(e.cls, cls, e.sel);
        else if (e.mode === 'route') ok = routeHook(e.cls, cls, e.sel, e.route);
        else if (e.mode === 'pvp') ok = pipPlayerViewProbe(e.cls);
        else if (e.mode === 'cronstart') ok = cronStartHook(e.cls, cls, e.sel);
        else if (e.mode === 'cronstop') ok = cronStopHook(e.cls, cls, e.sel);
        else if (e.mode === 'extpb') ok = extpbHook(e.cls, cls, e.sel);
      } catch (err) { ok = false; }
      if (!ok) pending.push(key);
    }
    if (!viewWatchDone) installViewWatch();
    return pending;
  }

  function startForensics() {
    var pending = tryForensicsOnce(); // immediate first pass
    fxLastPending = pending.join(';');
    if (pending.length === 0) { log('fx_ready', { at: 0, mounted: mountedCount() }); return; }
    if (fxTicks === 0) log('fx_pending', { list: trunc(fxLastPending, 320) });
    fxTimer = setInterval(function () {
      try {
        fxTicks++;
        var p = tryForensicsOnce();
        var joined = p.join(';');
        if (joined !== fxLastPending) {
          if (p.length === 0) {
            log('fx_ready', { at: fxTicks, mounted: mountedCount() });
          } else if (fxTicks <= 10) {
            log('fx_pending', { list: trunc(joined, 320) });
          }
          fxLastPending = joined;
        }
        if (p.length === 0 || fxTicks >= 240) {
          if (fxTimer !== null) { clearInterval(fxTimer); fxTimer = null; }
          if (p.length > 0) {
            for (var j = 0; j < p.length; j++) {
              reportMissing(p[j].split(' ')[0], 'target never appeared: ' + p[j]);
              hookMiss(p[j], 'target class never appeared');
            }
            log('fx_missing_final', { list: trunc(p.join(';'), 320) });
          }
        }
      } catch (e) {}
    }, 5000);
  }

  // retry loop: classes register lazily when the player is created
  var MAX_ATTEMPTS = 10;

  function tryInstrument(round) {
    var missing = [];
    var names = Object.keys(TARGETS);
    for (var i = 0; i < names.length; i++) {
      var name = names[i];
      if (!instrumentClassIfPresent(name)) missing.push(name);
    }
    listInterestingClasses();
    if (missing.length > 0 && round < MAX_ATTEMPTS) {
      log('instrument_retry', { round: round, missing: missing });
      setTimeout(function () {
        try { tryInstrument(round + 1); } catch (e) { log('retry_error', { error: trunc(e.message || ('' + e), 150) }); }
      }, 2000 * Math.min(round + 1, 5));
    } else if (missing.length > 0) {
      log('instrument_missing_final', { missing: missing });
    }
  }

  // ---------------------------------------------------------------------------
  // entry
  // ---------------------------------------------------------------------------
  log('heartbeat', {
    probe: PROBE_VERSION,
    frida: (typeof Frida !== 'undefined') ? Frida.version : null,
    pid: Process.id,
    arch: Process.arch,
    platform: Process.platform
  });

  try {
    observeLifecycleNotifications();
  } catch (e) {
    log('setup_error', { step: 'lifecycle', error: trunc(e.message || ('' + e), 150) });
  }

  try {
    tryInstrument(0);
  } catch (e) {
    log('setup_error', { step: 'instrument', error: trunc(e.message || ('' + e), 150) });
  }

  try {
    startForensics();
  } catch (e) {
    log('setup_error', { step: 'forensics', error: trunc(e.message || ('' + e), 150) });
  }

  try {
    startCountSummary();
  } catch (e) {
    log('setup_error', { step: 'count_summary', error: trunc(e.message || ('' + e), 150) });
  }

  try {
    startLayerStateTicker(); // v3 G2: 5s state line per live AVSampleBufferDisplayLayer
  } catch (e) {
    log('setup_error', { step: 'layer_state_ticker', error: trunc(e.message || ('' + e), 150) });
  }

  try {
    startExtpbTicker(); // v4 H3: 30s counter line for setExternalPixelBuffer:
  } catch (e) {
    log('setup_error', { step: 'extpb_ticker', error: trunc(e.message || ('' + e), 150) });
  }

  try {
    dumpState('init');
  } catch (e) {
    log('setup_error', { step: 'init_dump', error: trunc(e.message || ('' + e), 150) });
  }

  // startup line: what this build is, and how much got mounted on the first
  // pass (lazy classes keep attaching; probe_ready reports the settled count).
  // Keep it short: the 400-char cap would stub away the numbers otherwise.
  log('probe_boot', {
    probe: PROBE_VERSION,
    mounted: mountedCount(),
    fxTargets: FX_METHODS.length,
    targets: Object.keys(TARGETS).length,
    pending: (fxLastPending === '' ? 0 : fxLastPending.split(';').length)
  });
})();
