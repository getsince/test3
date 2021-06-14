defmodule T.MediaTest do
  use ExUnit.Case, async: true
  alias T.Media

  test "known_stickers" do
    assert Media.known_stickers() == %{
             "Facebook" =>
               "https://pretend-this-is-static.s3.amazonaws.com/Facebook.svg?d=844419fe2fb3d50a71eb8f2adaefcfbc",
             "Instagram" =>
               "https://pretend-this-is-static.s3.amazonaws.com/Instagram.svg?d=9ecbb6d4d79d56e7297848a3a04cde76",
             "Telegram" =>
               "https://pretend-this-is-static.s3.amazonaws.com/Telegram.svg?d=9ba79d3bdf04f142e6bdab4de8d32c08",
             "VK" =>
               "https://pretend-this-is-static.s3.amazonaws.com/VK.svg?d=f30258f46628e99a324fe25d8b741c4d",
             "YouTube" =>
               "https://pretend-this-is-static.s3.amazonaws.com/YouTube.svg?d=0e327c00009c104e56e4a8d454deafe2",
             "Британская Высшая Школа Дизайна" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%91%D1%80%D0%B8%D1%82%D0%B0%D0%BD%D1%81%D0%BA%D0%B0%D1%8F%20%D0%92%D1%8B%D1%81%D1%88%D0%B0%D1%8F%20%D0%A8%D0%BA%D0%BE%D0%BB%D0%B0%20%D0%94%D0%B8%D0%B7%D0%B0%D0%B9%D0%BD%D0%B0.png?d=b9d314260aef1494f2fd0aff42bb69a8",
             "МГИМО" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%9C%D0%93%D0%98%D0%9C%D0%9E.png?d=6f95c58e97b0b6eb993aa3f4c12301eb",
             "МГУ" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%9C%D0%93%D0%A3.png?d=8602a7e87980a2a48807c81a05fcd9c8",
             "МИСиС" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%9C%D0%98%D0%A1%D0%B8%D0%A1.png?d=2a31776e9e329ebaa3166e0eb2575f37",
             "МФТИ" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%9C%D0%A4%D0%A2%D0%98.png?d=b5659b0729d57e24638f3c28644e7ec7",
             "Москва" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%9C%D0%BE%D1%81%D0%BA%D0%B2%D0%B0.svg?d=20c94e76042e85ddca6459853c9bb116",
             "НИУ ВШЭ" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%9D%D0%98%D0%A3%20%D0%92%D0%A8%D0%AD.png?d=7cb73936f2034be655d0efa9cb0aea4c",
             "Первый МГМУ им. Сеченова" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%9F%D0%B5%D1%80%D0%B2%D1%8B%D0%B9%20%D0%9C%D0%93%D0%9C%D0%A3%20%D0%B8%D0%BC.%20%D0%A1%D0%B5%D1%87%D0%B5%D0%BD%D0%BE%D0%B2%D0%B0.png?d=c9e5b670f7739e4cc12e7590cbac5d4b",
             "РУДН" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%A0%D0%A3%D0%94%D0%9D.png?d=79c0f6e0ee2d6e33279455b30d714682",
             "Санкт-Петербург" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%A1%D0%B0%D0%BD%D0%BA%D1%82-%D0%9F%D0%B5%D1%82%D0%B5%D1%80%D0%B1%D1%83%D1%80%D0%B3.svg?d=e066094fece10f2e36c5391be3ef5b80",
             "баскетбол" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%B1%D0%B0%D1%81%D0%BA%D0%B5%D1%82%D0%B1%D0%BE%D0%BB.svg?d=05e6896114a19c0813821408a9faee10",
             "бокс" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%B1%D0%BE%D0%BA%D1%81.svg?d=16406f5736ab8e278c6e8d01a0a57b8a",
             "большой теннис" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%B1%D0%BE%D0%BB%D1%8C%D1%88%D0%BE%D0%B9%20%D1%82%D0%B5%D0%BD%D0%BD%D0%B8%D1%81.svg?d=1233c1bf3c81b494c23a0690f5fd41a8",
             "велосипед" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%B2%D0%B5%D0%BB%D0%BE%D1%81%D0%B8%D0%BF%D0%B5%D0%B4.svg?d=ecc7d8afe9014782351f6f0bf25a77ca",
             "вино" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%B2%D0%B8%D0%BD%D0%BE.svg?d=4df6eb1b748722cb40d3ccfa7b81a016",
             "кальян" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%BA%D0%B0%D0%BB%D1%8C%D1%8F%D0%BD.svg?d=5ecbb8d14fa0316b9d765398e55b790d",
             "коктейли" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%BA%D0%BE%D0%BA%D1%82%D0%B5%D0%B9%D0%BB%D0%B8.svg?d=e3717698c7665a0fbb8315846372dbc5",
             "кошка" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%BA%D0%BE%D1%88%D0%BA%D0%B0.svg?d=168075b13feb9d4ed0d318c02d24f5d7",
             "настольный теннис" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%BD%D0%B0%D1%81%D1%82%D0%BE%D0%BB%D1%8C%D0%BD%D1%8B%D0%B9%20%D1%82%D0%B5%D0%BD%D0%BD%D0%B8%D1%81.svg?d=06ac992e978ec118250a607d6f123efd",
             "пиво" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%BF%D0%B8%D0%B2%D0%BE.svg?d=17ecd4cbad5eaed4638365a769ecced7",
             "писательство" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%BF%D0%B8%D1%81%D0%B0%D1%82%D0%B5%D0%BB%D1%8C%D1%81%D1%82%D0%B2%D0%BE.svg?d=0256ed46f0792b1aead219938622c3e4",
             "пицца" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%BF%D0%B8%D1%86%D1%86%D0%B0.svg?d=28178a34ef9d569cd262a5622ba8737d",
             "программирование" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D0%BF%D1%80%D0%BE%D0%B3%D1%80%D0%B0%D0%BC%D0%BC%D0%B8%D1%80%D0%BE%D0%B2%D0%B0%D0%BD%D0%B8%D0%B5.svg?d=3ece9ed9d38696c6a4a0fcf4ef63289e",
             "рисование" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D1%80%D0%B8%D1%81%D0%BE%D0%B2%D0%B0%D0%BD%D0%B8%D0%B5.svg?d=c40bcc2de31c39dec4e9efcdd0c965d0",
             "сигареты" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D1%81%D0%B8%D0%B3%D0%B0%D1%80%D0%B5%D1%82%D1%8B.svg?d=5f79441606a78e87ceedf4149ad0416e",
             "суши" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D1%81%D1%83%D1%88%D0%B8.svg?d=bd6c81c77ea14d5572ed96b10eeac2ec",
             "тренажерный зал" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D1%82%D1%80%D0%B5%D0%BD%D0%B0%D0%B6%D0%B5%D1%80%D0%BD%D1%8B%D0%B9%20%D0%B7%D0%B0%D0%BB.svg?d=9ec4f7d22b5a7a13efb3b03f152f1807",
             "фотография" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D1%84%D0%BE%D1%82%D0%BE%D0%B3%D1%80%D0%B0%D1%84%D0%B8%D1%8F.svg?d=6e1267b516f6633881e56caa749feaee",
             "футбол" =>
               "https://pretend-this-is-static.s3.amazonaws.com/%D1%84%D1%83%D1%82%D0%B1%D0%BE%D0%BB.svg?d=7468c52921163586ed2b533c6d6c734b"
           }
  end

  test "known_sticker_label_url" do
    assert Media.known_sticker_label_url("Британская Высшая Школа Дизайна") ==
             "https://pretend-this-is-static.s3.amazonaws.com/%D0%91%D1%80%D0%B8%D1%82%D0%B0%D0%BD%D1%81%D0%BA%D0%B0%D1%8F%20%D0%92%D1%8B%D1%81%D1%88%D0%B0%D1%8F%20%D0%A8%D0%BA%D0%BE%D0%BB%D0%B0%20%D0%94%D0%B8%D0%B7%D0%B0%D0%B9%D0%BD%D0%B0.png?d=b9d314260aef1494f2fd0aff42bb69a8"

    assert Media.known_sticker_label_url("МГИМО") ==
             "https://pretend-this-is-static.s3.amazonaws.com/%D0%9C%D0%93%D0%98%D0%9C%D0%9E.png?d=6f95c58e97b0b6eb993aa3f4c12301eb"

    assert Media.known_sticker_label_url(nil) == nil
    assert Media.known_sticker_label_url("other") == nil
  end
end
