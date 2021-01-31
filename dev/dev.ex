defmodule Dev do
  alias T.{Media, Accounts}
  alias T.Accounts.{Profile}
  alias Pigeon.APNS
  alias Pigeon.APNS.Notification

  def push_notification(
        dev_id \\ "8DD777E4366CAA4CE148B8BC77ECF37673A603C78B3D2F2E91C09F1EE07DE178"
      ) do
    message = ""

    topic = Application.fetch_env!(:pigeon, :apns)[:apns_default].topic

    message
    |> Notification.new(dev_id, topic)
    |> Notification.put_alert(%{
      "title" => "Это матч!",
      # "subtitle" => "Five Card Draw",
      "body" => "Вася пупкин ждёт тебя!"
    })
    |> Notification.put_custom(%{"thread_id" => "1"})
    |> Notification.put_badge(1)
    # |> Notification.put_category()
    # |> Notification.put_content_available()
    # |> Notification.put_custom()
    # |> Notification.put_mutable_content()
    # |> Map.put(:collapse_id, "1")
    |> APNS.push()
  end

  def bucket do
    Media.bucket()
  end

  def buckets do
    ExAws.S3.list_buckets() |> ExAws.request!()
  end

  def convert_tinder_photos_to_jpeg(path \\ "~/Downloads/tinder_pics") do
    path = Path.expand(path)

    path
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".webp"))
    |> Enum.map(fn file ->
      Path.join(path, file)
    end)
    |> Enum.each(fn webp ->
      jpg = String.replace_suffix(webp, ".webp", ".jpg")
      {_, 0} = System.cmd("convert", [webp, jpg])
    end)
  end

  def upload_photos(path \\ "~/Downloads/tinder_pics") do
    path = Path.expand(path)

    path
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".jpg"))
    |> Enum.map(fn file -> Path.join(path, file) end)
    |> Enum.map(fn file ->
      uuid = Ecto.UUID.generate() <> ".jpg"
      File.cp(file, Path.join([path, uuid]))
      {uuid, Path.join([path, uuid])}
    end)
    |> Enum.each(fn {key, path} ->
      body = File.read!(path)
      ExAws.S3.put_object(Media.bucket(), key, body) |> ExAws.request!()
    end)
  end

  def create_ets do
    :ets.new(:photos, [:public, :named_table])
  end

  def setup do
    create_ets()
    mocks = read_mock_data_csv()
    photos = list_photos()
    {mocks, photos}
  end

  @task_supervisor T.TaskSupervisor

  def random_profiles(count \\ 50, mocks, photos) do
    ensure_task_supervisor()

    Task.Supervisor.async_stream_nolink(
      @task_supervisor,
      1..count,
      fn _ ->
        educated? = :rand.uniform() >= 0.5

        tastes =
          [
            :music,
            :sports,
            :alcohol,
            :smoking,
            :books,
            :currently_studying,
            :tv_shows,
            :languages,
            :musical_instruments,
            :movies,
            :social_networks,
            :cuisines,
            :pets
          ]
          |> Enum.shuffle()
          |> Enum.take(rand_count(7, 13))

        %Profile{
          photos: Enum.shuffle(photos) |> Enum.take(4),
          times_liked: 0,
          gender: "F",
          name: mocks.names |> Enum.random(),
          birthdate: ~D[2000-01-01],
          city: mocks.cities |> Enum.random(),
          first_date_idea: mocks.first_date_ideas |> Enum.random(),
          most_important_in_life: mocks.most_importent_in_life |> Enum.random(),
          height: 99,
          interests: mocks.interests |> Enum.shuffle() |> Enum.take(rand_count(2, 5)),
          job: mocks.companies |> Enum.random(),
          occupation: mocks.jobs |> Enum.random(),
          major: if(educated?, do: mocks.majors |> Enum.random()),
          university: if(educated?, do: mocks.unis |> Enum.random()),
          tastes:
            Map.new(tastes, fn k ->
              {k, mocks[k] |> Enum.shuffle() |> Enum.take(rand_count(1, 5))}
            end)
        }
      end,
      max_concurrency: 200,
      ordered: false
    )
  end

  def phone_number do
    rand = to_string(:rand.uniform(9_999_999))
    "+7000" <> String.pad_leading(rand, 7, "0")
  end

  def ensure_task_supervisor do
    unless Process.whereis(@task_supervisor) do
      Task.Supervisor.start_link(name: @task_supervisor)
    end
  end

  def persist_profiles(profiles) do
    ensure_task_supervisor()

    Task.Supervisor.async_stream_nolink(
      @task_supervisor,
      profiles,
      fn {:ok, profile} ->
        phone_number = phone_number()
        {:ok, user} = Accounts.register_user(%{"phone_number" => phone_number})
        {:ok, profile} = Accounts.onboard_profile(user.profile, Map.from_struct(profile))
        profile
      end,
      max_concurrency: 20,
      ordered: false
    )
  end

  def rand_count(min, max) do
    min = min - 1
    min + :rand.uniform(max - min)
  end

  def list_photos do
    case ets_list_photos() do
      [] ->
        photos = s3_list_photos()
        ets_save_photos(photos)
        photos

      photos ->
        Enum.map(photos, fn {photo} -> photo end)
    end
  end

  defp ets_save_photos(photos) do
    Enum.each(photos, fn photo ->
      :ets.insert(:photos, {photo})
    end)
  end

  defp ets_list_photos do
    :ets.tab2list(:photos)
  end

  defp s3_list_photos do
    ExAws.S3.list_objects(Media.bucket()) |> ExAws.stream!() |> Enum.map(fn %{key: k} -> k end)
  end

  def read_mock_data_csv(path \\ "~/Downloads/User profile multiple choice options - main.csv") do
    [_header | [header | rows]] =
      Path.expand(path)
      |> File.stream!()
      |> NimbleCSV.RFC4180.parse_stream()
      |> Enum.into([])

    [header | Enum.take(rows, 2)]

    Enum.reduce(rows, %{}, fn row, acc ->
      [
        _,
        _,
        female_name,
        city,
        _region,
        job,
        company,
        job_field,
        uni,
        major,
        most_importent_in_life,
        interest,
        first_date_idea,
        music_performer,
        music_genre,
        sport,
        alco,
        smoking,
        book,
        book_author,
        book_genre,
        studying,
        tv_show,
        language,
        musical_instrument,
        movie,
        social_network,
        cuisine,
        pet
      ] = row

      acc
      |> maybe_add_mock_field(:names, female_name)
      |> maybe_add_mock_field(:cities, city)
      |> maybe_add_mock_field(:jobs, job)
      |> maybe_add_mock_field(:companies, company)
      |> maybe_add_mock_field(:job_fields, job_field)
      |> maybe_add_mock_field(:unis, uni)
      |> maybe_add_mock_field(:majors, major)
      |> maybe_add_mock_field(:most_importent_in_life, most_importent_in_life)
      |> maybe_add_mock_field(:interests, interest)
      |> maybe_add_mock_field(:first_date_ideas, first_date_idea)
      |> maybe_add_mock_field(:music, music_performer)
      |> maybe_add_mock_field(:music, music_genre)
      |> maybe_add_mock_field(:sports, sport)
      |> maybe_add_mock_field(:alcohol, alco)
      |> maybe_add_mock_field(:smoking, smoking)
      |> maybe_add_mock_field(:books, book)
      |> maybe_add_mock_field(:books, book_author)
      |> maybe_add_mock_field(:books, book_genre)
      |> maybe_add_mock_field(:currently_studying, studying)
      |> maybe_add_mock_field(:tv_shows, tv_show)
      |> maybe_add_mock_field(:languages, language)
      |> maybe_add_mock_field(:musical_instruments, musical_instrument)
      |> maybe_add_mock_field(:movies, movie)
      |> maybe_add_mock_field(:social_networks, social_network)
      |> maybe_add_mock_field(:cuisines, cuisine)
      |> maybe_add_mock_field(:pets, pet)
    end)
  end

  defp maybe_add_mock_field(acc, _key, nil), do: acc
  defp maybe_add_mock_field(acc, _key, ""), do: acc

  defp maybe_add_mock_field(acc, key, val) do
    Map.update(acc, key, [], fn prev ->
      [val | prev]
    end)
  end
