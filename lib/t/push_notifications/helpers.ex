defmodule T.PushNotifications.Helpers do
  ru_en_mapping = %{
    "а" => "a",
    "и" => "i",
    "с" => "s",
    "ъ" => "",
    "б" => "b",
    "й" => "j",
    "т" => "t",
    "ы" => "y",
    "в" => "v",
    "к" => "k",
    "у" => "u",
    "ь" => "'",
    "г" => "g",
    "л" => "l",
    "ф" => "f",
    "э" => "je",
    "д" => "d",
    "м" => "m",
    "х" => "h",
    "ю" => "ju",
    "е" => "e",
    "н" => "n",
    "ц" => "c",
    "я" => "ya",
    "ё" => "jo",
    "о" => "o",
    "ч" => "ch",
    "ж" => "zh",
    "п" => "p",
    "ш" => "sh",
    "з" => "z",
    "р" => "r",
    "щ" => "sh"
  }

  for {k, v} <- ru_en_mapping do
    defp ru_en(unquote(k)), do: unquote(v)
    defp ru_en(unquote(String.upcase(k))), do: unquote(String.capitalize(v))
  end

  defp ru_en(other), do: other

  def translitirate_to_en(string) do
    string
    |> String.codepoints()
    |> Enum.map(&ru_en/1)
    |> Enum.join()
  end
end
