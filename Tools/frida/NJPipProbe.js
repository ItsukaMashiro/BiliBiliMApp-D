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
 * No Node.js APIs, no require, no process — Frida/ObjC bridge + NativeFunction only.
 */
(function () {
  'use strict';

  var PROBE_VERSION = 'nj-pip-probe-2';
  var PROBE_V = 2;
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
    'DMRenderLayerView'
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
    { cls: 'BFCChronosRendererWrapper', sel: '- copyPixelBuffer', mode: 'count', opts: { sampleFirst: 1 } }
  ];

  var fxLastPending = null;
  var fxTicks = 0;
  var fxTimer = null;
  function tryForensicsOnce() {
    var pending = [];
    for (var i = 0; i < FX_METHODS.length; i++) {
      var e = FX_METHODS[i];
      var key = e.cls + ' ' + e.sel;
      if (counters[key] && counters[key].attached) continue;
      if (instCounters[key]) continue;
      if (instrumented[key]) continue;
      if (key === 'IJKSDLSampleBufferView + layerClass' && counters['layerclass IJKSDLSampleBufferView']) continue;
      var cls = findClass(e.cls);
      if (cls === null) { pending.push(key); continue; }
      var ok = false;
      try {
        if (e.mode === 'count') ok = countHook(e.cls, cls, e.sel, e.opts);
        else if (e.mode === 'call') ok = instrumentMethod(e.cls, cls, e.sel, e.opts);
        else if (e.mode === 'inst') ok = instHook(e.cls, cls, e.sel);
        else if (e.mode === 'layerclass') ok = probeLayerClass(e.cls, cls);
      } catch (err) { ok = false; }
      if (!ok) pending.push(key);
    }
    if (!viewWatchDone) installViewWatch();
    return pending;
  }

  function startForensics() {
    var pending = tryForensicsOnce(); // immediate first pass
    fxLastPending = pending.join(';');
    if (pending.length === 0) { log('fx_ready', { at: 0 }); return; }
    if (fxTicks === 0) log('fx_pending', { list: trunc(fxLastPending, 320) });
    fxTimer = setInterval(function () {
      try {
        fxTicks++;
        var p = tryForensicsOnce();
        var joined = p.join(';');
        if (joined !== fxLastPending) {
          if (p.length === 0) {
            log('fx_ready', { at: fxTicks });
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
    dumpState('init');
  } catch (e) {
    log('setup_error', { step: 'init_dump', error: trunc(e.message || ('' + e), 150) });
  }
})();
