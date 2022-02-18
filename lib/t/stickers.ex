defmodule T.Stickers do
  @moduledoc false

  stickers =
    MapSet.new([
      "веганство",
      "Taurus",
      "meditation",
      "Овен",
      "еда",
      "настольный теннис",
      "Capricon",
      "squash",
      "театр",
      "football",
      "МГУ",
      "хайкинг",
      "Стрелец",
      "Scorpio",
      "hookah",
      "YouTube",
      "урбанистика",
      "Harvard",
      "Санкт-Петербург",
      "Первый МГМУ им. Сеченова",
      "Virgo",
      "Facebook",
      "МГИМО",
      "природа",
      "love beer",
      "квизы",
      "blogging",
      "we love you",
      "quiz",
      "see you",
      "SMM",
      "технологии",
      "Скорпион",
      "роллы",
      "рисование",
      "коньки",
      "Princeton",
      "медитация",
      "cycling",
      "history",
      "вегетарианство",
      "notification",
      "тренажерный зал",
      "blue love you",
      "подкасты",
      "skiing",
      "writing",
      "sushi",
      "блоггинг",
      "pizza",
      "бег",
      "танцы",
      "theater",
      "Козерог",
      "Весы",
      "йога",
      "Aries",
      "коктейли",
      "Libra",
      "Pisces",
      "Gemini",
      "Британская Высшая Школа Дизайна",
      "программирование",
      "Yale",
      "Дева",
      "настольные игры",
      "кулинария",
      "find a relationship",
      "skating",
      "running",
      "podcasts",
      "плавание",
      "Leo",
      "fashion",
      "МИСиС",
      "диджеинг",
      "table tennis",
      "dancing",
      "шахматы",
      "Columbia",
      "urbanism",
      "вино",
      "найти друга",
      "РУДН",
      "пение",
      "Instagram",
      "fitness",
      "история",
      "путешествия",
      "DJing",
      "New York",
      "coding",
      "nature",
      "собака",
      "love wine",
      "cigarettes",
      "Stanford",
      "swimming",
      "суши",
      "сигареты",
      "баскетбол",
      "basketball",
      "photography",
      "эко-активизм",
      "traveling",
      "cat",
      "investments",
      "коворкинг",
      "кальян",
      "planting",
      "hiking",
      "психология",
      "Saggitarius",
      "yoga",
      "пиво",
      "НИУ ВШЭ",
      "кошка",
      "Рыбы",
      "Telegram",
      "chess",
      "board games",
      "painting",
      "vegetarian",
      "University of Pennsylvania",
      "shopping",
      "psychology",
      "горные лыжи",
      "MIT",
      "boxing",
      "find a friend",
      "love cocktails",
      "Телец",
      "food",
      "VK",
      "snowboard",
      "волонтерство",
      "астрология",
      "no connection",
      "футбол",
      "cool",
      "нетворкинг",
      "networking",
      "фотография",
      "сноуборд",
      "Близнецы",
      "велосипед",
      "cars",
      "volunteering",
      "Aquarius",
      "автомобили",
      "technologies",
      "видеоигры",
      "писательство",
      "инвестиции",
      "video games",
      "общение",
      "найти отношения",
      "dog",
      "wait",
      "art",
      "Рак",
      "пицца",
      "vegan",
      "Moscow",
      "шоппинг",
      "eco-activism",
      "Москва",
      "Водолей",
      "coworking",
      "singing",
      "Лев",
      "большой теннис",
      "thanks",
      "communication",
      "Saint Petersburg",
      "tennis",
      "МФТИ",
      "Cancer",
      "cooking",
      "мода",
      "astrology",
      "растения",
      "сквош",
      "искусство",
      "бокс",
      "San Francisco",
      "photo"
    ])

  @external_resource "priv/sticker_options"
  en_files = File.ls!(Path.join(@external_resource, "en"))

  read_answers = fn path ->
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.filter(fn answer -> MapSet.member?(stickers, answer) end)
  end

  qas =
    en_files
    |> Enum.map(fn file ->
      question =
        file
        |> String.trim_trailing(".txt")
        |> String.replace(" ", "_")
        |> case do
          "food" -> "cuisines"
          "company" -> "occupation"
          "astrological_signs" -> "zodiac"
          "studying" -> "currently_studying"
          "job" -> "occupation"
          other -> other
        end

      en_answers = read_answers.(Path.join([@external_resource, "en", file]))
      ru_answers = read_answers.(Path.join([@external_resource, "ru", file]))

      [
        Enum.map(en_answers, fn answer -> {answer, question} end),
        Enum.map(ru_answers, fn answer -> {answer, question} end)
      ]
    end)
    |> List.flatten()

  qas
  |> Enum.group_by(fn {a, _q} -> a end)
  |> Enum.filter(fn {_a, qas} -> length(qas) > 1 end)
  |> Enum.each(fn {_a, qas} -> IO.warn("Duplicate qas: #{inspect(qas)}") end)

  uniq_qas = Enum.uniq_by(qas, fn {answer, _question} -> answer end)

  Enum.each(uniq_qas, fn {answer, question} ->
    def q(unquote(answer)), do: unquote(question)
  end)

  def q(_answer), do: nil

  defp restore_url_only_label(%{"url" => url} = label) do
    case qa(url) do
      {:restore, q, a} ->
        label |> Map.delete("url") |> Map.merge(%{"question" => q, "answer" => a, "value" => a})

      :remove ->
        nil

      :keep ->
        label
    end
  end

  defp restore_url_only_label(label), do: label

  defp qa(url) do
    %URI{host: "d20pncrvwjzpw9.cloudfront.net", path: path} = URI.parse(url)

    [key] = String.split(path, "/", trim: true)
    answer = URI.decode_www_form(key)

    cond do
      answer == "photo" ->
        :remove

      question = q(answer) ->
        {:restore, question, answer}

      true ->
        extra = %{"url" => url, "answer" => answer}
        Sentry.capture_message("failied to find answer", extra: extra)
        :keep
    end
  end

  def fix_story(story) when is_list(story) do
    Enum.map(story, fn
      %{"labels" => labels} = page ->
        labels = labels |> Enum.map(&restore_url_only_label/1) |> Enum.reject(&is_nil/1)
        %{page | "labels" => labels}

      page ->
        page
    end)
  end

  def fix_story(nil), do: nil
end
