// based on https://github.com/littlelines/littlechat/blob/master/assets/js/app.js

import adapter from "webrtc-adapter";

let users = {};
let localStream;

async function initStream() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: true,
      video: true,
    });

    localStream = stream;
    document.getElementById("local-video").srcObject = stream;
  } catch (e) {
    console.log(e);
  }
}

function addUserConnection(userUuid) {
  if (users[userUuid] === undefined) {
    users[userUuid] = {
      peerConnection: null,
    };
  }

  return users;
}

function removeUserConnection(userUuid) {
  delete users[userUuid];
  return users;
}

function createPeerConnection(lv, fromUser, offer) {
  let newPeerConnection = new RTCPeerConnection({
    iceServers: [{ urls: "stun:global.stun.twilio.com:3478?transport=udp" }],
  });

  users[fromUser].peerConnection = newPeerConnection;

  // Add each local track to the RTCPeerConnection.
  localStream
    .getTracks()
    .forEach((track) => newPeerConnection.addTrack(track, localStream));

  // If creating an answer, rather than an initial offer.
  if (offer !== undefined) {
    newPeerConnection.setRemoteDescription({ type: "offer", sdp: offer });
    newPeerConnection
      .createAnswer()
      .then((answer) => {
        newPeerConnection.setLocalDescription(answer);
        console.log("Sending this ANSWER to the requester:", answer);
        lv.pushEvent("new_answer", { toUser: fromUser, description: answer });
      })
      .catch((err) => console.log(err));
  }

  newPeerConnection.onicecandidate = async ({ candidate }) => {
    // fromUser is the new value for toUser because we're sending this data back
    // to the sender
    lv.pushEvent("new_ice_candidate", { toUser: fromUser, candidate });
  };

  // Don't add the `onnegotiationneeded` callback when creating an answer due to
  // a bug in Chrome.
  if (offer === undefined) {
    newPeerConnection.onnegotiationneeded = async () => {
      try {
        newPeerConnection
          .createOffer()
          .then((offer) => {
            newPeerConnection.setLocalDescription(offer);
            console.log("Sending this OFFER to the requester:", offer);
            lv.pushEvent("new_sdp_offer", {
              toUser: fromUser,
              description: offer,
            });
          })
          .catch((err) => console.log(err));
      } catch (error) {
        console.log(error);
      }
    };
  }

  newPeerConnection.ontrack = async (event) => {
    console.log("Track received:", event);
    document.getElementById(`video-remote-${fromUser}`).srcObject =
      event.streams[0];
  };

  return newPeerConnection;
}

const WebRTC = {
  mounted() {
    this.webrtc = this.handleEvent("want-offer", () => {});
    this.handleEvent("end-call", () => {});
    this.handleEvent("peer-message", () => {});
  },
};

export { JoinCall, HandleOfferRequest, HandleIceCandidateOffer };
