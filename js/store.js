// Data layer for ProPre2.0.
// On localhost the app talks to server.py and its shared timers.db, as before.
// Anywhere else (e.g. GitHub Pages) everything is kept in this browser's
// localStorage, so every visitor gets their own independent timers and output.
(function () {
  const USE_SERVER = ['localhost', '127.0.0.1'].includes(location.hostname);
  const TIMERS_KEY = 'propre_timers';
  const NEXT_ID_KEY = 'propre_next_id';
  const LIVE_KEY = 'propre_live';

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

  async function http(method, url, body) {
    const res = await fetch(url, {
      method,
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
    deleteTimer: id => http('DELETE', `/api/timers/${id}`),
    getLive: () => http('GET', '/api/live'),
    setLive: state => http('POST', '/api/live', state)
  };

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

    async deleteTimer(id) {
      const timers = read(TIMERS_KEY, []);
      const remaining = timers.filter(t => t.id !== id);
      if (remaining.length === timers.length) throw new Error('Timer not found');
      write(TIMERS_KEY, remaining);
    },

    // Elapsed time keeps advancing while running, same as the server's live state
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
    }
  };

  window.Store = USE_SERVER ? serverStore : browserStore;
})();
