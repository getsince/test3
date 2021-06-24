defmodule Dev do
  alias T.PushNotifications.APNS
  alias Pigeon.APNS.Notification
  import Ecto.Query

  def get_me do
    T.Accounts.get_profile!("00000177-8336-5e0e-0242-ac1100030000")
  end

  def init_feed(profile \\ get_me()) do
    %{loaded: loaded, next_ids: next_ids} = T.Feeds.init_batched_feed(profile)
    seen(loaded, profile)
    {next_ids, profile}
  end

  def continue_feed({next_ids, profile}) do
    %{loaded: loaded, next_ids: next_ids} = T.Feeds.continue_batched_feed(next_ids, profile)
    seen(loaded, profile)
    {next_ids, profile}
  end

  def seen(profiles, me) do
    Enum.each(profiles, fn p -> T.Feeds.mark_profile_seen(p.user_id, by: me.user_id) end)
  end

  def eh do
    data =
      T.Accounts.Profile
      |> where(gender: "M")
      |> select([p], p.user_id)
      |> T.Repo.all()
      |> Enum.map(fn user_id ->
        %{user_id: user_id, gender: "F"}
      end)

    T.Repo.insert_all(T.Accounts.GenderPreference, data, on_conflict: :nothing)
  end

  def save_my_pushkit_token do
    T.Accounts.save_pushkit_device_id(
      "00000179-b463-2a92-1e00-8a0e24440000",
      "ofXkAm-GFl86F9w2D_nD8Xl4e7XM91MaFLKKFrVw8mM",
      Base.decode64!("LtJkLiqNCePTsam/OAOY3G0xKiOTuV/Q+qjT50TYX14=")
    )
  end

  def save_putin_pushkit_token do
    T.Accounts.save_pushkit_device_id(
      "00000179-b46a-4a20-1e00-8a0e24440000",
      "EYm85-92Ula67nTO0RUBVEgsvkGsOrz_z2NG2XPDjy8",
      Base.decode64!("amYWsQWgDcOlLFkBDbDIZ7HXuP0wCrs0bol2wEHRr6Q=")
    )
  end

  def pushkit_call(
        dev_id \\ "FD8502163BF321CE5CAC82F04FE570DD17727C347D75F99E66009BD46D3864D4",
        caller_id \\ "00000179-b46a-4a20-1e00-8a0e24440000",
        caller_name \\ "налоговая"
      ) do
    n = %Notification{
      device_token: dev_id,
      # topic: "app.getsince.another.voip",
      topic: Application.fetch_env!(:pigeon, :apns)[:apns_default].topic <> ".voip",
      push_type: "voip",
      expiration: 0,
      payload: %{
        "user_id" => caller_id,
        "name" => caller_name
      }
    }

    n
    |> APNS.push_all_envs()
  end

  # 00000179-b463-2a92-1e00-8a0e24440000 (token=ofXkAm-GFl86F9w2D_nD8Xl4e7XM91MaFLKKFrVw8mM)
  def add_me do
    T.Accounts.get_user_by_phone_number("+79778467871")

    # token = T.Accounts.generate_user_session_token(me, "mobile")
    # T.Accounts.UserToken.encoded_token(token)
  end

  # 00000179-b46a-4a20-1e00-8a0e24440000 (token=EYm85-92Ula67nTO0RUBVEgsvkGsOrz_z2NG2XPDjy8)
  def add_putin do
    phone_number = "+79778467872"

    T.Accounts.register_user(%{phone_number: phone_number})
    putin = T.Accounts.get_user_by_phone_number(phone_number)

    T.Accounts.onboard_profile(putin.profile, %{
      name: "Putin",
      gender: "M",
      latitude: 50,
      longitude: 50
    })

    token = T.Accounts.generate_user_session_token(putin, "mobile")
    T.Accounts.UserToken.encoded_token(token)
  end

  # 00000179-b46b-52f2-1e00-8a0e24440000 (token=t8ss42xvk5cKboBGH8YWq1vDDhd2sQ4i8AhkrrYpAWc)
  def add_navalny do
    phone_number = "+79778467873"
    T.Accounts.register_user(%{phone_number: phone_number})
    navalny = T.Accounts.get_user_by_phone_number(phone_number)

    T.Accounts.onboard_profile(navalny.profile, %{
      name: "Navalny",
      gender: "M",
      latitude: 50,
      longitude: 50
    })

    token = T.Accounts.generate_user_session_token(navalny, "mobile")
    T.Accounts.UserToken.encoded_token(token)
  end
end
