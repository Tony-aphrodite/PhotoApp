// Emulator runs only: this machine's inotify instance limit (128) is almost
// fully used by other apps, so the Firebase CLI's file watchers fail with
// EMFILE. Tests do not need hot reload; make fs.watch a no-op.
const fs = require('fs');
const { EventEmitter } = require('events');
fs.watch = () => Object.assign(new EventEmitter(), { close() {}, ref() { return this; }, unref() { return this; } });
