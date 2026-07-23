// Focus helpers + small DOM FFI (Items 2 & 5).

///|
/// Focus element by id after the next animation frame (Luna paint).
extern "js" fn defer_focus(id : String) -> Unit =
  #| (id) => {
  #|   const go = () => {
  #|     const el = document.getElementById(id);
  #|     if (el && typeof el.focus === "function") el.focus({ preventScroll: true });
  #|   };
  #|   if (typeof requestAnimationFrame === "function") {
  #|     requestAnimationFrame(() => requestAnimationFrame(go));
  #|   } else {
  #|     setTimeout(go, 0);
  #|   }
  #| }

///|
/// Active element id, or fallback.
extern "js" fn active_element_id(fallback : String) -> String =
  #| (fallback) => {
  #|   const el = document.activeElement;
  #|   if (el && el.id) return el.id;
  #|   return fallback;
  #| }

///|
/// True when focus is the live terminal command input.
extern "js" fn active_is_terminal_input() -> Bool =
  #| () => {
  #|   const el = document.activeElement;
  #|   return !!(el && el.classList && el.classList.contains("terminal-input"));
  #| }

///|
/// Scroll #buffer-body by a fraction of its client height (-1..1). dir: 1 down, -1 up.
extern "js" fn scroll_buffer_page(dir : Int) -> Unit =
  #| (dir) => {
  #|   const el = document.getElementById("buffer-body");
  #|   if (!el) return;
  #|   const delta = Math.max(120, Math.floor(el.clientHeight * 0.9)) * (dir >= 0 ? 1 : -1);
  #|   el.scrollBy({ top: delta, behavior: "auto" });
  #| }

///|
/// Center buffer body scroll (zz).
extern "js" fn scroll_buffer_center() -> Unit =
  #| () => {
  #|   const el = document.getElementById("buffer-body");
  #|   if (!el) return;
  #|   const mid = Math.max(0, (el.scrollHeight - el.clientHeight) / 2);
  #|   el.scrollTo({ top: mid, behavior: "auto" });
  #| }

///|
/// Arm a timeout; returns handle (0 if unavailable).
extern "js" fn arm_timeout(ms : Int, cb : () -> Unit) -> Int =
  #| (ms, cb) => {
  #|   if (typeof setTimeout !== "function") return 0;
  #|   return setTimeout(() => { try { cb(); } catch (e) {} }, ms) | 0;
  #| }

///|
extern "js" fn clear_timeout_handle(handle : Int) -> Unit =
  #| (handle) => {
  #|   if (handle && typeof clearTimeout === "function") clearTimeout(handle);
  #| }
