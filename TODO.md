- add "typing ..."
- benchmark
- plug attack
- maybe limit # of times a profile is shown in feeds to limit superstars
- test https://github.com/ruslandoga/test3/pull/10/files
- on ios, make it run on ios10
- multiple nomad nodes, distributed within the same vpc
- loki
- tracing
- read https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/APNSOverview.html#//apple_ref/doc/uid/TP40008194-CH8-SW1

# TODO ways to track matches:

# 1. each match on join track itself on topic with me, then I can list everyone online for me easily

# on new match -> both users track each other

# on unmatch -> both users untrack each other

# 2. each user track themselves on topic online:user_id, then I can fetch if each is online easily, but diffs are a bit hacky and I subscribe to each mate's `online:user_id` topic

# 3. custom tracker (ideal case)

# 1. total subscriptions (#online users, #), total broadcasts, total processes

# - total presences (#online users)

# - total (not really) pubsub subscriptions (#online users \* #matches for user)

# 2.

# - total presences (#online users (\*2 since two topics: global and notifications:),

# - total (not really) pubsub subscriptions (#online users \* #matches for user)

# - total broadcasts (#matches for that user who went offline/online)

# 3.

# - total presences (1?)

# - total subs (#online users)

# TODO remove presence in amtch channel

# TODO pick 1. I think

# TODO remove macth:<> channel, and do this presence stuff in the new matches:<user-id> channel

# TODO on matches channel I can budge/poke/touch (commemorate daft punk) someone

# if touched, send apns

# if no response from device about notification delivery, send sms

# how? Task.Supervisor.start_child(@sup, fn -> apns send, receive :ack timeout -> send sms end)

# if touched is online -> send in-app notification, wait for ack, if no ack -> send apns

# if touched is not online -> send apns and wait for ack, if no ack -> send sms

# on ack, clear notifications on screen?

# webrtc -> totally macthes:<uuid> thing

# if presence says the mate is online, can init call, lower id sends offer, higher id waits for it

# call(mate_id) -> notification -> response (yes/no) -> response
