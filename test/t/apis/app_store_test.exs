defmodule T.AppStoreTest do
  use ExUnit.Case, async: true
  use T.DataCase, async: true
  alias AppStore

  describe "load_notification_history" do
    @tag :integration
    test "fetches in-app purchase notification history from app store" do
      assert :ok == AppStore.load_notification_history()
    end
  end
end
