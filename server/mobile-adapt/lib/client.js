// Browser half of the mobile-adapt plugin, hand-written in the exact wire
// format tsdown emits for client bundles: window.__ModuleLoader__.load with a
// CJS-style factory over the module table's require. The id MUST equal the
// loader entry name (@dsh/mobile-adapt); the factory returns the plugin
// exports ({ inject, apply }).
window.__ModuleLoader__.load({
  id: "@dsh/mobile-adapt",
  factory: (require) => {
    var module = { exports: {} };
    var exports = module.exports;
    Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });

    const React = require("react");
    const { IconPanelLeftOutline16, IconCloseOutline16 } = require("@deepseek-ai/dsh-client-ui-primitives");

    const CSS = String.raw`/* ---------- DSH mobile adaptation (<= 767px) ---------- */
@media (max-width: 767px) {
  [data-slot="root"] > div {
    grid-template-columns: 0 minmax(0, 1fr) 0 !important;
  }
  [data-slot="root"] > div > div:has(> [data-slot="sidebar"]) {
    grid-column: 1 !important;
  }
  [data-slot="root"] > div > div:has(> [data-slot="conversation"]) {
    grid-column: 2 !important;
  }
  [data-slot="root"] > div > div:has(> [data-slot="details"]) {
    grid-column: 3 !important;
  }

  [data-slot="root"] > div > div:has(> [data-slot="sidebar"]) {
    position: fixed !important;
    top: 0 !important;
    bottom: 0 !important;
    left: 0 !important;
    width: 100vw !important;
    max-width: 100vw !important;
    transform: translateX(-105%);
    transition: transform 0.24s var(--ds-ease-in-out, ease);
    z-index: 35 !important;
    box-shadow: 0 0 24px rgba(0, 0, 0, 0.28);
    border-right: 1px solid var(--dsw-alias-border-l1, rgba(128,128,128,0.3));
  }
  [data-slot="root"] > div:not([data-sidebar-collapsed]) > div:has(> [data-slot="sidebar"]) {
    transform: translateX(0);
  }

  [data-slot="root"] > div > div:has(> [data-slot="details"]) {
    position: fixed !important;
    inset: 0 !important;
    width: 100% !important;
    transform: translateX(100%);
    transition: transform 0.24s var(--ds-ease-in-out, ease);
    z-index: 15 !important;
  }
  [data-slot="root"] > div:has([data-dsh-mobile-details-open]) > div:has(> [data-slot="details"]) {
    transform: translateX(0);
  }

  [data-slot="details"] > div > div:first-child > button {
    display: none !important;
  }

  [data-slot="root"] > div > [data-side] {
    display: none !important;
  }

  [data-slot="conversation"] textarea {
    font-size: 16px !important;
  }

  [data-slot="root"] > div > [data-shell-overlay] {
    z-index: 36 !important;
  }

  [data-slot="sidebar.settings"] > div {
    align-items: stretch !important;
    justify-content: stretch !important;
  }
  [data-slot="sidebar.settings"] > div > div:nth-child(2) {
    width: 100vw !important;
    max-width: 100vw !important;
    height: 100vh !important;
    max-height: 100vh !important;
    border-radius: 0 !important;
    flex-direction: column !important;
  }
  [data-slot="sidebar.settings"] > div > div:nth-child(2) > nav {
    flex: none !important;
    width: 100% !important;
    flex-direction: row !important;
    align-items: center !important;
    gap: 10px !important;
    padding: 10px 12px !important;
    overflow-x: auto !important;
    border-bottom: 1px solid var(--dsw-alias-border-l1, rgba(128,128,128,0.3));
  }
  [data-slot="sidebar.settings"] > div > div:nth-child(2) > nav > div:first-child {
    flex: none !important;
    white-space: nowrap !important;
  }
  [data-slot="sidebar.settings"] > div > div:nth-child(2) > nav > div:nth-child(2) {
    flex: 1 !important;
    min-width: 0 !important;
    flex-direction: row !important;
    gap: 6px !important;
    overflow-x: auto !important;
  }
  [data-slot="sidebar.settings"] > div > div:nth-child(2) > nav > div:nth-child(2) > button {
    flex: none !important;
    height: 36px !important;
    padding: 6px 12px !important;
    gap: 6px !important;
  }
  [data-slot="sidebar.settings"] > div > div:nth-child(2) > div:nth-child(2) {
    flex: 1 !important;
    min-height: 0 !important;
  }
  [data-slot="sidebar.settings"] > div > div:nth-child(2) > div:nth-child(2) > div:nth-child(2) {
    padding: 0 16px 20px !important;
  }

  [data-slot="conversation.composer.bar"] div:has(> div[data-input-scroll]) > div:last-child {
    flex-wrap: wrap !important;
    row-gap: 8px !important;
  }
  [data-slot="conversation.composer.bar"] div:has(> div[data-input-scroll]) > div:last-child > div:last-child {
    flex: 1 1 100% !important;
    justify-content: flex-end !important;
  }
}

.dsh-mobile-hamburger,
.dsh-mobile-backdrop,
.dsh-mobile-details-close {
  display: none;
}

@media (max-width: 767px) {
  .dsh-mobile-hamburger {
    display: grid;
    place-items: center;
    position: fixed;
    top: 8px;
    left: 8px;
    width: 36px;
    height: 36px;
    border: none;
    border-radius: 50%;
    /* Floating control over the conversation surface: faint ink-tinted
       disc + blur, so it reads like the original rail icon button while
       staying visible on top of any content. */
    background: rgba(128, 128, 128, 0.18);
    background: color-mix(in srgb, var(--dsw-alias-label-primary, #fff) 10%, transparent);
    backdrop-filter: blur(6px);
    -webkit-backdrop-filter: blur(6px);
    color: var(--dsw-alias-label-primary, #fff);
    cursor: pointer;
    z-index: 40;
    -webkit-tap-highlight-color: transparent;
    transition: background-color 0.15s ease, transform 0.1s ease;
  }
  .dsh-mobile-hamburger:active {
    background: var(--dsw-alias-interactive-bg-hover, rgba(128, 128, 128, 0.28));
    transform: scale(0.94);
  }
  .dsh-mobile-hamburger .dsh-icon-open {
    display: block;
  }
  .dsh-mobile-hamburger .dsh-icon-close {
    display: none;
  }
  [data-slot="root"] > div:not([data-sidebar-collapsed]) .dsh-mobile-hamburger .dsh-icon-open {
    display: none;
  }
  [data-slot="root"] > div:not([data-sidebar-collapsed]) .dsh-mobile-hamburger .dsh-icon-close {
    display: block;
  }
  [data-slot="root"] > div:has([data-dsh-mobile-details-open]) .dsh-mobile-hamburger {
    display: none;
  }

  .dsh-mobile-backdrop {
    display: block;
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.35);
    z-index: 24;
    opacity: 0;
    pointer-events: none;
    transition: opacity 0.2s ease;
  }
  [data-slot="root"] > div:not([data-sidebar-collapsed]) .dsh-mobile-backdrop {
    display: none;
  }

  .dsh-mobile-details-close {
    display: grid;
    place-items: center;
    position: fixed;
    top: 8px;
    right: 8px;
    width: 36px;
    height: 36px;
    border: none;
    border-radius: 50%;
    background: rgba(128, 128, 128, 0.18);
    background: color-mix(in srgb, var(--dsw-alias-label-primary, #fff) 10%, transparent);
    backdrop-filter: blur(6px);
    -webkit-backdrop-filter: blur(6px);
    color: var(--dsw-alias-label-primary, #fff);
    cursor: pointer;
    z-index: 26;
    -webkit-tap-highlight-color: transparent;
    transition: background-color 0.15s ease, transform 0.1s ease;
  }
  .dsh-mobile-details-close:active {
    background: var(--dsw-alias-interactive-bg-hover, rgba(128, 128, 128, 0.28));
    transform: scale(0.94);
  }
}`;

    exports.inject = ["slots"];

    exports.apply = function apply(ctx) {
      const style = document.createElement("style");
      style.dataset.dshMobileAdapt = "true";
      style.textContent = CSS;
      document.head.append(style);
      ctx.effect(() => () => { style.remove() }, "mobile-adapt: stylesheet");

      const slots = ctx.get("slots");
      if (slots === undefined) return;
      const layout = ctx.get("layout");

      slots.inject("shell.overlay", () => slots.register(
        { name: "shell.overlay", id: "dsh-mobile" },
        () => {
          const [detailsOpen, setDetailsOpen] = React.useState(false);

          React.useEffect(() => {
            const el = document.querySelector('[data-slot="details"]');
            if (el === null) return;
            const mo = new MutationObserver(() => {
              if (el.querySelector("section") !== null) setDetailsOpen(true);
            });
            mo.observe(el, { childList: true, subtree: true, characterData: true });
            return () => mo.disconnect();
          }, []);

          const toggleSidebar = () => {
            if (layout !== undefined) layout.toggleSidebar();
          };
          const closeDetails = () => {
            if (layout !== undefined) layout.closeDetails();
            setDetailsOpen(false);
          };

          return React.createElement(React.Fragment, null,
            React.createElement("button", {
              className: "dsh-mobile-hamburger",
              type: "button",
              "aria-label": "菜单",
              onClick: toggleSidebar,
            },
              React.createElement(IconPanelLeftOutline16, { size: 18, className: "dsh-icon-open" }),
              React.createElement(IconCloseOutline16, { size: 18, className: "dsh-icon-close" }),
            ),
            React.createElement("div", {
              className: "dsh-mobile-backdrop",
              onClick: toggleSidebar,
            }),
            detailsOpen && React.createElement(React.Fragment, null,
              React.createElement("div", { "data-dsh-mobile-details-open": true }),
              React.createElement("button", {
                className: "dsh-mobile-details-close",
                type: "button",
                "aria-label": "关闭详情",
                onClick: closeDetails,
              }, React.createElement(IconCloseOutline16, { size: 18 })),
            ),
          );
        },
      ));
    };

    return module.exports;
  },
});
