defmodule StubMediaClient do
  @behaviour T.Media.Client

  @impl true
  def list_objects(_bucket) do
    [
      %{
        "ETag" => "\"844419fe2fb3d50a71eb8f2adaefcfbc\"",
        "Key" => "Facebook",
        "LastModified" => "2021-06-14T09:02:59.000Z",
        "Size" => "1768",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"9ecbb6d4d79d56e7297848a3a04cde76\"",
        "Key" => "Instagram",
        "LastModified" => "2021-06-14T09:02:59.000Z",
        "Size" => "3017",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"9ba79d3bdf04f142e6bdab4de8d32c08\"",
        "Key" => "Telegram",
        "LastModified" => "2021-06-14T09:02:59.000Z",
        "Size" => "1442",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"f30258f46628e99a324fe25d8b741c4d\"",
        "Key" => "VK",
        "LastModified" => "2021-06-14T09:02:59.000Z",
        "Size" => "2544",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"0e327c00009c104e56e4a8d454deafe2\"",
        "Key" => "YouTube",
        "LastModified" => "2021-06-14T09:02:59.000Z",
        "Size" => "1637",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"b9d314260aef1494f2fd0aff42bb69a8\"",
        "Key" => "Британская Высшая Школа Дизайна",
        "LastModified" => "2021-06-14T09:02:59.000Z",
        "Size" => "53726",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"6f95c58e97b0b6eb993aa3f4c12301eb\"",
        "Key" => "МГИМО",
        "LastModified" => "2021-06-14T09:02:59.000Z",
        "Size" => "50631",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"8602a7e87980a2a48807c81a05fcd9c8\"",
        "Key" => "МГУ",
        "LastModified" => "2021-06-14T09:02:59.000Z",
        "Size" => "83991",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"2a31776e9e329ebaa3166e0eb2575f37\"",
        "Key" => "МИСиС",
        "LastModified" => "2021-06-14T09:02:59.000Z",
        "Size" => "42218",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"b5659b0729d57e24638f3c28644e7ec7\"",
        "Key" => "МФТИ",
        "LastModified" => "2021-06-14T09:02:58.000Z",
        "Size" => "34429",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"20c94e76042e85ddca6459853c9bb116\"",
        "Key" => "Москва",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "2456",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"7cb73936f2034be655d0efa9cb0aea4c\"",
        "Key" => "НИУ ВШЭ",
        "LastModified" => "2021-06-14T09:02:58.000Z",
        "Size" => "96256",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"c9e5b670f7739e4cc12e7590cbac5d4b\"",
        "Key" => "Первый МГМУ им. Сеченова",
        "LastModified" => "2021-06-14T09:02:59.000Z",
        "Size" => "39895",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"79c0f6e0ee2d6e33279455b30d714682\"",
        "Key" => "РУДН",
        "LastModified" => "2021-06-14T09:02:59.000Z",
        "Size" => "35010",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"e066094fece10f2e36c5391be3ef5b80\"",
        "Key" => "Санкт-Петербург",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "1018",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"05e6896114a19c0813821408a9faee10\"",
        "Key" => "баскетбол",
        "LastModified" => "2021-06-14T09:02:59.000Z",
        "Size" => "690",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"16406f5736ab8e278c6e8d01a0a57b8a\"",
        "Key" => "бокс",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "1951",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"1233c1bf3c81b494c23a0690f5fd41a8\"",
        "Key" => "большой теннис",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "490",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"ecc7d8afe9014782351f6f0bf25a77ca\"",
        "Key" => "велосипед",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "1623",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"4df6eb1b748722cb40d3ccfa7b81a016\"",
        "Key" => "вино",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "1471",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"5ecbb8d14fa0316b9d765398e55b790d\"",
        "Key" => "кальян",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "1319",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"e3717698c7665a0fbb8315846372dbc5\"",
        "Key" => "коктейли",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "1399",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"168075b13feb9d4ed0d318c02d24f5d7\"",
        "Key" => "кошка",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "1796",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"06ac992e978ec118250a607d6f123efd\"",
        "Key" => "настольный теннис",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "2233",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"17ecd4cbad5eaed4638365a769ecced7\"",
        "Key" => "пиво",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "1036",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"0256ed46f0792b1aead219938622c3e4\"",
        "Key" => "писательство",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "1630",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"28178a34ef9d569cd262a5622ba8737d\"",
        "Key" => "пицца",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "1933",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"3ece9ed9d38696c6a4a0fcf4ef63289e\"",
        "Key" => "программирование",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "1479",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"c40bcc2de31c39dec4e9efcdd0c965d0\"",
        "Key" => "рисование",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "2087",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"5f79441606a78e87ceedf4149ad0416e\"",
        "Key" => "сигареты",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "2524",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"bd6c81c77ea14d5572ed96b10eeac2ec\"",
        "Key" => "суши",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "2520",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"9ec4f7d22b5a7a13efb3b03f152f1807\"",
        "Key" => "тренажерный зал",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "770",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"6e1267b516f6633881e56caa749feaee\"",
        "Key" => "фотография",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "1689",
        "StorageClass" => "STANDARD"
      },
      %{
        "ETag" => "\"7468c52921163586ed2b533c6d6c734b\"",
        "Key" => "футбол",
        "LastModified" => "2021-06-14T09:03:00.000Z",
        "Size" => "1546",
        "StorageClass" => "STANDARD"
      }
    ]
  end
end
