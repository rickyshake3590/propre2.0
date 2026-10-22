// Data layer for ProPre2.0.
// When server.pl is running (started by the launcher), timers and live state are shared
// through it, and the mirror screen on a second computer works.
// When it is not (e.g. the file was double-clicked, or the site is on GitHub Pages),
// everything is kept in this browser's localStorage, so nothing needs to be installed.
// In browser mode the control page and output page must be opened in the same browser.
(function () {
  const TIMERS_KEY = 'propre_timers';
  const NEXT_ID_KEY = 'propre_next_id';
  const LIVE_KEY = 'propre_live';

  // Decide the mode once: /api/live only exists when server.pl is running
  let serverMode = false;
  const ready = fetch('/api/live', { cache: 'no-store' })
    .then(res => { serverMode = res.ok; })
    .catch(() => { serverMode = false; });

  async function http(method, url, body) {
    const res = await fetch(url, {
      method,
      cache: 'no-store',
      headers: { 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Request failed');
    return data;
  }

  const serverStore = {
    listTimers: () => http('GET', '/api/timers'),
    createTimer: payload => http('POST', '/api/timers', payload),
    updateTimer: (id, payload) => http('PUT', `/api/timers/${id}`, payload),
    deleteTimer: id => http('DELETE', `/api/timers/${id}`),
    getLive: () => http('GET', '/api/live'),
    setLive: state => http('POST', '/api/live', state),
    network: () => http('GET', '/api/network')
  };

  function read(key, fallback) {
    try {
      const value = JSON.parse(localStorage.getItem(key));
      return value === null ? fallback : value;
    } catch (e) {
      return fallback;
    }
  }

  function write(key, value) {
    localStorage.setItem(key, JSON.stringify(value));
  }

  const browserStore = {
    async listTimers() {
      return read(TIMERS_KEY, []);
    },

    async createTimer(payload) {
      const id = read(NEXT_ID_KEY, 1);
      const now = new Date().toISOString();
      const timer = {
        id,
        name: payload.name,
        duration_seconds: payload.duration_seconds,
        type: payload.type,
        position: payload.position,
        size: payload.size,
        colour: payload.colour,
        show_title: payload.show_title ? 1 : 0,
        show_current_time: payload.show_current_time ? 1 : 0,
        created_at: now,
        updated_at: now
      };
      write(TIMERS_KEY, [...read(TIMERS_KEY, []), timer]);
      write(NEXT_ID_KEY, id + 1);
      return timer;
    },

    async updateTimer(id, payload) {
      const timers = read(TIMERS_KEY, []);
      const timer = timers.find(t => t.id === id);
      if (!timer) throw new Error('Timer not found');
      if ('duration_seconds' in payload) {
        if (!(payload.duration_seconds >= 1)) throw new Error('Duration must be at least 1 second');
        timer.duration_seconds = payload.duration_seconds;
      }
      if ('show_title' in payload) timer.show_title = payload.show_title ? 1 : 0;
      timer.updated_at = new Date().toISOString();
      write(TIMERS_KEY, timers);
      return timer;
    },

    async deleteTimer(id) {
      const timers = read(TIMERS_KEY, []);
      const remaining = timers.filter(t => t.id !== id);
      if (remaining.length === timers.length) throw new Error('Timer not found');
      write(TIMERS_KEY, remaining);
    },

    // Elapsed time keeps advancing while running, so it is computed from the stored stamp
    async getLive() {
      const state = read(LIVE_KEY, null);
      if (!state || !state.timer) return { timer: null, elapsed: 0, isRunning: false };
      const elapsed = state.elapsed + (state.isRunning ? (Date.now() - state.stamp) / 1000 : 0);
      return { timer: state.timer, elapsed, isRunning: state.isRunning };
    },

    async setLive(body) {
      write(LIVE_KEY, {
        timer: body.timer || null,
        elapsed: Number(body.elapsed) || 0,
        isRunning: !!body.isRunning,
        stamp: Date.now()
      });
      return { success: true };
    },

    // The mirror address only exists when the server is running
    async network() {
      return null;
    }
  };

  async function call(name, ...args) {
    await ready;
    return (serverMode ? serverStore : browserStore)[name](...args);
  }

  window.Store = {
    mode: () => ready.then(() => (serverMode ? 'server' : 'browser')),
    listTimers: (...args) => call('listTimers', ...args),
    createTimer: (...args) => call('createTimer', ...args),
    updateTimer: (...args) => call('updateTimer', ...args),
    deleteTimer: (...args) => call('deleteTimer', ...args),
    getLive: (...args) => call('getLive', ...args),
    setLive: (...args) => call('setLive', ...args),
    network: (...args) => call('network', ...args)
  };
})();
