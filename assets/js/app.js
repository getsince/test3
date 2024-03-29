// Bring phoenix_html to deal with method=PUT/DELETE in forms and buttons
import "phoenix_html";

// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

import topbar from "topbar";

const BlockedUser = {
  mounted() {
    this.handleEvent("blocked", ({ user_id }) => {
      let button = document.querySelector(
        `[phx-click='block'][phx-value-user-id='${user_id}']`
      );
      button.disabled = true;
      button.innerText = "Blocked";
    });
  },
};

const HiddenUser = {
  mounted() {
    this.handleEvent("hidden", ({ user_id }) => {
      let button = document.querySelector(
        `[phx-click='hide'][phx-value-user-id='${user_id}']`
      );
      button.disabled = true;
      button.innerText = "Hidden";
    });
  },
};

let scrollAt = () => {
  let scrollTop = document.documentElement.scrollTop || document.body.scrollTop;
  let scrollHeight =
    document.documentElement.scrollHeight || document.body.scrollHeight;
  let clientHeight = document.documentElement.clientHeight;
  return (scrollTop / (scrollHeight - clientHeight)) * 100;
};

const ProfilesInfiniteScroll = {
  cursor() {
    const { selector } = this.el.dataset;
    const node = this.el.querySelector(`${selector}:last-child`);
    const { cursorUserId, cursorLastActive, cursorInsertedAt } = node.dataset;
    return { user_id: cursorUserId, last_active: cursorLastActive };
  },

  mounted() {
    this.pending = false;
    window.addEventListener("scroll", () => {
      if (scrollAt() > 90 && !this.pending) {
        this.pending = true;
        this.pushEvent("more", this.cursor());
      }
    });
  },

  updated() {
    this.pending = false;
  },
};

const RegisteredProfilesInfiniteScroll = {
  cursor() {
    const { selector } = this.el.dataset;
    const node = this.el.querySelector(`${selector}:last-child`);
    const { cursorUserId, cursorLastActive, cursorInsertedAt } = node.dataset;
    return { user_id: cursorUserId, inserted_at: cursorInsertedAt };
  },

  mounted() {
    this.pending = false;
    window.addEventListener("scroll", () => {
      if (scrollAt() > 90 && !this.pending) {
        this.pending = true;
        this.pushEvent("more", this.cursor());
      }
    });
  },

  updated() {
    this.pending = false;
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
    ProfilesInfiniteScroll,
    RegisteredProfilesInfiniteScroll,
    BlockedUser,
    HiddenUser,
  },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
