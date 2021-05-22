defmodule T.MediaTest do
  use ExUnit.Case, async: true
  alias T.Media

  test "known_stickers" do
    assert Media.known_stickers() == %{
             "Британская Высшая Школа Дизайна" =>
               "https://pretend-this-is-real.s3.amazonaws.com/%D0%91%D1%80%D0%B8%D1%82%D0%B0%D0%BD%D1%81%D0%BA%D0%B0%D1%8F%20%D0%92%D1%8B%D1%81%D1%88%D0%B0%D1%8F%20%D0%A8%D0%BA%D0%BE%D0%BB%D0%B0%20%D0%94%D0%B8%D0%B7%D0%B0%D0%B9%D0%BD%D0%B0.png",
             "МГИМО" =>
               "https://pretend-this-is-real.s3.amazonaws.com/%D0%9C%D0%93%D0%98%D0%9C%D0%9E.png",
             "МГУ" => "https://pretend-this-is-real.s3.amazonaws.com/%D0%9C%D0%93%D0%A3.png",
             "МИСиС" =>
               "https://pretend-this-is-real.s3.amazonaws.com/%D0%9C%D0%98%D0%A1%D0%B8%D0%A1.png",
             "МФТИ" =>
               "https://pretend-this-is-real.s3.amazonaws.com/%D0%9C%D0%A4%D0%A2%D0%98.png",
             "НИУ ВШЭ" =>
               "https://pretend-this-is-real.s3.amazonaws.com/%D0%9D%D0%98%D0%A3%20%D0%92%D0%A8%D0%AD.png",
             "Первый МГМУ им. Сеченова" =>
               "https://pretend-this-is-real.s3.amazonaws.com/%D0%9F%D0%B5%D1%80%D0%B2%D1%8B%D0%B9%20%D0%9C%D0%93%D0%9C%D0%A3%20%D0%B8%D0%BC.%20%D0%A1%D0%B5%D1%87%D0%B5%D0%BD%D0%BE%D0%B2%D0%B0.png",
             "РУДН" =>
               "https://pretend-this-is-real.s3.amazonaws.com/%D0%A0%D0%A3%D0%94%D0%9D.png"
           }
  end

  test "known_sticker_label_url" do
    assert Media.known_sticker_label_url("Британская Высшая Школа Дизайна") ==
             "https://pretend-this-is-real.s3.amazonaws.com/%D0%91%D1%80%D0%B8%D1%82%D0%B0%D0%BD%D1%81%D0%BA%D0%B0%D1%8F%20%D0%92%D1%8B%D1%81%D1%88%D0%B0%D1%8F%20%D0%A8%D0%BA%D0%BE%D0%BB%D0%B0%20%D0%94%D0%B8%D0%B7%D0%B0%D0%B9%D0%BD%D0%B0.png"

    assert Media.known_sticker_label_url("МГИМО") ==
             "https://pretend-this-is-real.s3.amazonaws.com/%D0%9C%D0%93%D0%98%D0%9C%D0%9E.png"

    assert Media.known_sticker_label_url(nil) == nil
    assert Media.known_sticker_label_url("other") == nil
  end
end
