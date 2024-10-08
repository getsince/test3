defmodule SinceWeb.Router do
  use SinceWeb, :router

  import SinceWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {SinceWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api/mobile/auth", SinceWeb do
    pipe_through [:api, :fetch_current_user_from_bearer_token, :require_not_authenticated_user]
    post "/verify-apple", MobileAuthController, :verify_apple_id
  end

  scope "/api", SinceWeb do
    pipe_through [:api]

    post "/app-store-notification",
         AppStoreNotificationController,
         :process_app_store_notification
  end

  scope "/api", SinceWeb do
    pipe_through [:api, :fetch_current_user_from_bearer_token, :require_authenticated_user]
    get "/ip-location", LocationController, :get
    post "/upload-preflight", MediaController, :create_upload_form
    post "/ios/device-token", DeviceController, :create_ios_token
    # TODO remove
    post "/ios/push-token", DeviceController, :create_push_token
    delete "/mobile/account", MobileAccountController, :delete
    delete "/mobile/auth", MobileAuthController, :delete
  end

  scope "/admin", SinceWeb do
    pipe_through [:browser, :dashboard_auth]

    live_session :admin do
      live "/", AdminLive.Index, :index
      live "/profiles", ProfileLive.Index, :index
      live "/registered_profiles", ProfileLive.Index, :sort_by_registration
      live "/stickers", StickerLive.Index, :index
      live "/tokens", TokenLive.Index, :index
      live "/tokens/:user_id", TokenLive.Index, :show
      live "/search", SearchLive.Index, :index
    end
  end

  scope "/api/bot", SinceWeb do
    pipe_through [:api]

    post "/:token", BotController, :webhook
  end
end