end

defmodule Chatter do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init("match:" <> match_id = topic) do
    TWeb.Endpoint.subscribe(topic)
    match = T.Repo.get!(T.Matches.Match, match_id)
    {:ok, %{match: match}}
  end

  def text(text) do
    GenServer.call(__MODULE__, {:text, text})
  end

  def photo(s3_key) do
    GenServer.call(__MODULE__, {:photo, s3_key})
  end

  def audio(s3_key) do
    GenServer.call(__MODULE__, {:audio, s3_key})
  end

  def unmatch do
    GenServer.call(__MODULE__, :unmatch)
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "message:new",
          payload: payload
        },
        state
      ) do
    IO.inspect(payload)
    {:noreply, state}
  end

  @impl true
  def handle_call(:unmatch, _from, %{match: match} = state) do
    me = other_user_id(match)
    result = T.Matches.unmatch(me, match.id)
    TWeb.Endpoint.broadcast!("match:#{match.id}", "unmatched", %{})
    {:reply, result, state}
  end

  def handle_call({:text, text}, _from, state) do
    add_and_broadcast_message(state, %{"kind" => "text", "data" => %{"text" => text}})
    {:reply, :ok, state}
  end

  def handle_call({:photo, s3_key}, _from, state) do
    add_and_broadcast_message(state, %{
      "kind" => "photo",
      "data" => %{"s3_key" => s3_key}
    })

    {:reply, :ok, state}
  end

  def handle_call({:audio, s3_key}, _from, state) do
    add_and_broadcast_message(state, %{
      "kind" => "audio",
      "data" => %{"s3_key" => s3_key}
    })

    {:reply, :ok, state}
  end

  defp add_and_broadcast_message(%{match: match}, attrs) do
    {:ok, message} = T.Matches.add_message(match.id, other_user_id(match), attrs)

    TWeb.Endpoint.broadcast!(
      "match:#{match.id}",
      "message:new",
      %{message: TWeb.MatchView.render("message.json", %{message: message})}
    )
  end

  defp other_user_id(match) do
    %T.Matches.Match{user_id_1: id1, user_id_2: id2} = match
    [other_id] = [id1, id2] -- ["18097e3b-64d6-4e14-9076-e6bacc072e30"]
    other_id
  end
end
