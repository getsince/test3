defmodule Dev do
  alias T.{Media, Accounts}
  alias T.Accounts.{Profile}
  alias Pigeon.APNS
  alias Pigeon.APNS.Notification

  @task_supervisor T.TaskSupervisor

  def download_selected_photos_from_s3(photos) do
    bucket = Media.bucket()

    ensure_task_supervisor()

    Task.Supervisor.async_stream_nolink(
      @task_supervisor,
      photos,
      fn key ->
        IO.puts("Downloading #{key}")

        %{body: content, headers: headers} = ExAws.S3.get_object(bucket, key) |> ExAws.request!()

        jpeg? =
          String.ends_with?(key, "jpg") ||
            :proplists.get_value("Content-Type", headers, nil) == "image/jpeg"

        if jpeg? do
          IO.puts("Saving #{key}")
          File.write!(key, content)
        else
          IO.puts("Discarding #{key} -> not jpeg")
        end
      end,
      max_concurrency: 100,
      timeout: 60000,
      on_timeout: :kill_task,
      ordered: false
    )
  end

  def schedule_3dpics_jobs do
    s3_list_photos(~D[2021-01-16])
    |> Enum.map(fn s3_key -> Media.pic3d_job(s3_key) |> Ecto.Changeset.change() end)
    # |> Enum.take(5)
    |> Oban.insert_all()
  end

  def download_all_photos_from_s3 do
    bucket = Media.bucket()

    ensure_task_supervisor()

    stream =
      Media.bucket()
      |> ExAws.S3.list_objects()
      |> ExAws.stream!()

    Task.Supervisor.async_stream_nolink(
      @task_supervisor,
      stream,
      fn %{key: key} ->
        IO.puts("Downloading #{key}")

        %{body: content, headers: headers} = ExAws.S3.get_object(bucket, key) |> ExAws.request!()

        jpeg? =
          String.ends_with?(key, "jpg") ||
            :proplists.get_value("Content-Type", headers, nil) == "image/jpeg"

        if jpeg? do
          IO.puts("Saving #{key}")
          File.write!(key, content)
        else
          IO.puts("Discarding #{key} -> not jpeg")
        end
      end,
      max_concurrency: 100,
      timeout: 60000,
      on_timeout: :kill_task,
      ordered: false
    )
  end

  defmodule N do
    alias T.{Repo, Accounts.APNSDevice}
    alias Pigeon.APNS
    alias Pigeon.APNS.Notification

    def all_device_ids do
      Repo.all(APNSDevice)
      |> Repo.preload(user: :profile)
      |> Enum.map(fn t ->
        %{device: Base.encode16(t.device_id), user: %{name: t.user.profile.name, id: t.user_id}}
      end)
    end

    def notify_all do
      all_device_ids
      |> Enum.map(fn %{device: device} ->
        notify(device)
      end)
    end

    def notify(device_id) do
      topic = Application.fetch_env!(:pigeon, :apns)[:apns_default].topic

      ""
      |> Notification.new(device_id, topic)
      |> Notification.put_alert(%{
        "title" => "Твоя подборка на сегодня готова 😉",
        # "subtitle" => "Five Card Draw",
        "body" => "Заходи скорее!"
      })
      # |> Notification.put_custom(%{"thread_id" => "1"})
      |> Notification.put_badge(999)
      # |> Notification.put_category()
      # |> Notification.put_content_available()
      # |> Notification.put_custom()
      # |> Notification.put_mutable_content()
      |> Map.put(:collapse_id, "nudge")
      |> APNS.push()
    end
  end

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

  def rex do
    # Rexbug.Printing.MFA
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

  def dump_state(data, path) do
    File.write(path, :erlang.term_to_binary(data))
  end

  def read_state(path) do
    data = File.read!(path)
    :erlang.binary_to_term(data)
  end

  def upload_photos(path \\ "~/Downloads/tinder_pics") do
    path = Path.expand(path)

    path
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".jpg"))
    |> Enum.map(fn file -> Path.join(path, file) end)
    |> Enum.map(fn file ->
      uuid = Ecto.UUID.generate()
      File.cp(file, Path.join([path, uuid]))
      {uuid, Path.join([path, uuid])}
    end)
    |> Enum.map(fn {key, path} ->
      body = File.read!(path)
      ExAws.S3.put_object(Media.bucket(), key, body) |> ExAws.request!()
      key
    end)
  end

  def create_ets do
    :ets.new(:photos, [:public, :named_table])
  end

  def setup do
    create_ets()
    mocks = read_mock_data_options()
    photos = list_photos()
    {mocks, photos}
  end

  def random_profiles(
        count \\ 1000,
        mocks,
        male_photos \\ male_photos(),
        female_photos \\ female_photos(),
        male_names \\ male_names(),
        female_names \\ female_names()
      ) do
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

        female? = :rand.uniform() > 0.45
        gender = if female?, do: "F", else: "M"

        photos =
          if female? do
            female_photos
          else
            male_photos
          end
          |> Enum.shuffle()
          |> Enum.take(4)

        name =
          if female? do
            female_names
          else
            male_names
          end
          |> Enum.random()

        %Profile{
          photos: photos,
          times_liked: 0,
          gender: gender,
          name: name,
          birthdate: ~D[1997-05-11],
          city: mocks.cities |> Enum.random(),
          first_date_idea: mocks.first_date_ideas |> Enum.random(),
          most_important_in_life: mocks.most_importent_in_life |> Enum.random(),
          height: 150 + :rand.uniform(50),
          interests: mocks.interests |> Enum.shuffle() |> Enum.take(rand_count(2, 5)),
          job: mocks.companies |> Enum.random(),
          occupation: mocks.jobs |> Enum.random(),
          major: if(educated?, do: mocks.majors |> Enum.random()),
          university: if(educated?, do: mocks.unis |> Enum.random()),
          tastes:
            Map.new(tastes, fn k ->
              value =
                case k do
                  _text when k in [:smoking, :alcohol] ->
                    Enum.random(["никогда", "редко", "иногда", "регулярно"])

                  _list ->
                    mocks[k] |> Enum.shuffle() |> Enum.take(rand_count(1, 5))
                end

              {k, value}
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

  defp male_names do
    read_options("~/Downloads/Options/male_names.txt")
  end

  defp male_photos do
    s3_list_photos(~D[2021-02-02]) |> Enum.filter(&String.ends_with?(&1, ".jpg"))
  end

  defp female_names do
    read_options("~/Downloads/Options/female_names.txt")
  end

  defp female_photos do
    s3_list_photos(~D[2021-01-16]) |> Enum.filter(&String.ends_with?(&1, ".jpg"))
  end

  def persist_profiles(profiles) do
    ensure_task_supervisor()

    Task.Supervisor.async_stream_nolink(
      @task_supervisor,
      profiles,
      fn {:ok, profile} ->
        phone_number = phone_number()

        T.Repo.transaction(fn ->
          {:ok, user} = Accounts.register_user(%{"phone_number" => phone_number})
          {:ok, profile} = Accounts.onboard_profile(user.profile, Map.from_struct(profile))
        end)
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
        photos = s3_list_photos(~D[2021-01-16]) |> Enum.filter(&String.ends_with?(&1, ".jpg"))
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

  def s3_list_photos_today do
    s3_list_photos(Date.utc_today())
  end

  def schedule_personality_overlap do
    import Ecto.Query

    Profile
    |> where(gender: "F")
    |> select([p], p.user_id)
    |> T.Repo.all()
    |> Enum.map(fn user_id ->
      Oban.insert(T.Feeds.PersonalityOverlapJob.new(%{user_id: user_id}))
    end)
  end

  def s3_list_photos(date) do
    ExAws.S3.list_objects(Media.bucket())
    |> ExAws.stream!()
    |> Stream.filter(fn %{last_modified: last_modified} ->
      {:ok, dt, _} = DateTime.from_iso8601(last_modified)
      Date.compare(dt, date) == :eq
    end)
    |> Enum.map(fn %{key: k} -> k end)
  end

  def s3_list_photos do
    ExAws.S3.list_objects(Media.bucket()) |> ExAws.stream!() |> Enum.map(fn %{key: k} -> k end)
  end

  defp read_options(path) do
    Path.expand(path)
    |> File.read!()
    |> String.split("\n")
    |> Enum.reject(fn s -> String.trim(s) == "" end)
  end

  def read_mock_data_options(path \\ "~/Downloads/Options") do
    path = Path.expand(path)

    File.ls!(path)
    |> Enum.reduce(%{}, fn file, acc ->
      key = file |> String.replace(".txt", "") |> String.to_existing_atom()
      contents = read_options(Path.join(file, path))
      Map.put(acc, key, contents)
    end)
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

  defp maybe_add_mock_field(acc, key, vals) when is_list(vals) do
    Map.update(acc, key, [], fn prev ->
      vals ++ prev
    end)
  end

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
      %{message: TWeb.MessageView.render("show.json", %{message: message})}
    )
  end

  defp other_user_id(match) do
    %T.Matches.Match{user_id_1: id1, user_id_2: id2} = match
    [other_id] = [id1, id2] -- ["00000177-8336-5e0e-0242-ac1100030000"]
    other_id
  end
end

defmodule Support do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init("support:" <> user_id = topic) do
    TWeb.Endpoint.subscribe(topic)
    {:ok, %{id: user_id}}
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

  defp add_and_broadcast_message(%{id: user_id}, attrs) do
    {:ok, message} = T.Support.add_message(user_id, admin_id(), attrs)

    TWeb.Endpoint.broadcast!(
      "support:#{user_id}",
      "message:new",
      %{message: TWeb.MessageView.render("show.json", %{message: message})}
    )
  end

  defp admin_id do
    T.Support.admin_id()
  end
end
