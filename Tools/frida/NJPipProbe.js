/*
 * NJPipProbe.js — passive in-process observer of the bilibili live PiP pipeline.
 *
 * Runs inside frida-gadget 17.24.3 in "script" interaction mode, i.e. it is
 * executed automatically at dylib load; it never waits for an external
 * connection. It only RECORDS: it never changes arguments, return values or
 * objects, and every failure is swallowed so the host app cannot crash.
 *
 * Output: NDJSON appended to <NSHomeDirectory()>/Library/NJPiPProbe.ndjson,
 * one JSON object per line: {"ts":<ms>,"ev":"<event>","d":{...}}
 *
 * No Node.js APIs, no require, no process — Frida/ObjC bridge + NativeFunction only.
 */
(function () {
  'use strict';

  var PROBE_VERSION = 'nj-pip-probe-1';

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
      var line = JSON.stringify(obj) + '\n';
      var buf = Memory.allocUtf8String(line);
      var fd = sysOpen(Memory.allocUtf8String(path), O_WRONLY | O_CREAT | O_APPEND, MODE_0644);
      if (fd < 0) return; // 'int' return type gives a plain JS number
      sysWrite(fd, buf, line.length);
      sysClose(fd);
    } catch (e) {
      // never propagate
    }
  }

  function log(ev, d) {
    appendLine({ ts: Date.now(), ev: ev, d: (d === undefined) ? null : d });
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
  // dumpState — snapshot of live objects and their state
  // ---------------------------------------------------------------------------
  var SNAPSHOT_CLASSES = [
    'BBSBPiPManager',
    'BBAVPiPManager',
    'PictureInPictureControllerWrapper',
    'AVPictureInPictureController',
    'AVSampleBufferDisplayLayer',
    'BBPlayerDanmakuService',
    'BBPlayerDanmakuVoutView',
    'BBPlayerChronosContainerView'
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
      var snap = { tag: tag, classes: {} };
      for (var i = 0; i < SNAPSHOT_CLASSES.length; i++) {
        var name = SNAPSHOT_CLASSES[i];
        try {
          var cls = findClass(name);
          if (cls === null) {
            snap.classes[name] = { registered: false };
            continue;
          }
          var instances = ObjC.chooseSync(cls);
          var entry = { registered: true, count: instances.length, addrs: [] };
          for (var j = 0; j < instances.length; j++) {
            entry.addrs.push(instances[j].handle.toString());
          }
          // detailed per-instance state for the interesting classes
          if (name === 'AVPictureInPictureController' && instances.length <= 8) {
            entry.details = [];
            for (var k = 0; k < instances.length; k++) {
              try { entry.details.push(snapshotOnePiP(instances[k])); } catch (e1) { entry.details.push({ error: trunc(e1.message, 100) }); }
            }
          } else if (name === 'AVSampleBufferDisplayLayer' && instances.length <= 16) {
            entry.details = [];
            for (var m = 0; m < instances.length; m++) {
              try { entry.details.push(snapshotOneLayer(instances[m])); } catch (e2) { entry.details.push({ error: trunc(e2.message, 100) }); }
            }
          } else if (name === 'BBPlayerDanmakuService' && instances.length <= 8) {
            entry.details = [];
            for (var q = 0; q < instances.length; q++) {
              try { entry.details.push(snapshotOneDanmakuService(instances[q])); } catch (e3) { entry.details.push({ error: trunc(e3.message, 100) }); }
            }
          }
          snap.classes[name] = entry;
        } catch (e) {
          snap.classes[name] = { error: trunc(e.message || ('' + e), 120) };
        }
      }
      log('state', snap);
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
      var hits = names.filter(function (n) {
        return n.indexOf('PlayerContainer') !== -1 || n.indexOf('BBPictureInPicture') !== -1;
      });
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
    dumpState('init');
  } catch (e) {
    log('setup_error', { step: 'init_dump', error: trunc(e.message || ('' + e), 150) });
  }
})();
