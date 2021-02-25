const mediaConstraints = {
  audio: true,
  video: true,
};

const reportError = (where) => (error) => {
  console.error(where, error);
};

function log() {
  console.log(...arguments);
}

function setVideoStream(videoElement, stream) {
  videoElement.srcObject = stream;
}

function unsetVideoStream(videoElement) {
  if (videoElement.srcObject) {
    videoElement.srcObject.getTracks().forEach((track) => track.stop());
  }

  videoElement.removeAttribute("src");
  videoElement.removeAttribute("srcObject");
}

const devices = navigator.mediaDevices;

class WebRTC {
  hook;
  peerConnection;
  remoteStream = new MediaStream();

  constructor(hook) {
    this.hook = hook;
  }

  async iceServers() {
    return await new Promise((resolve) => {
      this.hook.pushEvent("ice-servers", {}, ({ ice_servers }) => {
        resolve(ice_servers);
      });
    });
  }

  async createPeerConnection(stream) {
    let iceServers = await this.iceServers();
    let pc = new RTCPeerConnection({ iceServers });

    pc.ontrack = (event) => this.handleOnTrack(event);
    pc.onicecandidate = (event) => this.handleIceCandidate(event);
    pc.onconnectionstatechange = (event) =>
      this.handleConnectionStateChange(event);
    stream.getTracks().forEach((track) => pc.addTrack(track));

    return pc;
  }

  handleOnTrack(event) {
    log(event);
    this.remoteStream.addTrack(event.track);
  }

  handleIceCandidate(event) {
    if (!!event.candidate) {
      this.pushPeerMessage("ice-candidate", event.candidate);
    }
  }

  handleConnectionStateChange(event) {
    console.log(event);
    event = new CustomEvent("connectionstatechange", {
      detail: { state: event.target.connectionState },
      bubbles: true,
    });
    this.hook.el.dispatchEvent(event);
  }

  async connect() {
    connectButton.disabled = true;
    disconnectButton.disabled = false;
    callButton.disabled = false;

    const localStream = await devices.getUserMedia(mediaConstraints);
    console.log("local stream", localStream);
    setVideoStream(localVideo, localStream);

    this.peerConnection = await this.createPeerConnection(localStream);
  }

  async call() {
    let offer = await this.peerConnection.createOffer();
    this.peerConnection.setLocalDescription(offer);
    this.pushPeerMessage("video-offer", offer);
  }

  async answerCall(offer) {
    // if (!this.peerConnection) return;
    this.receiveRemote(offer);
    let answer = await this.peerConnection.createAnswer();
    await this.peerConnection.setLocalDescription(answer);
    this.pushPeerMessage("video-answer", this.peerConnection.localDescription);
  }

  receiveRemote(offer) {
    let remoteDescription = new RTCSessionDescription(offer);
    this.peerConnection.setRemoteDescription(remoteDescription);
  }

  async pushPeerMessage(type, content) {
    this.hook.pushEvent("peer-message", {
      body: JSON.stringify({ type, content }),
    });
  }

  disconnect() {
    connectButton.disabled = false;
    disconnectButton.disabled = true;
    callButton.disabled = true;

    unsetVideoStream(localVideo);
    unsetVideoStream(remoteVideo);

    if (this.peerConnection) this.peerConnection.close();
    this.peerConnection = null;
    this.remoteStream = new MediaStream();
    setVideoStream(remoteVideo, this.remoteStream);

    this.pushPeerMessage("disconnect", {});
  }
}

// caller pov:
// 1. connect (iceServers, createPeerConnection)
// 2a. call (createOffer, setLocalDescription, send video-offer)
// 2b. receive video-answer (receiveRemote, setRemoteDescription)
// 3. ice candidates

// receiveer pov:
// 1. connect (iceServers, createPeerConnection)
// 2a. receive video-offer, answerCall (receiveRemote, setRemoteDescription, createAnswer, setLocalDescription)
// 2b. send video-answer
// 3. ice candidates

const WebRTCHook = {
  mounted() {
    window.connectButton = document.getElementById("connect");
    window.callButton = document.getElementById("call");
    window.disconnectButton = document.getElementById("disconnect");

    window.remoteVideo = document.getElementById("remote-stream");
    window.localVideo = document.getElementById("local-stream");

    disconnectButton.disabled = true;
    callButton.disabled = true;

    window.webrtc = window.webrtc || new WebRTC(this);
    setVideoStream(remoteVideo, webrtc.remoteStream);

    connectButton.onclick = () => webrtc.connect();
    callButton.onclick = () => webrtc.call();
    disconnectButton.onclick = () => webrtc.disconnect();

    this.handleEvent("peer-message", ({ body }) => {
      const message = JSON.parse(body);

      switch (message.type) {
        case "video-offer":
          log("peer offered: ", message.content);
          if (!webrtc.peerConnection) break;
          webrtc.answerCall(message.content);
          break;

        // TODO
        case "SessionDescription":
          log("peer offered: ", message.content);
          if (!webrtc.peerConnection) break;
          webrtc.answerCall(message.content);
          break;

        case "video-answer":
          log("peer answered: ", message.content);
          if (!webrtc.peerConnection) break;
          webrtc.receiveRemote(message.content);
          break;

        case "ice-candidate":
          log("candidate: ", message.content);
          if (!webrtc.peerConnection) break;
          let candidate = new RTCIceCandidate(message.content);
          webrtc.peerConnection
            .addIceCandidate(candidate)
            .catch(reportError("adding and ice candidate"));
          break;

        case "disconnect":
          if (!webrtc.peerConnection) break;
          webrtc.disconnect();
          break;

        default:
          reportError("unhandled message type")(message.type);
      }
    });
  },
};

export { WebRTCHook };
