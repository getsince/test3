defmodule StubTwilio do
  @behaviour T.Twilio.Adapter

  @impl true
  def fetch_ice_servers do
    [
      %{
        "url" => "stun:global.stun.twilio.com:3478?transport=udp",
        "urls" => "stun:global.stun.twilio.com:3478?transport=udp"
      },
      %{
        "credential" => "B2AhKtD3x/T0vATYL2FimHFlPMTIJAmAmHBRrqAHEKc=",
        "url" => "turn:global.turn.twilio.com:3478?transport=udp",
        "urls" => "turn:global.turn.twilio.com:3478?transport=udp",
        "username" => "65d32d2326762b02b0133dadd624f74333dea32e5588ef495986d9b5e4b932d3"
      },
      %{
        "credential" => "B2AhKtD3x/T0vATYL2FimHFlPMTIJAmAmHBRrqAHEKc=",
        "url" => "turn:global.turn.twilio.com:3478?transport=tcp",
        "urls" => "turn:global.turn.twilio.com:3478?transport=tcp",
        "username" => "65d32d2326762b02b0133dadd624f74333dea32e5588ef495986d9b5e4b932d3"
      },
      %{
        "credential" => "B2AhKtD3x/T0vATYL2FimHFlPMTIJAmAmHBRrqAHEKc=",
        "url" => "turn:global.turn.twilio.com:443?transport=tcp",
        "urls" => "turn:global.turn.twilio.com:443?transport=tcp",
        "username" => "65d32d2326762b02b0133dadd624f74333dea32e5588ef495986d9b5e4b932d3"
      }
    ]
  end
end
