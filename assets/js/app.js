// Bring phoenix_html to deal with method=PUT/DELETE in forms and buttons
import "phoenix_html";

import Alpine from "alpinejs";
import { Socket } from "phoenix";
import topbar from "topbar";

import { LiveSocket } from "phoenix_live_view";
import { WebRTCHook } from "./hooks/webrtc";

const MessagesHook = {
  mounted() {
    window.addEventListener("phx:page-loading-start", ({ detail }) => {
      if (detail.kind == "patch") {
        this.el.innerHTML = "";
      }
    });
    this.el.scrollTop = this.el.scrollHeight;
  },
  updated() {
    this.el.scrollTop = this.el.scrollHeight;
  },
};

const ScrollDownHook = {
  mounted() {
    this.el.scrollTop = this.el.scrollHeight;
  },
  updated() {
    this.el.scrollTop = this.el.scrollHeight;
  },
};

const ScrollWindowDownHook = {
  mounted() {
    window.scrollTo(0, document.body.scrollHeight);
  },
  updated() {
    window.scrollTo(0, document.body.scrollHeight);
  },
};

const S3 = function (entries, onViewError) {
  entries.forEach((entry) => {
    let formData = new FormData();
    let { url, fields } = entry.meta;

    Object.entries(fields).forEach(([key, val]) => formData.append(key, val));
    formData.append("file", entry.file);

    let xhr = new XMLHttpRequest();
    onViewError(() => xhr.abort());
    xhr.onload = () =>
      xhr.status === 204 ? entry.progress(100) : entry.error();
    xhr.onerror = () => entry.error();

    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        let percent = Math.round((event.loaded / event.total) * 100);
        if (percent < 100) {
          entry.progress(percent);
        }
      }
    });

    xhr.open("POST", url, true);
    xhr.send(formData);
  });
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  uploaders: { S3 },
  hooks: {
    MessagesHook,
    ScrollDownHook,
    ScrollWindowDownHook,
    WebRTCHook,
  },
  dom: {
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        Alpine.clone(from, to);
      }
    },
  },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (info) => topbar.show());
window.addEventListener("phx:page-loading-stop", (info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();
Alpine.start();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket;
window.Alpine = Alpine;
