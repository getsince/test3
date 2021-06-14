defmodule StubMediaClient do
  @behaviour T.Media.Client

  @impl true
  def list_objects(_bucket) do
    [
      %{
        e_tag: "\"844419fe2fb3d50a71eb8f2adaefcfbc\"",
        key: "Facebook.svg",
        last_modified: "2021-06-14T09:02:59.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1768",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"9ecbb6d4d79d56e7297848a3a04cde76\"",
        key: "Instagram.svg",
        last_modified: "2021-06-14T09:02:59.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "3017",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"9ba79d3bdf04f142e6bdab4de8d32c08\"",
        key: "Telegram.svg",
        last_modified: "2021-06-14T09:02:59.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1442",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"f30258f46628e99a324fe25d8b741c4d\"",
        key: "VK.svg",
        last_modified: "2021-06-14T09:02:59.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "2544",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"0e327c00009c104e56e4a8d454deafe2\"",
        key: "YouTube.svg",
        last_modified: "2021-06-14T09:02:59.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1637",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"b9d314260aef1494f2fd0aff42bb69a8\"",
        key: "Британская Высшая Школа Дизайна.png",
        last_modified: "2021-06-14T09:02:59.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "53726",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"6f95c58e97b0b6eb993aa3f4c12301eb\"",
        key: "МГИМО.png",
        last_modified: "2021-06-14T09:02:59.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "50631",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"8602a7e87980a2a48807c81a05fcd9c8\"",
        key: "МГУ.png",
        last_modified: "2021-06-14T09:02:59.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "83991",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"2a31776e9e329ebaa3166e0eb2575f37\"",
        key: "МИСиС.png",
        last_modified: "2021-06-14T09:02:59.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "42218",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"b5659b0729d57e24638f3c28644e7ec7\"",
        key: "МФТИ.png",
        last_modified: "2021-06-14T09:02:58.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "34429",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"20c94e76042e85ddca6459853c9bb116\"",
        key: "Москва.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "2456",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"7cb73936f2034be655d0efa9cb0aea4c\"",
        key: "НИУ ВШЭ.png",
        last_modified: "2021-06-14T09:02:58.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "96256",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"c9e5b670f7739e4cc12e7590cbac5d4b\"",
        key: "Первый МГМУ им. Сеченова.png",
        last_modified: "2021-06-14T09:02:59.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "39895",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"79c0f6e0ee2d6e33279455b30d714682\"",
        key: "РУДН.png",
        last_modified: "2021-06-14T09:02:59.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "35010",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"e066094fece10f2e36c5391be3ef5b80\"",
        key: "Санкт-Петербург.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1018",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"05e6896114a19c0813821408a9faee10\"",
        key: "баскетбол.svg",
        last_modified: "2021-06-14T09:02:59.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "690",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"16406f5736ab8e278c6e8d01a0a57b8a\"",
        key: "бокс.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1951",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"1233c1bf3c81b494c23a0690f5fd41a8\"",
        key: "большой теннис.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "490",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"ecc7d8afe9014782351f6f0bf25a77ca\"",
        key: "велосипед.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1623",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"4df6eb1b748722cb40d3ccfa7b81a016\"",
        key: "вино.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1471",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"5ecbb8d14fa0316b9d765398e55b790d\"",
        key: "кальян.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1319",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"e3717698c7665a0fbb8315846372dbc5\"",
        key: "коктейли.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1399",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"168075b13feb9d4ed0d318c02d24f5d7\"",
        key: "кошка.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1796",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"06ac992e978ec118250a607d6f123efd\"",
        key: "настольный теннис.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "2233",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"17ecd4cbad5eaed4638365a769ecced7\"",
        key: "пиво.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1036",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"0256ed46f0792b1aead219938622c3e4\"",
        key: "писательство.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1630",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"28178a34ef9d569cd262a5622ba8737d\"",
        key: "пицца.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1933",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"3ece9ed9d38696c6a4a0fcf4ef63289e\"",
        key: "программирование.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1479",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"c40bcc2de31c39dec4e9efcdd0c965d0\"",
        key: "рисование.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "2087",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"5f79441606a78e87ceedf4149ad0416e\"",
        key: "сигареты.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "2524",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"bd6c81c77ea14d5572ed96b10eeac2ec\"",
        key: "суши.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "2520",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"9ec4f7d22b5a7a13efb3b03f152f1807\"",
        key: "тренажерный зал.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "770",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"6e1267b516f6633881e56caa749feaee\"",
        key: "фотография.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1689",
        storage_class: "STANDARD"
      },
      %{
        e_tag: "\"7468c52921163586ed2b533c6d6c734b\"",
        key: "футбол.svg",
        last_modified: "2021-06-14T09:03:00.000Z",
        owner: %{
          display_name: "",
          id: "2d5eb7a60849ebd8bb34b044ace907f1c45daa00e6d7d1c9bf2e5f2fa0409bb6"
        },
        size: "1546",
        storage_class: "STANDARD"
      }
    ]
  end
end
